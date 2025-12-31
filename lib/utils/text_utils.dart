List<String> splitMeaning(String text) {
  final brTag = RegExp(r'<br\s*/?>', caseSensitive: false);
  var t = text
      .replaceAll(brTag, '\n')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n');

  if (t.contains('\n')) {
    return t
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  if (t.contains('؛')) {
    return t
        .split('؛')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  if (t.length > 120 && t.contains('،')) {
    return t
        .split('،')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  if (t.length > 160 && t.contains(';')) {
    return t
        .split(';')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  return [t.trim()];
}

List<String> splitMeaningIsolate(String text) {
  return splitMeaning(text);
}
