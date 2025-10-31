import 'package:flutter_test/flutter_test.dart';
import 'package:arabic_dictionary_app/utils/text_utils.dart';

void main() {
  group('splitMeaning', () {
    test('splits on <br> and variants', () {
      const input = 'أصل الكلمة<br>المعنى الأول<BR/>المعنى الثاني';
      final out = splitMeaning(input);
      expect(out, ['أصل الكلمة', 'المعنى الأول', 'المعنى الثاني']);
    });

    test('splits on Arabic semicolon (؛)', () {
      const input = 'أصل الكلمة؛ المعنى الأول؛ المعنى الثاني';
      final out = splitMeaning(input);
      expect(out, ['أصل الكلمة', 'المعنى الأول', 'المعنى الثاني']);
    });

    test('splits on Arabic comma (،) for long lines', () {
      final input = '${List.filled(15, 'هذا نص طويل').join()}${List.filled(10, '، فقرة ثانية طويلة').join()}، فقرة ثالثة';
      final out = splitMeaning(input);
      expect(out.length, greaterThanOrEqualTo(3));
      expect(out.first.contains('نص طويل'), isTrue);
    });

    test('splits on regular semicolon (;) for very long lines', () {
      final input = '${List.filled(20, 'سطر طويل جداً ').join()};${List.filled(20, 'سطر آخر طويل ').join()}';
      final out = splitMeaning(input);
      expect(out.length, 2);
      expect(out[0].isNotEmpty, isTrue);
      expect(out[1].isNotEmpty, isTrue);
    });

    test('returns single trimmed line when no separators', () {
      const input = '  كلمة واحدة بدون فواصل  ';
      final out = splitMeaning(input);
      expect(out, ['كلمة واحدة بدون فواصل']);
    });
  });
}
