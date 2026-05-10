import 'package:test/test.dart';

import '../../lib/utils/text_utils.dart';

void main() {
  group('splitMeaning', () {
    test('splits on <br> and variants', () {
      const input = 'أصل الكلمة<br>المعنى الأول<BR/>المعنى الثاني';
      expect(splitMeaning(input),
          ['أصل الكلمة', 'المعنى الأول', 'المعنى الثاني']);
    });

    test('splits on Arabic semicolon (؛)', () {
      const input = 'أصل الكلمة؛ المعنى الأول؛ المعنى الثاني';
      expect(splitMeaning(input),
          ['أصل الكلمة', 'المعنى الأول', 'المعنى الثاني']);
    });

    test('splits on Arabic comma (،) only when the line is long', () {
      final input =
          '${List.filled(15, 'هذا نص طويل').join()}${List.filled(10, '، فقرة ثانية طويلة').join()}، فقرة ثالثة';
      final out = splitMeaning(input);
      expect(out.length, greaterThanOrEqualTo(3));
      expect(out.first.contains('نص طويل'), isTrue);
    });

    test('returns a single trimmed line when no separators', () {
      expect(splitMeaning('  كلمة واحدة بدون فواصل  '),
          ['كلمة واحدة بدون فواصل']);
    });

    test('drops empty pieces produced by trailing separators', () {
      expect(splitMeaning('أول\nثاني\n\n'), ['أول', 'ثاني']);
    });
  });
}
