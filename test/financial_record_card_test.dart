import 'package:expense_app/core/widgets/financial_record_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('financial record card groups details, amount and actions', (
    tester,
  ) async {
    var editCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FinancialRecordCard(
            icon: Icons.payments_outlined,
            title: 'راتب',
            amount: '150000',
            amountLabel: 'المبلغ المتبقي',
            details: const ['الشهر المستحق: 2026-11', 'ملاحظة الراتب'],
            actions: [
              IconButton(
                tooltip: 'تعديل',
                onPressed: () => editCount++,
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('راتب'), findsOneWidget);
    expect(find.textContaining('2026-11'), findsOneWidget);
    expect(find.textContaining('ملاحظة الراتب'), findsOneWidget);
    expect(find.text('المبلغ المتبقي'), findsOneWidget);
    expect(find.text('150000'), findsOneWidget);

    await tester.tap(find.byTooltip('تعديل'));
    await tester.pump();
    expect(editCount, 1);
  });

  testWidgets('financial record card supports a footer without action buttons', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FinancialRecordCard(
            icon: Icons.swap_horiz,
            title: 'تحويل إلى المنزل',
            amount: '75000',
            details: const ['2026-11-08'],
            footer: const Text('سجل الدفعات'),
          ),
        ),
      ),
    );

    expect(find.text('تحويل إلى المنزل'), findsOneWidget);
    expect(find.text('75000'), findsOneWidget);
    expect(find.text('سجل الدفعات'), findsOneWidget);
  });
}
