List<int> rankSuggestionIndicesIsolate(Map<String, dynamic> args) {
  String query = args['query'] as String;
  List<String> words = (args['words'] as List).cast<String>();

  String norm(String s) {
    final diacritics = RegExp(r'[\u064B-\u065F\u0670]');
    var out = s.replaceAll(diacritics, '');
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

  final qn = norm(query);
  int scoreFor(String w) {
    final wn = norm(w);
    int s = 0;
    if (wn != qn) s += 4;
    if (w != query) s += 2;
    if (!wn.startsWith(qn)) s += 2;
    if (!w.startsWith(query)) s += 1;
    if (!wn.contains(qn)) s += 1;
    return s;
  }

  final indices = List<int>.generate(words.length, (i) => i);
  indices.sort((a, b) => scoreFor(words[a]).compareTo(scoreFor(words[b])));
  return indices;
}
