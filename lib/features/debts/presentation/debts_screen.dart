import 'package:expense_app/core/database/database_providers.dart';
import 'package:expense_app/features/debts/domain/debt_entry.dart';
import 'package:expense_app/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class DebtsScreen extends ConsumerWidget {
  const DebtsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppLocalizations.of(context)!;
    final debts = ref.watch(debtsProvider);

    return debts.when(
      loading: () => Center(child: Text(strings.loading)),
      error: (error, stackTrace) => Center(child: Text(strings.dataError)),
      data: (items) {
        if (items.isEmpty) return Center(child: Text(strings.noRecords));

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final debt = items[index];
            final direction = debt.direction == DebtDirection.creditor
                ? strings.creditor
                : strings.debtor;
            return Card(
              child: ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: Text('${debt.counterparty} • $direction'),
                subtitle: Text(
                  '${strings.dueMonth}: ${debt.dueMonth} | '
                  '${strings.originalAmount}: ${debt.originalAmount.minorUnits}',
                ),
                trailing: Text(
                  debt.outstandingAmount.minorUnits.toString(),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
