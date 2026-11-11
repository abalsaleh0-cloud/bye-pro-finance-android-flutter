import 'package:expense_app/core/database/database_providers.dart';
import 'package:expense_app/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppLocalizations.of(context)!;
    final expenses = ref.watch(homeExpensesProvider);

    return expenses.when(
      loading: () => Center(child: Text(strings.loading)),
      error: (error, stackTrace) => Center(child: Text(strings.dataError)),
      data: (items) {
        if (items.isEmpty) return Center(child: Text(strings.noRecords));

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final expense = items[index];
            return Card(
              child: ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text(expense.categoryId),
                subtitle: Text('${strings.dueMonth}: ${expense.dueMonth}'),
                trailing: Text(expense.amount.minorUnits.toString()),
              ),
            );
          },
        );
      },
    );
  }
}
