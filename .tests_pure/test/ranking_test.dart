// Pure-Dart coverage for lib/utils/ranking.dart.
//
// Importing the file directly via a relative path means the test tracks
// the real source — there's no parallel copy to drift. Running:
//     dart test .tests_pure/test
// from the repo root exercises all of these.

import 'package:test/test.dart';

import '../../lib/utils/ranking.dart';

void main() {
  group('normalizeArabic', () {
    test('strips fatha, kasra, damma and sukun', () {
      expect(normalizeArabic('كَتَبَ'), 'كتب');
      expect(normalizeArabic('مُسْلِم'), 'مسلم');
    });

    test('unifies alif variants and dagger alif', () {
      expect(normalizeArabic('أحمد'), 'احمد');
      expect(normalizeArabic('إيمان'), 'ايمان');
      expect(normalizeArabic('آية'), 'اية');
      // Wasla and the full-form alif also fold to plain alif.
      expect(normalizeArabic('ٱلله'), 'الله');
    });

    test('folds ya maqsura into ya', () {
      expect(normalizeArabic('مصطفى'), 'مصطفي');
    });

    test('strips tatweel (kashida)', () {
      expect(normalizeArabic('الـمـكـتـبـة'), 'المكتبة');
    });

    test('is idempotent', () {
      final once = normalizeArabic('أَبْجَدِيَّةُ اللُّغَةِ');
      expect(normalizeArabic(once), once);
    });
  });

  group('scoreSuggestion (lower is better)', () {
    test('raw exact match scores zero', () {
      expect(scoreSuggestion('كتاب', 'كتاب'), 0);
    });

    test('diacritic-only difference beats a clean prefix', () {
      final normalizedExact = scoreSuggestion('كتاب', 'كِتَاب');
      final cleanPrefix = scoreSuggestion('كتاب', 'كتابة');
      expect(normalizedExact, lessThan(cleanPrefix));
    });

    test('prefix beats substring-only match', () {
      final prefix = scoreSuggestion('كتب', 'كتبي');
      final substring = scoreSuggestion('كتب', 'مكتبة');
      expect(prefix, lessThan(substring));
    });

    test('unrelated word hits the scoring ceiling', () {
      // The scorer tops out at 4 + 2 + 2 + 1 + 1 = 10 (every branch penalised).
      // Anything that shares no root, diacritic-stripped match, prefix, or
      // substring with the query lands there.
      expect(scoreSuggestion('كتاب', 'شمس'), 10);
    });
  });

  group('rankSuggestionIndicesIsolate', () {
    test('exact match comes first, diacritic variant second', () {
      const query = 'كتاب';
      final words = ['كِتَاب', 'كتابة', 'المكتب', 'كتاب', 'كتب'];
      final order =
          rankSuggestionIndicesIsolate({'query': query, 'words': words});
      final sorted = [for (final i in order) words[i]];

      expect(sorted.first, 'كتاب');
      expect(sorted.indexOf('كِتَاب'), lessThan(sorted.indexOf('كتابة')));
      expect(sorted.indexOf('كِتَاب'), lessThan(sorted.indexOf('المكتب')));
    });

    test('prefix outranks contains', () {
      const query = 'كتب';
      final words = ['مكتبة', 'كاتب', 'مكتب', 'كتب', 'كتبي'];
      final order =
          rankSuggestionIndicesIsolate({'query': query, 'words': words});
      final sorted = [for (final i in order) words[i]];

      expect(sorted.first, 'كتب');
      expect(sorted.indexOf('كتبي'), lessThan(sorted.indexOf('مكتبة')));
    });

    test('empty input list returns empty order', () {
      final order =
          rankSuggestionIndicesIsolate({'query': 'كتاب', 'words': <String>[]});
      expect(order, isEmpty);
    });
  });
}
