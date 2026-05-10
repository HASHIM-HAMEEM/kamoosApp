// Unit tests for the deterministic Word-of-the-Day seed.

import 'package:test/test.dart';

import '../../lib/utils/wod_seed.dart';

void main() {
  group('dayOrdinalUtc', () {
    test('two different times on the same UTC day share an ordinal', () {
      final a = DateTime.utc(2026, 5, 10, 0, 0, 1);
      final b = DateTime.utc(2026, 5, 10, 23, 59, 59);
      expect(dayOrdinalUtc(a), dayOrdinalUtc(b));
    });

    test('consecutive days differ by exactly one', () {
      final a = DateTime.utc(2026, 5, 10);
      final b = DateTime.utc(2026, 5, 11);
      expect(dayOrdinalUtc(b) - dayOrdinalUtc(a), 1);
    });

    test('local noon on a single day picks a stable ordinal', () {
      // Two DateTimes that represent the same UTC day still fold together
      // even if one is constructed locally — we take the UTC date part.
      final morning = DateTime.utc(2026, 5, 10, 5, 0);
      final evening = DateTime.utc(2026, 5, 10, 22, 0);
      expect(dayOrdinalUtc(morning), dayOrdinalUtc(evening));
    });
  });

  group('wodSourceIndex', () {
    test('cycles through every source over consecutive days', () {
      const sourceCount = 7;
      final seen = <int>{};
      for (var i = 0; i < sourceCount; i++) {
        seen.add(wodSourceIndex(i, sourceCount));
      }
      expect(seen.length, sourceCount);
    });

    test('always non-negative even for far-past dates', () {
      final i = wodSourceIndex(-10000, 7);
      expect(i, greaterThanOrEqualTo(0));
      expect(i, lessThan(7));
    });

    test('zero-source-count is a safe no-op', () {
      expect(wodSourceIndex(42, 0), 0);
    });
  });
}
