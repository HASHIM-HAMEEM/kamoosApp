import 'package:flutter_test/flutter_test.dart';
import 'package:arabic_dictionary_app/utils/ranking.dart';

void main() {
  group('rankSuggestionIndicesIsolate', () {
    test('ranks exact and normalized matches first', () {
      const query = 'كتاب';
      final words = [
        'كِتَاب', // diacritics variant
        'كتابة',  // prefix longer
        'المكتب', // contains but not prefix nor equal
        'كتاب',   // exact
        'كتب',    // different word
      ];

      final order = rankSuggestionIndicesIsolate({
        'query': query,
        'words': words,
      });

      final sorted = [for (final i in order) words[i]];

      expect(sorted.first, 'كتاب');
      // Diacritics variant should rank above longer prefix or contains
      expect(sorted.indexOf('كِتَاب') < sorted.indexOf('كتابة'), isTrue);
      expect(sorted.indexOf('كِتَاب') < sorted.indexOf('المكتب'), isTrue);
    });

    test('prefix outranks contains and non-matches', () {
      const query = 'كتب';
      final words = [
        'مكتبة',     // contains
        'كاتب',       // different root
        'مكتب',       // contains
        'كتب',        // exact
        'كتابة',      // prefix of query? No, but query is prefix of this word? No, but this starts with "كتا"
        'كاتبون',     // different
        'كتبي',       // prefix
      ];

      final order = rankSuggestionIndicesIsolate({
        'query': query,
        'words': words,
      });
      final sorted = [for (final i in order) words[i]];

      expect(sorted.first, 'كتب');
      expect(sorted.indexOf('كتبي') < sorted.indexOf('مكتبة'), isTrue);
      expect(sorted.indexOf('كتبي') < sorted.indexOf('مكتب'), isTrue);
    });
  });
}
