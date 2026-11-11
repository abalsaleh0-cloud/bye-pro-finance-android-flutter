import 'package:expense_app/core/money/money.dart';

/// A single partial or final payment recorded against a debt.
final class DebtPayment {
  DebtPayment({
    required this.id,
    required this.debtId,
    required this.amount,
    required this.paidAt,
    this.note,
  }) {
    if (id.trim().isEmpty || debtId.trim().isEmpty) {
      throw ArgumentError('Payment and debt IDs cannot be empty.');
    }
    if (amount.isZero) {
      throw ArgumentError.value(amount, 'amount', 'Payment must be positive.');
    }
  }

  final String id;
  final String debtId;
  final Money amount;
  final DateTime paidAt;
  final String? note;
}
