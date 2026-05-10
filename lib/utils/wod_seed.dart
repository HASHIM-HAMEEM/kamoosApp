/// Deterministic seed for the Word of the Day.
///
/// The app used to pick the WOD via `DateTime.now().millisecondsSinceEpoch`,
/// which rolled every millisecond. That made the word unstable (two
/// opens of the app a second apart could land on different sources) and
/// made debugging painful (you couldn't reproduce "what WOD did the user
/// see on May 10?"). Pulling the arithmetic into a pure function lets
/// us both unit-test it and reuse it wherever else we need a
/// once-per-calendar-day integer.
library;

/// Returns a non-negative ordinal for the given date in UTC. Two
/// `DateTime` values that fall on the same UTC calendar day yield the
/// same ordinal; values on different days yield different ordinals.
int dayOrdinalUtc(DateTime date) {
  final utcMidnight = DateTime.utc(date.year, date.month, date.day);
  final ms = utcMidnight.millisecondsSinceEpoch;
  return ms ~/ Duration.millisecondsPerDay;
}

/// Pick which source index to draw today's WOD from, given the total
/// number of sources and today's [dayOrdinalUtc]. Using a modulo over
/// the day ordinal guarantees we visit every source in a fixed cycle
/// rather than landing on an uneven distribution.
int wodSourceIndex(int dayOrdinal, int sourceCount) {
  if (sourceCount <= 0) return 0;
  return dayOrdinal.abs() % sourceCount;
}
