import 'package:expense_app/core/database/database_providers.dart';
import 'package:expense_app/core/money/money.dart';
import 'package:expense_app/core/money/format_minor_units.dart';
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
  String _searchQuery = '';
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

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
                  decoration: InputDecoration(labelText: strings.personName),
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
                    ref.invalidate(debtActivityProvider);
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
                    ref.invalidate(debtActivityProvider);
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

  Future<void> _undoDebtPayment(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations strings,
    DebtEntry debt,
    DebtPayment payment,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.undoDebtPayment),
        content: Text(strings.confirmUndoDebtPayment),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(strings.undoDebtPayment),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      if (debt.direction == DebtDirection.debtor) {
        await ref.read(homeExpenseRepositoryProvider).undoDebtRepayment(payment.id);
      } else {
        await ref.read(debtRepositoryProvider).undoPayment(payment.id);
      }
      ref.invalidate(debtsProvider);
      ref.invalidate(debtActivityProvider);
      ref.invalidate(homeExpensesProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.invalidRecord)),
        );
      }
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
    if (confirmed == true) {
      try {
        await ref.read(debtRepositoryProvider).delete(id);
        ref.invalidate(debtActivityProvider);
        ref.invalidate(debtsProvider);
      } on StateError {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(strings.debtHasPaymentHistory)),
          );
        }
      }
    }
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
            labels: [
              'دين لك (${strings.creditor})',
              'دين عليك (${strings.debtor})',
              strings.debtActivity,
            ],
            selectedIndex: _activeTab,
            onSelected: (index) {
              setState(() => _activeTab = index);
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
              );
            },
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
          Padding(
            padding: tokens.pageInsets(bottom: 8),
            child: TextField(
              key: const Key('debt-record-search'),
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: strings.searchRecords,
                suffixIcon: _searchQuery.isEmpty ? null : IconButton(
                  tooltip: strings.clearSearch,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => setState(() => _searchQuery = ''),
                ),
              ),
            ),
          ),
          if (_activeTab < 2)
            _debtSummaryCard(
              context,
              strings,
              (debts.value ?? const [])
                  .where((debt) => debt.dueMonth.compareTo(selectedMonth) <= 0)
                  .toList(),
              _activeTab == 0 ? DebtDirection.creditor : DebtDirection.debtor,
            ),
          Expanded(
            child: debts.when(
              loading: () => Center(child: Text(strings.loading)),
              error: (error, stackTrace) => Center(child: Text(strings.dataError)),
              data: (items) => PageView(
                key: const Key('debts-section-pages'),
                controller: _pageController,
                onPageChanged: (index) => setState(() => _activeTab = index),
                children: [
                  _buildDebtDirectionPage(
                    context, ref, strings, items, DebtDirection.creditor,
                    selectedMonth, tokens,
                  ),
                  _buildDebtDirectionPage(
                    context, ref, strings, items, DebtDirection.debtor,
                    selectedMonth, tokens,
                  ),
                  _buildDebtActivityPage(context, ref, strings, selectedMonth, tokens),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildDebtDirectionPage(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations strings,
    List<DebtEntry> items,
    DebtDirection direction,
    MonthKey selectedMonth,
    AppDesignTokens tokens,
  ) {
    final query = _searchQuery.trim().toLowerCase();
    final visibleItems = items.where((debt) =>
      debt.direction == direction &&
      debt.dueMonth.compareTo(selectedMonth) <= 0 &&
      (debt.dueMonth == selectedMonth || !debt.isSettled) &&
      (debt.counterparty.toLowerCase().contains(query) ||
       (debt.note ?? '').toLowerCase().contains(query) ||
       debt.originalAmount.minorUnits.toString().contains(query) ||
       formatMinorUnits(context, debt.originalAmount.minorUnits).contains(query) ||
       formatMinorUnits(context, debt.outstandingAmount.minorUnits).contains(query))
    ).toList(growable: false);

    if (visibleItems.isEmpty) return Center(child: Text(strings.noRecords));
    return ListView.separated(
      key: Key(direction == DebtDirection.creditor ? 'debt-creditor-page' : 'debt-debtor-page'),
      padding: tokens.pageInsets(),
      itemCount: visibleItems.length,
      separatorBuilder: (context, index) => SizedBox(height: tokens.sectionSpacing / 2),
      itemBuilder: (context, index) {
        final debt = visibleItems[index];
        final isCreditor = debt.direction == DebtDirection.creditor;
        final original = debt.originalAmount.minorUnits;
        final remaining = debt.outstandingAmount.minorUnits;
        final paid = original - remaining;
        final progress = original == 0 ? 0.0 : (paid / original).clamp(0.0, 1.0);
        final badge = Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isCreditor
                ? Theme.of(context).colorScheme.tertiaryContainer
                : Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(tokens.controlRadius),
          ),
          child: Text(
            isCreditor ? strings.creditor : strings.debtor,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: isCreditor
                  ? Theme.of(context).colorScheme.onTertiaryContainer
                  : Theme.of(context).colorScheme.onSecondaryContainer,
            ),
          ),
        );
        return FinancialRecordCard(
          icon: isCreditor ? Icons.call_received_outlined : Icons.call_made_outlined,
          title: debt.counterparty,
          amount: formatMinorUnits(context, remaining),
          amountLabel: strings.outstandingAmount,
          details: [
            toAsciiDigits(MaterialLocalizations.of(context).formatFullDate(debt.createdAt)),
            '${strings.originalAmount}: ${formatMinorUnits(context, original)}',
          ],
          badge: badge,
          footer: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(tokens.controlRadius),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 7,
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (!debt.isSettled && isCreditor)
                    FilledButton.tonalIcon(
                      onPressed: () => _recordPayment(context, ref, strings, debt),
                      icon: const Icon(Icons.payments_outlined),
                      label: Text(strings.recordDebtPayment),
                    ),
                  if (!debt.isSettled && !isCreditor)
                    Chip(
                      avatar: const Icon(Icons.home_outlined, size: 18),
                      label: Text(strings.debtRepaymentInHome),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (debt.isSettled)
                    Chip(
                      avatar: const Icon(Icons.check_circle_outline, size: 18),
                      label: Text(strings.settled),
                      visualDensity: VisualDensity.compact,
                    ),
                  IconButton(
                    tooltip: strings.editRecord,
                    onPressed: () => _editDebt(context, ref, strings, existing: debt),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: strings.deleteRecord,
                    onPressed: () => _deleteDebt(context, ref, strings, debt.id),
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
                        final payments = ref.watch(debtPaymentsProvider(debt.id));
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
                                            contentPadding: EdgeInsets.zero,
                                            leading: const Icon(Icons.receipt_long_outlined),
                                            title: Text(
                                              formatMinorUnits(context, payment.amount.minorUnits),
                                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            subtitle: Text(
                                              '${strings.paidAt}: ${toAsciiDigits(MaterialLocalizations.of(context).formatFullDate(payment.paidAt))}'
                                              '\n${strings.time}: ${TimeOfDay.fromDateTime(payment.paidAt).format(context)}'
                                              '${payment.note == null ? '' : '\n${payment.note}'}',
                                            ),
                                            trailing: IconButton(
                                              tooltip: strings.undoDebtPayment,
                                              icon: const Icon(Icons.undo_rounded),
                                              onPressed: () => _undoDebtPayment(
                                                context,
                                                ref,
                                                strings,
                                                debt,
                                                payment,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
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
        );
      },
    );
  }

  Widget _buildDebtActivityPage(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations strings,
    MonthKey selectedMonth,
    AppDesignTokens tokens,
  ) {
    final activity = ref.watch(debtActivityProvider);
    return activity.when(
      loading: () => Center(child: Text(strings.loading)),
      error: (error, stackTrace) => Center(child: Text(strings.dataError)),
      data: (events) {
        final query = _searchQuery.trim().toLowerCase();
        final visible = events.where((event) {
          final date = event.occurredAt.toLocal();
          final eventMonth = MonthKey(year: date.year, month: date.month);
          return eventMonth.compareTo(selectedMonth) <= 0 &&
              ('${event.counterparty} ${event.note ?? ''} ${event.amountMinorUnits} '
                '${formatMinorUnits(context, event.amountMinorUnits)}')
                .toLowerCase().contains(query);
        }).toList(growable: false);
        if (visible.isEmpty) return Center(child: Text(strings.noRecords));
        return ListView.separated(
          key: const Key('debt-activity-page'),
          padding: tokens.pageInsets(),
          itemCount: visible.length,
          separatorBuilder: (context, index) => SizedBox(height: tokens.sectionSpacing / 2),
          itemBuilder: (context, index) {
            final event = visible[index];
            final eventTitle = switch (event.eventType) {
              'created' => strings.debtCreatedEvent,
              'updated' => strings.debtUpdatedEvent,
              'payment' => strings.debtPaymentEvent,
              'payment_reversed' => strings.debtPaymentReversedEvent,
              'deleted' => strings.debtDeletedEvent,
              'restored' => strings.debtRestoredEvent,
              _ => strings.debtActivity,
            };
            final direction = event.direction == DebtDirection.creditor.name
                ? strings.creditor
                : strings.debtor;
            final icon = switch (event.eventType) {
              'created' => Icons.add_circle_outline,
              'updated' => Icons.edit_note_outlined,
              'payment' => Icons.payments_outlined,
              'payment_reversed' => Icons.undo_rounded,
              'deleted' => Icons.delete_outline,
              'restored' => Icons.restore_rounded,
              _ => Icons.history,
            };
            return Card(
              child: ListTile(
                leading: Icon(icon),
                title: Text(eventTitle),
                subtitle: Text(
                  '${event.counterparty} • $direction • '
                  '${toAsciiDigits(MaterialLocalizations.of(context).formatFullDate(event.occurredAt))}'
                  '${event.note == null || event.note!.isEmpty ? '' : '\n${event.note}'}',
                ),
                isThreeLine: event.note != null && event.note!.isNotEmpty,
                trailing: Text(
                  formatMinorUnits(context, event.amountMinorUnits),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _debtSummaryCard(
    BuildContext context,
    AppLocalizations strings,
    List<DebtEntry> items,
    DebtDirection direction,
  ) {
    final total = items
        .where((item) => item.direction == direction)
        .fold<int>(0, (sum, item) => sum + item.outstandingAmount.minorUnits);
    final isCreditor = direction == DebtDirection.creditor;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: SummaryMetricGrid(
        metrics: [
          SummaryMetricData(
            title: isCreditor ? strings.totalCreditor : strings.totalDebtor,
            value: formatMinorUnits(context, total),
            icon: isCreditor ? Icons.call_received_outlined : Icons.call_made_outlined,
            emphasized: !isCreditor,
          ),
        ],
      ),
    );
  }
}
