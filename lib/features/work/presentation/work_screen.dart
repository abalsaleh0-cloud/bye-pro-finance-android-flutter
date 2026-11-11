import 'package:expense_app/core/database/database_providers.dart';
import 'package:expense_app/features/work/domain/work_entry.dart';
import 'package:expense_app/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class WorkScreen extends ConsumerWidget {
  const WorkScreen({super.key});

  String _kindLabel(AppLocalizations strings, WorkEntryKind kind) {
    return switch (kind) {
      WorkEntryKind.salary => strings.salary,
      WorkEntryKind.advance => strings.advance,
      WorkEntryKind.payment => strings.payment,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppLocalizations.of(context)!;
    final entries = ref.watch(workEntriesProvider);
    final transfers = ref.watch(workTransfersProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(strings.entries, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        entries.when(
          loading: () => Text(strings.loading),
          error: (error, stackTrace) => Text(strings.dataError),
          data: (items) => items.isEmpty
              ? Text(strings.noRecords)
              : Column(
                  children: [
                    for (final entry in items)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.work_outline),
                          title: Text(_kindLabel(strings, entry.kind)),
                          subtitle: Text(
                            '${strings.dueMonth}: ${entry.dueMonth}',
                          ),
                          trailing: Text(entry.amount.minorUnits.toString()),
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 20),
        Text(
          strings.transfers,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        transfers.when(
          loading: () => Text(strings.loading),
          error: (error, stackTrace) => Text(strings.dataError),
          data: (items) => items.isEmpty
              ? Text(strings.noRecords)
              : Column(
                  children: [
                    for (final transfer in items)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.swap_horiz),
                          title: Text(strings.transfers),
                          subtitle: Text(
                            transfer.transferredAt.toLocal().toString().split(' ').first,
                          ),
                          trailing: Text(transfer.amount.minorUnits.toString()),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
