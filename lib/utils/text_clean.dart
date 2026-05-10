/// Small pure-Dart helpers for cleaning the raw HTML-ish strings that
/// come out of the bundled dictionary tables, and for safely quoting
/// user input for SQLite FTS5 MATCH expressions.
///
/// These used to live inline inside `DictionaryCard` (meaning cleanup)
/// and `DatabaseService` (FTS escape). Pulling them into a dependency-
/// free file lets us unit-test them without booting Flutter.
library;

/// Convert the dictionary's inline HTML fragments into plain text.
///
///  - `<br>` / `<br/>` / `<BR/>` become newlines so multi-line meanings
///    still render as multiple lines after the cleanup.
///  - every other tag is stripped. (Entries occasionally contain spans
///    with highlight classes that bleed into clipboard/share output.)
///  - leading/trailing whitespace is trimmed.
String plainMeaning(String input) {
  return input
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .trim();
}

/// Quote and escape a string for use as a phrase in an FTS5 MATCH query.
///
/// FTS5 phrase quoting uses the same doubled-quote convention as SQL:
/// a literal `"` inside a phrase must be written as `""`. Wrapping the
/// whole thing in quotes also neutralizes operator tokens like AND/OR/
/// NEAR/NOT, which would otherwise be parsed as operators and either
/// break the query or, worse, return surprising matches.
String ftsEscape(String input) {
  final escaped = input.replaceAll('"', '""');
  return '"$escaped"';
}
