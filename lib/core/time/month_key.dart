/// A calendar month independent of locale and time zone.
final class MonthKey implements Comparable<MonthKey> {
  MonthKey({required this.year, required this.month}) {
    if (year < 1 || year > 9999) {
      throw ArgumentError.value(year, 'year', 'Year must be between 1 and 9999.');
    }
    if (month < 1 || month > 12) {
      throw ArgumentError.value(month, 'month', 'Month must be between 1 and 12.');
    }
  }

  final int year;
  final int month;

  MonthKey next() {
    if (month == 12) return MonthKey(year: year + 1, month: 1);
    return MonthKey(year: year, month: month + 1);
  }

  @override
  int compareTo(MonthKey other) {
    final yearOrder = year.compareTo(other.year);
    return yearOrder == 0 ? month.compareTo(other.month) : yearOrder;
  }

  @override
  bool operator ==(Object other) =>
      other is MonthKey && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() => '$year-${month.toString().padLeft(2, '0')}';
}
