import 'package:expense_app/core/money/money.dart';
import 'package:expense_app/core/time/month_key.dart';

enum WorkEntryKind { salary, advance, payment }

/// A recorded work-side amount. The monthly remainder is deliberately not
/// represented here; it must always be derived from source entries.
final class WorkEntry {
  WorkEntry({
    required this.id,
    required this.kind,
    required this.amount,
    required this.dueMonth,
    required this.recordedAt,
    this.note,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'ID cannot be empty.');
    }
    if (amount.isZero) {
      throw ArgumentError.value(
        amount,
        'amount',
        'Amount must be greater than zero.',
      );
    }
  }

  final String id;
  final WorkEntryKind kind;
  final Money amount;
  final MonthKey dueMonth;
  final DateTime recordedAt;
  final String? note;
}
