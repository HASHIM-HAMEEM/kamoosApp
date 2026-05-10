/// Shared Arabic search utilities: normalization + relevance scoring.
///
/// These helpers used to live in three places (utils/ranking.dart,
/// database_service.dart, search_service.dart) with drift between them.
/// Keep them here so the ranking is consistent between the DB layer, the
/// FTS layer, and the in-isolate suggestion ranker.
library;

final RegExp _kDiacritics = RegExp(r'[\u064B-\u065F\u0670]');

/// Normalize Arabic for matching: strip diacritics, tatweel, unify alif
/// variants and ya variants. Must match the normalization used to build
/// `entries_fts.headword_norm` in `DatabaseService._ensureFtsIndex`.
String normalizeArabic(String input) {
  var out = input.replaceAll(_kDiacritics, '');
  out = out.replaceAll('\u0640', '');
  out = out
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
      .replaceAll('\u0671', 'ا')
      .replaceAll('ٱ', 'ا')
      .replaceAll('ى', 'ي');
  return out;
}

/// Lower score is better. Ranks by: exact equality on raw > exact equality
/// on normalized > raw prefix > normalized prefix > normalized contains.
int scoreSuggestion(String query, String word) {
  final qn = normalizeArabic(query);
  final wn = normalizeArabic(word);
  int s = 0;
  if (wn != qn) s += 4;
  if (word != query) s += 2;
  if (!wn.startsWith(qn)) s += 2;
  if (!word.startsWith(query)) s += 1;
  if (!wn.contains(qn)) s += 1;
  return s;
}

/// Entry point for `compute()`: receives `{query, words}` and returns
/// a list of indices sorted best-first.
List<int> rankSuggestionIndicesIsolate(Map<String, dynamic> args) {
  final String query = args['query'] as String;
  final List<String> words = (args['words'] as List).cast<String>();
  final indices = List<int>.generate(words.length, (i) => i);
  indices.sort(
    (a, b) => scoreSuggestion(query, words[a]).compareTo(
      scoreSuggestion(query, words[b]),
    ),
  );
  return indices;
}
