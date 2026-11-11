import 'package:expense_app/core/database/app_database.dart';
import 'package:expense_app/features/debts/data/debt_repository.dart';
import 'package:expense_app/features/debts/domain/debt_entry.dart';
import 'package:expense_app/features/debts/domain/debt_payment.dart';
import 'package:expense_app/features/home/data/home_expense_repository.dart';
import 'package:expense_app/features/home/domain/home_expense.dart';
import 'package:expense_app/features/work/data/work_repository.dart';
import 'package:expense_app/features/work/domain/work_entry.dart';
import 'package:expense_app/features/work/domain/work_home_transfer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(() => database.close());
  return database;
});
final homeExpenseRepositoryProvider = Provider<HomeExpenseRepository>(
  (ref) => HomeExpenseRepository(ref.watch(appDatabaseProvider)),
);
final workRepositoryProvider = Provider<WorkRepository>(
  (ref) => WorkRepository(ref.watch(appDatabaseProvider)),
);
final debtRepositoryProvider = Provider<DebtRepository>(
  (ref) => DebtRepository(ref.watch(appDatabaseProvider)),
);
final homeExpensesProvider = StreamProvider<List<HomeExpense>>(
  (ref) => ref.watch(homeExpenseRepositoryProvider).watchAll(),
);
final workEntriesProvider = StreamProvider<List<WorkEntry>>(
  (ref) => ref.watch(workRepositoryProvider).watchEntries(),
);
final workTransfersProvider = StreamProvider<List<WorkHomeTransfer>>(
  (ref) => ref.watch(workRepositoryProvider).watchTransfers(),
);
final debtsProvider = StreamProvider<List<DebtEntry>>(
  (ref) => ref.watch(debtRepositoryProvider).watchAll(),
);
final debtPaymentsProvider =
    StreamProvider.family<List<DebtPayment>, String>((ref, debtId) {
      return ref.watch(debtRepositoryProvider).watchPayments(debtId);
    });
