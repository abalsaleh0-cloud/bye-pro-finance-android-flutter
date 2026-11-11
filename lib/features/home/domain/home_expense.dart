import 'package:expense_app/core/money/money.dart';
import 'package:expense_app/core/time/month_key.dart';

/// A home expense assigned to the month in which it is due.
final class HomeExpense {
  HomeExpense({
    required this.id,
    required this.amount,
    required this.categoryId,
    required this.expenseDate,
    required this.dueMonth,
    this.note,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'ID cannot be empty.');
    }
    if (amount.isZero) {
      throw ArgumentError.value(amount, 'amount', 'Amount must be greater than zero.');
    }
    if (categoryId.trim().isEmpty) {
      throw ArgumentError.value(
        categoryId,
        'categoryId',
        'Category ID cannot be empty.',
      );
    }
  }

  final String id;
  final Money amount;
  final String categoryId;
  final DateTime expenseDate;
  final MonthKey dueMonth;
  final String? note;
}
