import 'package:expense_app/core/database/database_providers.dart';
import 'package:expense_app/core/money/money.dart';
import 'package:expense_app/core/time/calendar_date.dart';
import 'package:expense_app/core/time/month_key.dart';
import 'package:expense_app/core/time/selected_month_provider.dart';
import 'package:expense_app/core/theme/app_design_tokens.dart';
import 'package:expense_app/core/widgets/entry_tools.dart';
import 'package:expense_app/core/widgets/financial_record_card.dart';
import 'package:expense_app/core/widgets/month_selector.dart';
import 'package:expense_app/features/debts/domain/debt_entry.dart';
import 'package:expense_app/features/debts/domain/debt_payment.dart';
import 'package:expense_app/features/debts/presentation/debt_add_request_provider.dart';
import 'package:expense_app/core/widgets/section_pill_tabs.dart';
import 'package:expense_app/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class DebtsScreen extends ConsumerStatefulWidget {
  const DebtsScreen({super.key, this.openManualEntry = false});

  final bool openManualEntry;

  @override
  ConsumerState<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends ConsumerState<DebtsScreen> {
  bool _manualEntryOpened = false;
  int _activeTab = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.openManualEntry && !_manualEntryOpened) {
      _manualEntryOpened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _editDebt(context, ref, AppLocalizations.of(context)!);
      });
    }
  }

  Future<void> _showDebtAddOptions(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations strings,
  ) async {
    final selected = await showModalBottomSheet<DebtDirection>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            key: const Key('debt-add-creditor'),
            leading: const Icon(Icons.call_received_outlined),
            title: Text(strings.addCreditorDebt),
            onTap: () => Navigator.pop(sheetContext, DebtDirection.creditor),
          ),
          ListTile(
            key: const Key('debt-add-debtor'),
            leading: const Icon(Icons.call_made_outlined),
            title: Text(strings.addDebtorDebt),
            onTap: () => Navigator.pop(sheetContext, DebtDirection.debtor),
          ),
        ]),
      ),
    );
    if (!context.mounted || selected == null) return;
    await _editDebt(context, ref, strings, direction: selected);
  }

  Future<void> _editDebt(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations strings, {
    DebtEntry? existing,
    DebtDirection? direction,
  }) async {
    final counterparty = TextEditingController(text: existing?.counterparty ?? '');
    final amount = TextEditingController(text: existing?.originalAmount.minorUnits.toString() ?? '');
    final currentMonth = ref.read(selectedMonthProvider);
    final now = DateTime.now();
    final lastDay = DateTime(currentMonth.year, currentMonth.month + 1, 0).day;
    final defaultDate = DateTime(currentMonth.year, currentMonth.month, now.day > lastDay ? lastDay : now.day);
    final date = TextEditingController(text: formatCalendarDate(existing?.createdAt ?? defaultDate));
    final note = TextEditingController(text: existing?.note ?? '');
    final selectedDirection = existing?.direction ?? direction ?? DebtDirection.debtor;
    final previouslyPaid = existing == null
        ? 0
        : existing.originalAmount.minorUnits - existing.outstandingAmount.minorUnits;
    String? error;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(existing != null
                ? strings.editRecord
                : selectedDirection == DebtDirection.creditor
                    ? strings.addCreditorDebt
                    : strings.addDebtorDebt),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  key: const Key('debt-person'),
                  controller: counterparty,
                  decoration: InputDecoration(labelText: strings.counterparty),
                ),
                TextField(
                  key: const Key('debt-amount'),
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: strings.calculatorAmount,
                    suffixIcon: calculatorSuffix(context, amount, strings),
                  ),
                ),
                TextField(
                  key: const Key('debt-date'),
                  controller: date,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: strings.recordedAt,
                    hintText: 'YYYY-MM-DD',
                    suffixIcon: calendarSuffix(context, date, strings, monthOnly: false),
                  ),
                ),
                TextField(
                  key: const Key('debt-note'),
                  controller: note,
                  decoration: InputDecoration(labelText: strings.note),
                ),
                if (error != null)
                  Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ]),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(strings.cancel),
              ),
              FilledButton(
                onPressed: () async {
                  final value = int.tryParse(amount.text.trim());
                  final selectedDate = DateTime.tryParse(date.text.trim());
                  if (counterparty.text.trim().isEmpty ||
                      value == null ||
                      value <= 0 ||
                      value < previouslyPaid ||
                      selectedDate == null) {
                    setDialogState(() => error = strings.invalidRecord);
                    return;
                  }
                  try {
                    await ref.read(debtRepositoryProvider).save(
                      DebtEntry(
                        id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
                        direction: selectedDirection,
                        originalAmount: Money.fromMinorUnits(value),
                        outstandingAmount: Money.fromMinorUnits(value - previouslyPaid),
                        dueMonth: MonthKey(year: selectedDate.year, month: selectedDate.month),
                        createdAt: selectedDate,
                        counterparty: counterparty.text.trim(),
                        note: note.text.trim().isEmpty ? null : note.text.trim(),
                      ),
                    );
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  } catch (_) {
                    setDialogState(() => error = strings.invalidRecord);
                  }
                },
                child: Text(strings.save),
              ),
            ],
          ),
        ),
      );
    } finally {
      await WidgetsBinding.instance.endOfFrame;
      counterparty.dispose();
      amount.dispose();
      date.dispose();
      note.dispose();
    }
  }

  Future<void> _recordPayment(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations strings,
    DebtEntry debt,
  ) async {
    final amount = TextEditingController();
    final now = DateTime.now();
    final paidAt = TextEditingController(text: formatCalendarDate(now));
    var paymentTime = TimeOfDay.fromDateTime(now);
    final paidTime = TextEditingController(text: paymentTime.format(context));
    final note = TextEditingController();
    String? error;
    try {
      final dialogRoute = DialogRoute<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(strings.recordDebtPayment),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                Text(
                  '${strings.outstandingAmount}: ${debt.outstandingAmount.minorUnits}',
                ),
                TextField(
                  controller: amount,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: strings.paymentAmount, suffixIcon: calculatorSuffix(context, amount, strings)),
                ),
                TextField(
                  controller: paidAt,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: strings.paidAt,
                    suffixIcon: calendarSuffix(context, paidAt, strings, monthOnly: false),
                  ),
                ),
                TextField(
                  controller: paidTime,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: strings.time,
                    suffixIcon: IconButton(
                      tooltip: strings.time,
                      icon: const Icon(Icons.access_time),
                      onPressed: () async {
                        final selectedTime = await showTimePicker(
                          context: dialogContext,
                          initialTime: paymentTime,
                        );
                        if (selectedTime == null || !dialogContext.mounted) {
                          return;
                        }
                        setDialogState(() {
                          paymentTime = selectedTime;
                          paidTime.text = selectedTime.format(dialogContext);
                        });
                      },
                    ),
                  ),
                ),
                TextField(
                  controller: note,
                  decoration: InputDecoration(labelText: strings.note),
                ),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(strings.cancel),
              ),
              FilledButton(
                onPressed: () async {
                  final value = int.tryParse(amount.text.trim());
                  final paymentDay = DateTime.tryParse(paidAt.text.trim());
                  if (paymentDay == null || value == null ||
                      value <= 0 ||
                      value > debt.outstandingAmount.minorUnits) {
                    setDialogState(() => error = strings.invalidRecord);
                    return;
                  }
                  try {
                    final paymentDate = DateTime(
                      paymentDay.year,
                      paymentDay.month,
                      paymentDay.day,
                      paymentTime.hour,
                      paymentTime.minute,
                    );
                    await ref
                        .read(debtRepositoryProvider)
                        .recordPayment(
                          DebtPayment(
                            id: DateTime.now().microsecondsSinceEpoch
                                .toString(),
                            debtId: debt.id,
                            amount: Money.fromMinorUnits(value),
                            paidAt: paymentDate,
                            note: note.text.trim().isEmpty
                                ? null
                                : note.text.trim(),
                          ),
                        );
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  } catch (_) {
                    setDialogState(() => error = strings.invalidRecord);
                  }
                },
                child: Text(strings.save),
              ),
            ],
          ),
        ),
      );
      await Navigator.of(context).push(dialogRoute);
      await dialogRoute.completed;
    } finally {
      amount.dispose();
      paidAt.dispose();
      paidTime.dispose();
      note.dispose();
    }
  }

  Future<void> _deleteDebt(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations strings,
    String id,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.deleteRecord),
        content: Text(strings.confirmDelete),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) await ref.read(debtRepositoryProvider).delete(id);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    ref.listen<int>(debtAddRequestProvider, (previous, next) {
      if (next <= (previous ?? 0)) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showDebtAddOptions(context, ref, strings);
      });
    });
    final tokens = AppDesignTokens.of(context);
    final debts = ref.watch(debtsProvider);
    final selectedMonth = ref.watch(selectedMonthProvider);
    return Scaffold(
      body: Column(
        children: [
          SectionPillTabs(
            keyPrefix: 'debts-tab',
            labels: ['دين لك (${strings.creditor})', 'دين عليك (${strings.debtor})'],
            selectedIndex: _activeTab,
            onSelected: (index) => setState(() => _activeTab = index),
          ),
          Padding(
            padding: tokens.pageInsets(bottom: 8),
            child: MonthSelector(
              pickerKey: const Key('debts-selected-month-picker'),
              selectedMonth: selectedMonth,
              availableMonths: {
                MonthKey(year: DateTime.now().year, month: DateTime.now().month),
                selectedMonth,
                ...(debts.value ?? const []).map((debt) => debt.dueMonth),
              }.toList()..sort((a, b) => b.compareTo(a)),
              onChanged: (value) =>
                  ref.read(selectedMonthProvider.notifier).select(value),
            ),
          ),
          _debtSummaryCard(
            context,
            strings,
            (debts.value ?? const [])
                .where((debt) => debt.dueMonth == selectedMonth)
                .toList(),
          ),
          Expanded(child: debts.when(
        loading: () => Center(child: Text(strings.loading)),
        error: (error, stackTrace) => Center(child: Text(strings.dataError)),
        data: (items) {
          final selectedDirection = _activeTab == 0 ? DebtDirection.creditor : DebtDirection.debtor;
          final visibleItems = items
              .where((debt) => debt.direction == selectedDirection && debt.dueMonth == selectedMonth)
              .toList();
          return visibleItems.isEmpty
              ? Center(child: Text(strings.noRecords))
              : ListView.separated(
                padding: tokens.pageInsets(),
                itemCount: visibleItems.length,
                separatorBuilder: (context, index) => SizedBox(height: tokens.sectionSpacing / 2),
                itemBuilder: (context, index) {
                  final debt = visibleItems[index];
                  final direction = debt.direction == DebtDirection.creditor
                      ? strings.creditor
                      : strings.debtor;
                  final original = debt.originalAmount.minorUnits;
                  final remaining = debt.outstandingAmount.minorUnits;
                  final paid = original - remaining;
                  final progress = original == 0
                      ? 0.0
                      : (paid / original).clamp(0.0, 1.0);
                  final badge = Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: debt.direction == DebtDirection.creditor
                          ? Theme.of(context).colorScheme.tertiaryContainer
                          : Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(tokens.controlRadius),
                    ),
                    child: Text(
                      direction,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color:
                                debt.direction == DebtDirection.creditor
                                    ? Theme.of(context)
                                        .colorScheme
                                        .onTertiaryContainer
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSecondaryContainer,
                          ),
                    ),
                  );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: FinancialRecordCard(
                      icon: debt.direction == DebtDirection.creditor
                          ? Icons.call_received_outlined
                          : Icons.call_made_outlined,
                      title: debt.counterparty,
                      amount: debt.outstandingAmount.minorUnits.toString(),
                      amountLabel: strings.outstandingAmount,
                      details: [
                        toAsciiDigits(MaterialLocalizations.of(context).formatFullDate(debt.createdAt)),
                        '${strings.originalAmount}: ${debt.originalAmount.minorUnits}',
                      ],
                      badge: badge,
                      footer: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 7,
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              color: Theme.of(context).colorScheme.tertiary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              if (!debt.isSettled)
                                FilledButton.tonalIcon(
                                  onPressed: () => _recordPayment(
                                    context,
                                    ref,
                                    strings,
                                    debt,
                                  ),
                                  icon: const Icon(Icons.payments_outlined),
                                  label: Text(strings.recordDebtPayment),
                                )
                              else
                                Chip(
                                  avatar: const Icon(
                                    Icons.check_circle_outline,
                                    size: 18,
                                  ),
                                  label: Text(strings.settled),
                                  visualDensity: VisualDensity.compact,
                                ),
                              IconButton(
                                tooltip: strings.editRecord,
                                onPressed: () => _editDebt(
                                  context,
                                  ref,
                                  strings,
                                  existing: debt,
                                ),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: strings.deleteRecord,
                                onPressed: () =>
                                    _deleteDebt(context, ref, strings, debt.id),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                          TextButton.icon(
                            key: Key('debt-payment-history-${debt.id}'),
                            onPressed: () {
                              showDialog<void>(
                                context: context,
                                builder: (dialogContext) => Consumer(
                                  builder: (context, ref, child) {
                                    final payments = ref.watch(
                                      debtPaymentsProvider(debt.id),
                                    );
                                    return AlertDialog(
                                      scrollable: true,
                                      title: Text(strings.paymentHistory),
                                      content: SizedBox(
                                        width: double.maxFinite,
                                        child: payments.when(
                                          loading: () => Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Text(strings.loading),
                                          ),
                                          error: (error, stackTrace) => Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Text(strings.dataError),
                                          ),
                                          data: (history) => history.isEmpty
                                              ? Padding(
                                                  padding: const EdgeInsets.all(12),
                                                  child: Text(strings.noRecords),
                                                )
                                              : Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    for (final payment in history)
                                                      ListTile(
                                                        dense: true,
                                                        contentPadding:
                                                            EdgeInsets.zero,
                                                        leading: const Icon(
                                                          Icons.receipt_long_outlined,
                                                        ),
                                                        title: Text(
                                                          payment.amount.minorUnits
                                                              .toString(),
                                                          style: Theme.of(context)
                                                              .textTheme
                                                              .titleSmall
                                                              ?.copyWith(
                                                                fontWeight:
                                                                    FontWeight.w700,
                                                              ),
                                                        ),
                                                        subtitle: Text(
                                                          '${strings.paidAt}: ${toAsciiDigits(MaterialLocalizations.of(context).formatFullDate(payment.paidAt))}'
                                                          '\n${strings.time}: ${TimeOfDay.fromDateTime(payment.paidAt).format(context)}'
                                                          '${payment.note == null ? '' : '\n${payment.note}'}',
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(dialogContext),
                                          child: Text(strings.cancel),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              );
                            },
                            icon: const Icon(Icons.history),
                            label: Text(strings.paymentHistory),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
        },
      )),
        ],
      ),
    );
  }

  Widget _debtSummaryCard(
    BuildContext context,
    AppLocalizations strings,
    List<DebtEntry> items,
  ) {
    final creditor = items
        .where((item) => item.direction == DebtDirection.creditor)
        .fold<int>(0, (sum, item) => sum + item.outstandingAmount.minorUnits);
    final debtor = items
        .where((item) => item.direction == DebtDirection.debtor)
        .fold<int>(0, (sum, item) => sum + item.outstandingAmount.minorUnits);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: SummaryMetricGrid(
        metrics: [
          SummaryMetricData(
            title: strings.totalCreditor,
            value: creditor.toString(),
            icon: Icons.call_received_outlined,
          ),
          SummaryMetricData(
            title: strings.totalDebtor,
            value: debtor.toString(),
            icon: Icons.call_made_outlined,
            emphasized: true,
          ),
        ],
      ),
    );
  }
}
