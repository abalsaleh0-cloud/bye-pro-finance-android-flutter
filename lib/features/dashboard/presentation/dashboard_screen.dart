import 'package:expense_app/core/database/database_providers.dart';
import 'package:expense_app/core/time/month_key.dart';
import 'package:expense_app/features/dashboard/domain/monthly_overview.dart';
import 'package:expense_app/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppLocalizations.of(context)!;
    final work = ref.watch(workEntriesProvider);
    final home = ref.watch(homeExpensesProvider);
    final transfers = ref.watch(workTransfersProvider);
    final debts = ref.watch(debtsProvider);

    if (work.isLoading ||
        home.isLoading ||
        transfers.isLoading ||
        debts.isLoading) {
      return Scaffold(body: Center(child: Text(strings.loading)));
    }
    if (work.hasError ||
        home.hasError ||
        transfers.hasError ||
        debts.hasError) {
      return Scaffold(body: Center(child: Text(strings.dataError)));
    }

    final now = DateTime.now();
    final month = MonthKey(year: now.year, month: now.month);
    final overview = MonthlyOverview.calculate(
      month: month,
      workEntries: work.value ?? const [],
      homeExpenses: home.value ?? const [],
      transfers: transfers.value ?? const [],
      debts: debts.value ?? const [],
    );

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            strings.monthlyOverview,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            month.toString(),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _summaryCard(
            context,
            strings.workRecordsTotal,
            overview.workRecordsTotal.minorUnits,
            [
              (strings.salaryTotal, overview.salary.minorUnits),
              (strings.advancesTotal, overview.advances.minorUnits),
              (strings.paymentsTotal, overview.payments.minorUnits),
            ],
          ),
          _summaryCard(
            context,
            strings.workRemaining,
            overview.workRemainingMinorUnits,
            [
              (strings.salaryPaymentsApplied, overview.salaryPaymentsApplied.minorUnits),
              (strings.transferredToHome, overview.transfers.minorUnits),
            ],
          ),
          _summaryCard(
            context,
            strings.totalWorkOutstanding,
            overview.totalWorkOutstandingMinorUnits,
            [
              (strings.previousWorkOutstanding, overview.previousWorkOutstandingMinorUnits),
              (strings.currentSalaryOutstanding, overview.currentSalaryOutstandingMinorUnits),
            ],
          ),
          _summaryCard(
            context,
            strings.homeExpensesTotal,
            overview.homeExpenses.minorUnits,
          ),
          _summaryCard(
            context,
            strings.transfersTotal,
            overview.transfers.minorUnits,
          ),
          _summaryCard(
            context,
            strings.creditorBalance,
            overview.creditorBalance.minorUnits,
          ),
          _summaryCard(
            context,
            strings.debtorBalance,
            overview.debtorBalance.minorUnits,
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(
    BuildContext context,
    String title,
    int amount, [
    List<(String, int)> details = const [],
  ]) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              amount.toString(),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            for (final detail in details)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(detail.$1),
                trailing: Text(detail.$2.toString()),
              ),
          ],
        ),
      ),
    );
  }
}
