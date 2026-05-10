// Unit tests for lib/utils/text_clean.dart — HTML cleanup and FTS escape.
// Keeping these in pure Dart means we don't need the Flutter SDK to catch
// regressions when refactoring the card or the FTS search path.

import 'package:test/test.dart';

import '../../lib/utils/text_clean.dart';

void main() {
  group('plainMeaning', () {
    test('converts <br> variants into newlines', () {
      final input = 'أول<br>ثاني<BR/>ثالث<br />رابع';
      expect(plainMeaning(input), 'أول\nثاني\nثالث\nرابع');
    });

    test('strips arbitrary tags like spans', () {
      final input = '<span class="root">كتب</span>، <b>مكتبة</b>';
      expect(plainMeaning(input), 'كتب، مكتبة');
    });

    test('trims leading/trailing whitespace', () {
      expect(plainMeaning('  كلمة   '), 'كلمة');
    });

    test('survives nested/broken markup without blowing up', () {
      final input = 'a <i>b <span>c</span></i> d <em>e';
      expect(plainMeaning(input), 'a b c d e');
    });
  });

  group('ftsEscape', () {
    test('wraps a plain token in double quotes', () {
      expect(ftsEscape('كتاب'), '"كتاب"');
    });

    test('neutralizes FTS operators by quoting', () {
      // Unquoted, "AND" would be parsed as an operator and "كتاب AND شمس"
      // would match rows containing both. Quoted, it is a literal phrase.
      expect(ftsEscape('AND'), '"AND"');
      expect(ftsEscape('OR'), '"OR"');
      expect(ftsEscape('NEAR'), '"NEAR"');
    });

    test('escapes embedded double quotes by doubling them', () {
      expect(ftsEscape('say "hi"'), '"say ""hi"""');
    });
  });
}
