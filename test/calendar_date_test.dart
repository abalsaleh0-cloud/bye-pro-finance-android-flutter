import 'package:expense_app/core/time/calendar_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatCalendarDate', () {
    test('uses a stable zero-padded ISO calendar date', () {
      expect(formatCalendarDate(DateTime(2026, 1, 5)), '2026-01-05');
      expect(formatCalendarDate(DateTime(2026, 11, 14)), '2026-11-14');
    });

    test('preserves leap-day dates', () {
      expect(formatCalendarDate(DateTime(2024, 2, 29)), '2024-02-29');
    });

    test('does not include time components', () {
      expect(
        formatCalendarDate(DateTime(2026, 7, 9, 23, 59, 58)),
        '2026-07-09',
      );
    });
  });
}
