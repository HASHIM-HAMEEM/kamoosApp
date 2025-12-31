import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:arabic_dictionary_app/services/api_service.dart';
import '../utils/ranking.dart';
import '../models/word.dart';
import '../models/dictionary_source.dart';
import '../services/database_service.dart';

// Ranking moved to: lib/utils/ranking.dart

class SearchService {
  final DatabaseService databaseService;
  final ApiService? apiService;
  final _LRUCache<String, List<Word>> _suggestionCache = _LRUCache(
    maxSize: 100,
  );
  final _LRUCache<String, Word> _aiCache = _LRUCache(maxSize: 50);

  SearchService({required this.databaseService, this.apiService}) {
    debugPrint(
      '🔍 SearchService initialized with ApiService: ${apiService != null ? "YES" : "NO"}',
    );
  }

  // Search for a word - first check database, then API if not found
  Future<Word?> searchWord(String word, {DictionarySource? source}) async {
    final trimmed = word.trim();
    debugPrint(
      '🔎 Searching for word: "$trimmed" (source: ${source?.arabicName ?? "all"})',
    );

    final dbFuture = databaseService.getWord(trimmed, source: source);

    try {
      final earlyDb = await dbFuture.timeout(
        const Duration(milliseconds: 150),
        onTimeout: () => throw TimeoutException('DB timeout'),
      );
      if (earlyDb != null) {
        debugPrint(
          '✅ Found in database: ${earlyDb.source?.arabicName ?? "unknown source"}',
        );
        return earlyDb;
      }
    } on TimeoutException {
      debugPrint('⏱️ Database timeout, trying AI...');
    }

    if (apiService != null) {
      final key = trimmed;
      final cached = _aiCache[key];
      if (cached != null) {
        debugPrint('🗂️  Using cached AI result');
        return cached;
      }
      debugPrint('🤖 Calling Gemini API for word: "$trimmed"');
      final ai = await apiService!.getWordMeaning(trimmed);
      if (ai != null) {
        debugPrint('✅ Gemini API returned result');
        _aiCache[key] = ai;
        return ai;
      }
    } else {
      debugPrint('⚠️  ApiService is null - cannot call Gemini');
    }

    final finalDb = await dbFuture;
    if (finalDb != null) {
      debugPrint(
        '✅ Found in database (late): ${finalDb.source?.arabicName ?? "unknown source"}',
      );
      return finalDb;
    }

    return null;
  }

  // Get search suggestions from database
  Future<List<Word>> getSearchSuggestions(
    String query, {
    DictionarySource? source,
  }) async {
    final key = '${source?.tableName ?? 'all'}|$query';
    final cached = _suggestionCache[key];
    if (cached != null) return cached;
    final results = await databaseService.searchWords(query, source: source);
    // Re-rank using a background isolate based on the word text only
    final order = await compute(rankSuggestionIndicesIsolate, {
      'query': query,
      'words': results.map((w) => w.word).toList(),
    });
    final sorted = [for (final i in order) results[i]];
    _suggestionCache[key] = sorted;
    return sorted;
  }

  // Get all dictionary entries for a headword (aggregated across sources)
  Future<List<Word>> getDictionaryEntries(
    String word, {
    DictionarySource? source,
  }) async {
    return await databaseService.getAllEntries(word, source: source);
  }
}

class _LRUCache<K, V> {
  final int maxSize;
  final LinkedHashMap<K, V> _storage = LinkedHashMap<K, V>();

  _LRUCache({required this.maxSize});

  V? operator [](K key) {
    if (_storage.containsKey(key)) {
      final value = _storage.remove(key);
      if (value != null) {
        _storage[key] = value;
        return value;
      }
    }
    return null;
  }

  void operator []=(K key, V value) {
    if (_storage.containsKey(key)) {
      _storage.remove(key);
    } else if (_storage.length >= maxSize) {
      _storage.remove(_storage.keys.first);
    }
    _storage[key] = value;
  }

  bool containsKey(K key) => _storage.containsKey(key);

  int get length => _storage.length;
}
