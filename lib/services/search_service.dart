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
  final Map<String, List<Word>> _suggestionCache = {};
  final Map<String, Word> _aiCache = {};

  SearchService({
    required this.databaseService,
    this.apiService,
  }) {
    debugPrint('🔍 SearchService initialized with ApiService: ${apiService != null ? "YES" : "NO"}');
  }

  // Search for a word - first check database, then API if not found
  Future<Word?> searchWord(String word, {DictionarySource? source}) async {
    final trimmed = word.trim();
    debugPrint('🔎 Searching for word: "$trimmed" (source: ${source?.arabicName ?? "all"})');
    
    // Start DB lookup and allow a short timeout to start AI early if needed
    final dbFuture = databaseService.getWord(trimmed, source: source);
    Word? earlyDb = await dbFuture.timeout(const Duration(milliseconds: 150), onTimeout: () => null);
    if (earlyDb != null) {
      debugPrint('✅ Found in database: ${earlyDb.source?.arabicName ?? "unknown source"}');
      return earlyDb;
    }

    // Try AI (cached first), while DB may still be running in background
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

    // Await full DB result if AI failed
    final finalDb = await dbFuture;
    if (finalDb != null) {
      debugPrint('✅ Found in database (late): ${finalDb.source?.arabicName ?? "unknown source"}');
      return finalDb;
    }

    return null;
  }

  // Get search suggestions from database
  Future<List<Word>> getSearchSuggestions(String query, {DictionarySource? source}) async {
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
  Future<List<Word>> getDictionaryEntries(String word, {DictionarySource? source}) async {
    return await databaseService.getAllEntries(word, source: source);
  }
}