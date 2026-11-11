import 'package:expense_app/core/money/money.dart';
import 'package:expense_app/core/time/month_key.dart';

enum DebtDirection {
  /// Money another party owes the user.
  creditor,

  /// Money the user owes another party.
  debtor,
}

final class DebtEntry {
  DebtEntry({
    required this.id,
    required this.direction,
    required this.originalAmount,
    required this.outstandingAmount,
    required this.dueMonth,
    required this.createdAt,
    required this.counterparty,
    this.note,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'ID cannot be empty.');
    }
    if (counterparty.trim().isEmpty) {
      throw ArgumentError.value(
        counterparty,
        'counterparty',
        'Counterparty cannot be empty.',
      );
    }
    if (originalAmount.isZero) {
      throw ArgumentError.value(
        originalAmount,
        'originalAmount',
        'Original amount must be greater than zero.',
      );
    }
    if (outstandingAmount.compareTo(originalAmount) > 0) {
      throw ArgumentError(
        'Outstanding amount cannot exceed the original amount.',
      );
    }
  }

  final String id;
  final DebtDirection direction;
  final Money originalAmount;
  final Money outstandingAmount;
  final MonthKey dueMonth;
  final DateTime createdAt;
  final String counterparty;
  final String? note;

  bool get isSettled => outstandingAmount.isZero;
}
