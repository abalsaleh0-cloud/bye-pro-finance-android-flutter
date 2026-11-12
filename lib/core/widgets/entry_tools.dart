import 'package:expense_app/l10n/generated/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

Future<String?> showAmountCalculator(
  BuildContext context,
  AppLocalizations strings,
) async {
  final first = TextEditingController();
  final second = TextEditingController();
  var operation = '+';
  String? result;
  String? error;

  try {
    return await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
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
                  child: Text(error!, style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  )),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(strings.cancel),
            ),
            TextButton(
              onPressed: () {
                final a = BigInt.tryParse(first.text.trim());
                final b = BigInt.tryParse(second.text.trim());
                if (a == null || b == null ||
                    (operation == '÷' && (b == BigInt.zero || a.remainder(b) != BigInt.zero))) {
                  setState(() {
                    result = null;
                    error = strings.invalidCalculation;
                  });
                  return;
                }
                final value = switch (operation) {
                  '+' => a + b,
                  '-' => a - b,
                  '×' => a * b,
                  '÷' => a ~/ b,
                  _ => BigInt.zero,
                };
                setState(() {
                  result = value.toString();
                  error = null;
                });
              },
              child: Text(strings.calculate),
            ),
            FilledButton(
              onPressed: result == null
                  ? null
                  : () => Navigator.pop(dialogContext, result),
              child: Text(strings.useResult),
            ),
          ],
        ),
      ),
    );
  } finally {
    first.dispose();
    second.dispose();
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
    if (value != null) controller.text = value;
  },
);

String formatCalendarDate(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

Widget calendarSuffix(
  BuildContext context,
  TextEditingController controller,
  AppLocalizations strings, {
  required bool monthOnly,
}) => IconButton(
  tooltip: strings.calendar,
  icon: const Icon(Icons.calendar_month_outlined),
  onPressed: () async {
    final parts = controller.text.trim().split(monthOnly ? '-' : '-');
    final year = parts.isNotEmpty ? int.tryParse(parts[0]) : null;
    final month = parts.length > 1 ? int.tryParse(parts[1]) : null;
    final day = !monthOnly && parts.length > 2 ? int.tryParse(parts[2]) : null;
    final now = DateTime.now();
    final initial = DateTime(
      year != null && year > 0 ? year : now.year,
      month != null && month >= 1 && month <= 12 ? month : now.month,
      day != null && day >= 1 && day <= 31 ? day : 1,
    );
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    final y = picked.year.toString().padLeft(4, '0');
    final m = picked.month.toString().padLeft(2, '0');
    final d = picked.day.toString().padLeft(2, '0');
    controller.text = monthOnly ? '$y-$m' : '$y-$m-$d';
  },
);
