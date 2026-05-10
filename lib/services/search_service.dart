import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../utils/ranking.dart';
import 'api_service.dart';
import '../models/word.dart';
import '../models/dictionary_source.dart';
import 'database_service.dart';

/// Result of a single-word lookup. Lets callers (ResultScreen) tell an
/// "empty dictionary + empty AI answer" apart from "AI request failed"
/// so we can surface the second case with an offline/network banner.
class SearchOutcome {
  final Word? word;
  final bool fromAi;
  final bool aiFailed;
  const SearchOutcome({this.word, this.fromAi = false, this.aiFailed = false});
}

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

  // Search for a word - first check database fully, then fall back to the
  // AI API only if the DB has no entry. The earlier 150ms race caused the
  // AI to be called for words that were already in the local dictionary,
  // wasting API quota and overriding authoritative lexicon entries.
  Future<Word?> searchWord(String word, {DictionarySource? source}) async {
    final outcome = await searchWordDetailed(word, source: source);
    return outcome.word;
  }

  /// Same as [searchWord] but exposes whether the answer came from the
  /// AI and whether the AI request itself failed (used to show an
  /// offline/network banner in the UI).
  Future<SearchOutcome> searchWordDetailed(
    String word, {
    DictionarySource? source,
  }) async {
    final trimmed = word.trim();
    debugPrint(
      '🔎 Searching for word: "$trimmed" (source: ${source?.arabicName ?? "all"})',
    );

    final dbHit = await databaseService.getWord(trimmed, source: source);
    if (dbHit != null) {
      debugPrint(
        '✅ Found in database: ${dbHit.source?.arabicName ?? "unknown source"}',
      );
      return SearchOutcome(word: dbHit);
    }

    if (apiService == null) {
      debugPrint('⚠️  ApiService is null - cannot call Gemini');
      return const SearchOutcome();
    }

    // 1. In-memory cache (current process).
    final cached = _aiCache[trimmed];
    if (cached != null) {
      debugPrint('🗂️  Using in-memory AI result');
      return SearchOutcome(word: cached, fromAi: true);
    }

    // 2. Persisted cache (survives restarts, saves API quota).
    final persisted = await databaseService.getCachedAiWord(trimmed);
    if (persisted != null) {
      debugPrint('💾 Using persisted AI result');
      _aiCache[trimmed] = persisted;
      return SearchOutcome(word: persisted, fromAi: true);
    }

    debugPrint('🤖 DB + cache miss, asking Gemini for: "$trimmed"');
    try {
      final ai = await apiService!.getWordMeaning(trimmed);
      if (ai != null) {
        _aiCache[trimmed] = ai;
        // Fire-and-forget persistence — a failure here (disk full,
        // schema quirk) should not cost the user the result they
        // already have in memory.
        unawaited(databaseService.cacheAiWord(trimmed, ai));
        return SearchOutcome(word: ai, fromAi: true);
      }
      // Null without throwing: API returned nothing usable (empty
      // candidates, schema mismatch). Treat that as a soft failure so
      // the UI can nudge the user to retry rather than silently show
      // "no results".
      return const SearchOutcome(aiFailed: true);
    } catch (e) {
      debugPrint('❌ Gemini request failed: $e');
      return const SearchOutcome(aiFailed: true);
    }
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
