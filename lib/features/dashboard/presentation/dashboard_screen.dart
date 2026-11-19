import 'package:expense_app/core/database/database_providers.dart';
import 'package:expense_app/core/time/calendar_date.dart';
import 'package:expense_app/core/time/month_key.dart';
import 'package:expense_app/core/time/selected_month_provider.dart';
import 'package:expense_app/core/theme/app_design_tokens.dart';
import 'package:expense_app/core/widgets/month_selector.dart';
import 'package:expense_app/features/dashboard/domain/monthly_overview.dart';
import 'package:expense_app/features/debts/domain/debt_entry.dart';
import 'package:expense_app/features/debts/domain/debt_payment.dart';
import 'package:expense_app/features/home/domain/home_bill.dart';
import 'package:expense_app/features/home/domain/home_expense.dart';
import 'package:expense_app/features/work/domain/work_entry.dart';
import 'package:expense_app/features/work/domain/work_home_transfer.dart';
import 'package:expense_app/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppLocalizations.of(context)!;
    final tokens = AppDesignTokens.of(context);
    final work = ref.watch(workEntriesProvider);
    final home = ref.watch(homeExpensesProvider);
    final transfers = ref.watch(workTransfersProvider);
    final debts = ref.watch(debtsProvider);
    final bills = ref.watch(homeBillsProvider);
    final month = ref.watch(selectedMonthProvider);
    final billPayments = ref.watch(homeBillPaymentsForMonthProvider(month));
    final billOutstandingAtMonthEnd =
        ref.watch(homeBillOutstandingAsOfMonthProvider(month));
    final allBillPayments = ref.watch(allHomeBillPaymentsProvider);
    final allDebtPayments = ref.watch(allDebtPaymentsProvider);

    if (work.isLoading ||
        home.isLoading ||
        transfers.isLoading ||
        debts.isLoading ||
        bills.isLoading ||
        billPayments.isLoading ||
        billOutstandingAtMonthEnd.isLoading ||
        allBillPayments.isLoading ||
        allDebtPayments.isLoading) {
      return Scaffold(body: Center(child: Text(strings.loading)));
    }
    if (work.hasError ||
        home.hasError ||
        transfers.hasError ||
        debts.hasError ||
        bills.hasError ||
        billPayments.hasError ||
        billOutstandingAtMonthEnd.hasError ||
        allBillPayments.hasError ||
        allDebtPayments.hasError) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(strings.dataError, textAlign: TextAlign.center),
          ),
        ),
      );
    }

    final workItems = work.value ?? const <WorkEntry>[];
    final homeItems = home.value ?? const <HomeExpense>[];
    final transferItems = transfers.value ?? const <WorkHomeTransfer>[];
    final debtItems = debts.value ?? const <DebtEntry>[];
    final billItems = bills.value ?? const <HomeBill>[];
    final overview = MonthlyOverview.calculate(
      month: month,
      workEntries: workItems,
      homeExpenses: homeItems,
      transfers: transferItems,
      debts: debtItems,
    );

    final monthExpenses = homeItems.where((item) {
      final date = item.expenseDate.toLocal();
      return date.year == month.year && date.month == month.month;
    }).fold<int>(0, (sum, item) => sum + item.amount.minorUnits);
    final monthTransfers = transferItems.where((item) {
      final date = item.transferredAt.toLocal();
      return date.year == month.year && date.month == month.month;
    }).fold<int>(0, (sum, item) => sum + item.amount.minorUnits);
    final outstandingBillsAtMonthEnd =
        billOutstandingAtMonthEnd.value ?? 0;
    final homeBalance = monthTransfers -
        monthExpenses -
        (billPayments.value ?? 0) -
        outstandingBillsAtMonthEnd;

    final availableMonths = <MonthKey>{
      MonthKey(year: DateTime.now().year, month: DateTime.now().month),
      month,
      ...workItems.map((item) => item.dueMonth),
      ...homeItems.map((item) => item.dueMonth),
      ...homeItems.map((item) {
        final date = item.expenseDate.toLocal();
        return MonthKey(year: date.year, month: date.month);
      }),
      ...transferItems.map((item) {
        final date = item.transferredAt.toLocal();
        return MonthKey(year: date.year, month: date.month);
      }),
      ...billItems.map((item) => item.dueMonth),
      ...debtItems.map((item) => item.dueMonth),
    }.toList()
      ..sort((a, b) => b.compareTo(a));

    final recent = _recentActivity(
      strings,
      workItems,
      homeItems,
      transferItems,
      debtItems,
      billItems,
      allBillPayments.value ?? const <HomeBillPayment>[],
      allDebtPayments.value ?? const <DebtPayment>[],
    );

    return Scaffold(
      body: ListView(
        key: const Key('dashboard-content'),
        padding: tokens.pageInsets(bottom: tokens.pageVerticalPadding * 2),
        children: [
          MonthSelector(
            pickerKey: const Key('dashboard-month-picker'),
            selectedMonth: month,
            availableMonths: availableMonths,
            onChanged: (value) =>
                ref.read(selectedMonthProvider.notifier).select(value),
          ),
          SizedBox(height: tokens.sectionSpacing),
          _sectionHeading(context, strings.financialSnapshot),
          const SizedBox(height: 8),
          _metricGrid(context, [
            _MetricData(
              title: strings.homeAvailableBalance,
              amount: homeBalance,
              icon: Icons.account_balance_wallet_outlined,
              emphasized: true,
            ),
            _MetricData(
              title: strings.workRemaining,
              amount: overview.workRemainingMinorUnits,
              icon: Icons.account_balance_outlined,
            ),
            _MetricData(
              title: strings.totalWorkOutstanding,
              amount: overview.totalWorkOutstandingMinorUnits,
              icon: Icons.pending_actions_outlined,
            ),
          ]),
          SizedBox(height: tokens.sectionSpacing),
          _sectionHeading(context, strings.work),
          const SizedBox(height: 8),
          _metricGrid(context, [
            _MetricData(
              title: strings.salaryTotal,
              amount: overview.salary.minorUnits,
              icon: Icons.payments_outlined,
            ),
            _MetricData(
              title: strings.advancesTotal,
              amount: overview.advances.minorUnits,
              icon: Icons.request_quote_outlined,
            ),
            _MetricData(
              title: strings.paymentsTotal,
              amount: overview.payments.minorUnits,
              icon: Icons.receipt_long_outlined,
            ),
            _MetricData(
              title: strings.currentSalaryOutstanding,
              amount: overview.currentSalaryOutstandingMinorUnits,
              icon: Icons.account_balance_outlined,
            ),
            _MetricData(
              title: strings.salaryPaymentsApplied,
              amount: overview.salaryPaymentsApplied.minorUnits,
              icon: Icons.check_circle_outline,
            ),
            _MetricData(
              title: strings.previousWorkOutstanding,
              amount: overview.previousWorkOutstandingMinorUnits,
              icon: Icons.history,
            ),
            _MetricData(
              title: strings.transfersTotal,
              amount: overview.transfers.minorUnits,
              icon: Icons.swap_horiz,
            ),
          ]),
          const SizedBox(height: 8),
          Card(
            child: ExpansionTile(
              key: const Key('previous-work-outstanding-details'),
              leading: const Icon(Icons.history),
              title: Row(
                children: [
                  Expanded(
                    child: Text(strings.previousWorkOutstandingDetails),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    overview.previousWorkOutstandingMinorUnits.toString(),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
              subtitle: Text(strings.previousWorkOutstandingHint),
              childrenPadding: const EdgeInsetsDirectional.only(
                start: 16,
                end: 16,
                bottom: 12,
              ),
              children: [
                if (overview.previousWorkOutstandingByMonth.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(strings.noPreviousWorkOutstanding),
                  )
                else
                  for (final item
                      in overview.previousWorkOutstandingByMonth.entries)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        MaterialLocalizations.of(context).formatMonthYear(
                          DateTime(item.key.year, item.key.month),
                        ),
                      ),
                      trailing: Text(
                        item.value.toString(),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
              ],
            ),
          ),
          SizedBox(height: tokens.sectionSpacing),
          _sectionHeading(context, strings.homeSection),
          const SizedBox(height: 8),
          _metricGrid(context, [
            _MetricData(
              title: strings.homeExpensesTotal,
              amount: monthExpenses,
              icon: Icons.shopping_cart_outlined,
            ),
            _MetricData(
              title: strings.transfersTotal,
              amount: monthTransfers,
              icon: Icons.account_balance_wallet_outlined,
            ),
            _MetricData(
              title: strings.totalBillsOutstanding,
              amount: outstandingBillsAtMonthEnd,
              icon: Icons.receipt_outlined,
            ),
            _MetricData(
              title: strings.billPaid,
              amount: billPayments.value ?? 0,
              icon: Icons.task_alt_outlined,
            ),
          ]),
          const SizedBox(height: 16),
          _sectionHeading(context, strings.cashFlowComparison),
          const SizedBox(height: 8),
          _comparisonCard(context, strings, monthTransfers, monthExpenses),
          SizedBox(height: tokens.sectionSpacing),
          _sectionHeading(context, strings.debts),
          const SizedBox(height: 4),
          Text(
            strings.debtBalancesCurrentNote,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          _metricGrid(context, [
            _MetricData(
              title: strings.creditorBalance,
              amount: overview.creditorBalance.minorUnits,
              icon: Icons.call_received_outlined,
            ),
            _MetricData(
              title: strings.debtorBalance,
              amount: overview.debtorBalance.minorUnits,
              icon: Icons.call_made_outlined,
            ),
          ]),
          SizedBox(height: tokens.sectionSpacing),
          _sectionHeading(context, strings.recentActivity),
          const SizedBox(height: 8),
          if (recent.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Center(child: Text(strings.noRecentActivity)),
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  for (var index = 0; index < recent.length; index++) ...[
                    ListTile(
                      leading: CircleAvatar(
                        child: Icon(recent[index].icon),
                      ),
                      title: Text(recent[index].title),
                      subtitle: Text(formatCalendarDate(recent[index].date)),
                      trailing: Text(recent[index].amount.toString()),
                      onTap: () => context.go(recent[index].route),
                    ),
                    if (index != recent.length - 1)
                      const Divider(height: 1, indent: 72),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 12),
          Text(
            strings.amountMinorUnits,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  static Widget _sectionHeading(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
    );
  }

  static Widget _metricGrid(BuildContext context, List<_MetricData> metrics) {
    return SummaryMetricGrid(
      metrics: [
        for (final metric in metrics)
          SummaryMetricData(
            title: metric.title,
            value: metric.amount.toString(),
            icon: metric.icon,
            emphasized: metric.emphasized,
          ),
      ],
    );
  }

  static Widget _comparisonCard(
    BuildContext context,
    AppLocalizations strings,
    int transfers,
    int expenses,
  ) {
    final theme = Theme.of(context);
    final scale = transfers > expenses ? transfers : expenses;
    final transferRatio = scale == 0 ? 0.0 : transfers / scale;
    final expenseRatio = scale == 0 ? 0.0 : expenses / scale;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _comparisonRow(
              context,
              strings.transfersTotal,
              transfers,
              transferRatio,
              theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            _comparisonRow(
              context,
              strings.homeExpensesTotal,
              expenses,
              expenseRatio,
              theme.colorScheme.tertiary,
            ),
          ],
        ),
      ),
    );
  }

  static Widget _comparisonRow(
    BuildContext context,
    String title,
    int amount,
    double ratio,
    Color indicatorColor,
  ) {
    final theme = Theme.of(context);
    final tokens = AppDesignTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title)),
            Text(
              amount.toString(),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(tokens.controlRadius),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 9,
            color: indicatorColor,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }

  static List<_RecentActivity> _recentActivity(
    AppLocalizations strings,
    List<WorkEntry> work,
    List<HomeExpense> home,
    List<WorkHomeTransfer> transfers,
    List<DebtEntry> debts,
    List<HomeBill> bills,
    List<HomeBillPayment> billPayments,
    List<DebtPayment> debtPayments,
  ) {
    final items = <_RecentActivity>[];
    final billsById = {for (final bill in bills) bill.id: bill};
    final debtsById = {for (final debt in debts) debt.id: debt};
    for (final entry in work) {
      final title = switch (entry.kind) {
        WorkEntryKind.salary => strings.salary,
        WorkEntryKind.advance => strings.advance,
        WorkEntryKind.salaryPayment => strings.payment,
      };
      items.add(_RecentActivity(
        date: entry.recordedAt,
        title: title,
        amount: entry.amount.minorUnits,
        icon: Icons.work_outline,
        route: '/work',
      ));
    }
    for (final expense in home) {
      items.add(_RecentActivity(
        date: expense.expenseDate,
        title: strings.dailyExpenses,
        amount: expense.amount.minorUnits,
        icon: Icons.shopping_bag_outlined,
        route: '/home',
      ));
    }
    for (final transfer in transfers) {
      items.add(_RecentActivity(
        date: transfer.transferredAt,
        title: strings.transferredToHome,
        amount: transfer.amount.minorUnits,
        icon: Icons.swap_horiz,
        route: '/work',
      ));
    }
    for (final payment in billPayments) {
      final bill = billsById[payment.billId];
      if (bill == null) continue;
      items.add(_RecentActivity(
        date: payment.paidAt,
        title: '${strings.payment}: ${bill.title}',
        amount: payment.amount.minorUnits,
        icon: Icons.receipt_long_outlined,
        route: '/home',
      ));
    }
    for (final payment in debtPayments) {
      final debt = debtsById[payment.debtId];
      if (debt == null) continue;
      items.add(_RecentActivity(
        date: payment.paidAt,
        title: '${strings.payment}: ${debt.counterparty}',
        amount: payment.amount.minorUnits,
        icon: Icons.handshake_outlined,
        route: '/debts',
      ));
    }
    for (final debt in debts) {
      items.add(_RecentActivity(
        date: debt.createdAt,
        title: debt.direction == DebtDirection.creditor
            ? strings.creditorBalance
            : strings.debtorBalance,
        amount: debt.originalAmount.minorUnits,
        icon: Icons.handshake_outlined,
        route: '/debts',
      ));
    }
    items.sort((a, b) => b.date.compareTo(a.date));
    return items.take(5).toList(growable: false);
  }
}

final class _MetricData {
  const _MetricData({
    required this.title,
    required this.amount,
    required this.icon,
    this.emphasized = false,
  });

  final String title;
  final int amount;
  final IconData icon;
  final bool emphasized;
}

final class _RecentActivity {
  const _RecentActivity({
    required this.date,
    required this.title,
    required this.amount,
    required this.icon,
    required this.route,
  });

  final DateTime date;
  final String title;
  final int amount;
  final IconData icon;
  final String route;
}
