import 'package:expense_app/core/theme/app_theme.dart';
import 'package:expense_app/core/widgets/entry_form_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('shared entry dialog uses the same unified outer spacing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const EntryFormDialog(
                    title: Text('Title'),
                    content: Text('Content'),
                    actions: [],
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    expect(
      dialog.insetPadding,
      const EdgeInsets.all(16),
    );
  });
}
