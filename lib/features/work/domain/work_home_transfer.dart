import 'package:expense_app/core/money/money.dart';

/// One transfer record between work and home.
/// Do not persist a second mirrored transaction for the other side.
final class WorkHomeTransfer {
  WorkHomeTransfer({
    required this.id,
    required this.amount,
    required this.transferredAt,
    this.note,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'ID cannot be empty.');
    }
    if (amount.isZero) {
      throw ArgumentError.value(amount, 'amount', 'Amount must be greater than zero.');
    }
  }

  final String id;
  final Money amount;
  final DateTime transferredAt;
  final String? note;
}
