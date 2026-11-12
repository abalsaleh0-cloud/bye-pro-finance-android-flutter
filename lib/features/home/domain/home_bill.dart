import 'package:expense_app/core/money/money.dart';
import 'package:expense_app/core/time/month_key.dart';

enum HomeBillKind { monthly, rent }

final class HomeBill {
  const HomeBill({required this.id, required this.title, required this.kind, required this.amount, required this.dueMonth, this.note, this.paidMinorUnits = 0});
  final String id;
  final String title;
  final HomeBillKind kind;
  final Money amount;
  final MonthKey dueMonth;
  final String? note;
  final int paidMinorUnits;
  int get remainingMinorUnits => amount.minorUnits - paidMinorUnits;
  bool get isSettled => remainingMinorUnits == 0;
}

final class HomeBillPayment {
  const HomeBillPayment({required this.id, required this.billId, required this.amount, required this.paidAt, this.note});
  final String id;
  final String billId;
  final Money amount;
  final DateTime paidAt;
  final String? note;
}
