import 'package:expense_app/core/money/integer_calculator.dart';
import 'package:expense_app/core/time/calendar_date.dart';
import 'package:expense_app/l10n/generated/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

Future<String?> showAmountCalculator(
  BuildContext context,
  AppLocalizations strings,
) => showDialog<String>(
  context: context,
  builder: (_) => _AmountCalculatorDialog(strings: strings),
);

class _AmountCalculatorDialog extends StatefulWidget {
  const _AmountCalculatorDialog({required this.strings});

  final AppLocalizations strings;

  @override
  State<_AmountCalculatorDialog> createState() =>
      _AmountCalculatorDialogState();
}

class _AmountCalculatorDialogState extends State<_AmountCalculatorDialog> {
  final first = TextEditingController();
  final second = TextEditingController();
  String operation = '+';
  String? result;
  String? error;

  @override
  void dispose() {
    first.dispose();
    second.dispose();
    super.dispose();
  }

  void calculate() {
    final a = BigInt.tryParse(first.text.trim());
    final b = BigInt.tryParse(second.text.trim());
    if (a == null || b == null) {
      setState(() {
        result = null;
        error = widget.strings.invalidCalculation;
      });
      return;
    }
    final value = calculateIntegerAmount(a, b, operation);
    if (value == null) {
      setState(() {
        result = null;
        error = widget.strings.invalidCalculation;
      });
      return;
    }
    setState(() {
      result = value.toString();
      error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    return AlertDialog(
      title: Text(strings.calculator),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: first,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: strings.firstNumber),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: operation,
            decoration: InputDecoration(labelText: strings.operation),
            items: ['+', '-', '×', '÷']
                .map((value) => DropdownMenuItem(
                      value: value,
                      child: Text(value),
                    ))
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => operation = value);
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: second,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: strings.secondNumber),
          ),
          if (result != null) ...[
            const SizedBox(height: 12),
            SelectableText('${strings.result}: $result'),
          ],
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(strings.cancel),
        ),
        TextButton(
          onPressed: calculate,
          child: Text(strings.calculate),
        ),
        FilledButton(
          onPressed: result == null
              ? null
              : () => Navigator.pop(context, result),
          child: Text(strings.useResult),
        ),
      ],
    );
  }
}

Widget calculatorSuffix(
  BuildContext context,
  TextEditingController controller,
  AppLocalizations strings,
) => IconButton(
  tooltip: strings.calculator,
  icon: const Icon(Icons.calculate_outlined),
  onPressed: () async {
    final value = await showAmountCalculator(context, strings);
    if (context.mounted && value != null) controller.text = value;
  },
);

Widget calendarSuffix(
  BuildContext context,
  TextEditingController controller,
  AppLocalizations strings, {
  required bool monthOnly,
}) => IconButton(
  tooltip: strings.calendar,
  icon: const Icon(Icons.calendar_month_outlined),
  onPressed: () async {
    final parts = controller.text.trim().split('-');
    final year = parts.isNotEmpty ? int.tryParse(parts[0]) : null;
    final month = parts.length > 1 ? int.tryParse(parts[1]) : null;
    final day = !monthOnly && parts.length > 2
        ? int.tryParse(parts[2])
        : null;
    final now = DateTime.now();
    final safeYear = (year ?? now.year).clamp(1900, 2100).toInt();
    final safeMonth = (month ?? now.month).clamp(1, 12).toInt();
    final maxDay = DateTime(safeYear, safeMonth + 1, 0).day;
    final safeDay = (day ?? 1).clamp(1, maxDay).toInt();
    final initial = DateTime(safeYear, safeMonth, safeDay);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (!context.mounted || picked == null) return;
    final y = picked.year.toString().padLeft(4, '0');
    final m = picked.month.toString().padLeft(2, '0');
    final d = picked.day.toString().padLeft(2, '0');
    controller.text = monthOnly ? '$y-$m' : '$y-$m-$d';
  },
);
