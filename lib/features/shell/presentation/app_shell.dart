import 'package:expense_app/core/time/month_key.dart';
import 'package:expense_app/core/widgets/app_bottom_navigation_bar.dart';
import 'package:expense_app/core/widgets/entry_tools.dart';
import 'package:expense_app/core/time/selected_month_provider.dart';
import 'package:expense_app/l10n/generated/app_localizations.dart';
import 'package:expense_app/features/work/presentation/work_screen.dart';
import 'package:expense_app/features/home/presentation/home_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

class AppShell extends ConsumerWidget {
  const AppShell({
    required this.location,
    required this.navigationShell,
    super.key,
  });

  final String location;
  final StatefulNavigationShell navigationShell;

  int get _selectedIndex {
    return switch (location) {
      '/work' => 1,
      '/home' => 2,
      '/debts' => 3,
      '/ai' => 4,
      _ => 0,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppLocalizations.of(context)!;
    final labels = [
      strings.dashboard,
      strings.work,
      strings.homeSection,
      strings.debts,
      strings.ai,
    ];

    return Scaffold(
      extendBody: false,
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        title: Text(labels[_selectedIndex]),
        actions: [
          if (_selectedIndex == 1)
            IconButton(
              key: const Key('work-quick-add'),
              tooltip: strings.quickActions,
              icon: const Icon(Icons.add_circle_outline_rounded),
              onPressed: () => _showWorkQuickAdd(context, ref, strings),
            ),
          if (_selectedIndex == 2)
            IconButton(
              key: const Key('home-quick-add'),
              tooltip: strings.quickActions,
              icon: const Icon(Icons.add_circle_outline_rounded),
              onPressed: () => _showHomeQuickAdd(context, ref, strings),
            ),
          IconButton(
            key: const Key('open-settings'),
            tooltip: strings.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings?tab=$_selectedIndex'),
          ),
          IconButton(
            key: const Key('open-calculator'),
            tooltip: strings.calculator,
            icon: const Icon(Icons.calculate_outlined),
            onPressed: () async {
              final value = await showAmountCalculator(context, strings);
              if (!context.mounted || value == null) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${strings.result}: $value')),
              );
            },
          ),
          IconButton(
            key: const Key('open-calendar'),
            tooltip: strings.calendar,
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () async {
              final current = ref.read(selectedMonthProvider);
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime(current.year, current.month, 1),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                initialDatePickerMode: DatePickerMode.year,
              );
              if (picked == null || !context.mounted) return;
              ref.read(selectedMonthProvider.notifier).select(
                    MonthKey(year: picked.year, month: picked.month),
                  );
            },
          ),
        ],
      ),
      body: navigationShell,
      bottomNavigationBar: AppBottomNavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: navigationShell.goBranch,
      ),
    );
  }

  Future<void> _showWorkQuickAdd(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations strings,
  ) async {
    final action = await showModalBottomSheet<WorkQuickAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 12),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  strings.quickActions,
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),
            ListTile(
              key: const Key('work-quick-add-salary'),
              leading: const Icon(Icons.payments_outlined),
              title: Text(strings.addSalaryAction),
              onTap: () => Navigator.pop(sheetContext, WorkQuickAction.salary),
            ),
            ListTile(
              key: const Key('work-quick-add-payment'),
              leading: const Icon(Icons.receipt_long_outlined),
              title: Text(strings.addPaymentAction),
              onTap: () => Navigator.pop(sheetContext, WorkQuickAction.payment),
            ),
            ListTile(
              key: const Key('work-quick-add-advance'),
              leading: const Icon(Icons.request_quote_outlined),
              title: Text(strings.addAdvanceAction),
              onTap: () => Navigator.pop(sheetContext, WorkQuickAction.advance),
            ),
            ListTile(
              key: const Key('work-quick-add-transfer'),
              leading: const Icon(Icons.swap_horiz_rounded),
              title: Text(strings.transferToHomeAction),
              onTap: () => Navigator.pop(sheetContext, WorkQuickAction.transfer),
            ),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    ref.read(workQuickActionProvider.notifier).request(action);
  }

  Future<void> _showHomeQuickAdd(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations strings,
  ) async {
    final action = await showModalBottomSheet<HomeQuickAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 12),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  strings.quickActions,
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),
            ListTile(
              key: const Key('home-quick-add-invoice'),
              leading: const Icon(Icons.receipt_long_outlined),
              title: Text(strings.addInvoice),
              onTap: () =>
                  Navigator.pop(sheetContext, HomeQuickAction.invoice),
            ),
            ListTile(
              key: const Key('home-quick-add-rent'),
              leading: const Icon(Icons.home_work_outlined),
              title: Text(strings.addMonthlyRent),
              onTap: () => Navigator.pop(sheetContext, HomeQuickAction.rent),
            ),
            ListTile(
              key: const Key('home-quick-add-expense'),
              leading: const Icon(Icons.shopping_bag_outlined),
              title: Text(strings.addExpense),
              onTap: () =>
                  Navigator.pop(sheetContext, HomeQuickAction.expense),
            ),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    ref.read(homeQuickActionProvider.notifier).request(action);
  }

}
