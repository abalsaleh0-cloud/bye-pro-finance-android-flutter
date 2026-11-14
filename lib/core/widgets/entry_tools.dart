import 'package:expense_app/core/money/calculator_expression.dart';
import 'package:expense_app/l10n/generated/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

Future<String?> showAmountCalculator(
  BuildContext context,
  AppLocalizations strings,
) => showDialog<String>(
  context: context,
  builder: (_) => _AmountCalculatorDialog(strings: strings),
);

enum _CalculatorMode { scientific, financial }

enum _FinancialMode { percentage, discount, split }

class _CalculatorHistoryEntry {
  const _CalculatorHistoryEntry(this.expression, this.result);

  final String expression;
  final String result;
}

class _AmountCalculatorDialog extends StatefulWidget {
  const _AmountCalculatorDialog({required this.strings});

  final AppLocalizations strings;

  @override
  State<_AmountCalculatorDialog> createState() =>
      _AmountCalculatorDialogState();
}

class _AmountCalculatorDialogState extends State<_AmountCalculatorDialog> {
  final expression = TextEditingController();
  final amount = TextEditingController();
  final percentage = TextEditingController();
  final people = TextEditingController();
  final history = <_CalculatorHistoryEntry>[];

  _CalculatorMode mode = _CalculatorMode.scientific;
  _FinancialMode financialMode = _FinancialMode.percentage;
  String? resultText;
  String? errorText;
  String? resultForInsertion;

  static const _keys = [
    'AC', '(', ')', '%', '⌫',
    '7', '8', '9', '÷', '√',
    '4', '5', '6', '×', 'x²',
    '1', '2', '3', '−', '^',
    '0', '.', '±', '+', '=',
  ];

  @override
  void dispose() {
    expression.dispose();
    amount.dispose();
    percentage.dispose();
    people.dispose();
    super.dispose();
  }

  void _clearResult() {
    resultText = null;
    errorText = null;
    resultForInsertion = null;
  }

  void _appendToken(String token) {
    final current = expression.text;
    final startsNewValue = resultText != null &&
        RegExp(r'^[0-9.]$').hasMatch(token);
    final next = (startsNewValue ? '' : current) + token;
    expression.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    setState(_clearResult);
  }

  void _pressKey(String key) {
    switch (key) {
      case 'AC':
        expression.clear();
        setState(_clearResult);
        break;
      case '⌫':
        final current = expression.text;
        if (current.isNotEmpty) {
          expression.text = current.substring(0, current.length - 1);
          expression.selection = TextSelection.collapsed(
            offset: expression.text.length,
          );
        }
        setState(_clearResult);
        break;
      case '√':
        _appendToken('√(');
        break;
      case 'x²':
        _appendToken('^2');
        break;
      case '±':
        final current = expression.text.trim();
        if (current.isNotEmpty) {
          expression.text = '-($current)';
          expression.selection = TextSelection.collapsed(
            offset: expression.text.length,
          );
          setState(_clearResult);
        } else {
          _appendToken('−');
        }
        break;
      case '=':
        _calculateExpression();
        break;
      default:
        _appendToken(key);
        break;
    }
  }

  void _calculateExpression() {
    final source = expression.text.trim();
    try {
      final value = calculateCalculatorExpression(source);
      final formatted = formatCalculatorValue(value);
      setState(() {
        resultText = formatted;
        resultForInsertion = calculatorValueAsMinorUnits(value)?.toString();
        errorText = null;
        _addHistory(source, formatted);
      });
    } on FormatException {
      setState(() {
        resultText = null;
        resultForInsertion = null;
        errorText = widget.strings.calculatorInvalidExpression;
      });
    }
  }

  void _calculateFinancial() {
    final amountValue = BigInt.tryParse(amount.text.trim());
    if (amountValue == null || amountValue < BigInt.zero) {
      setState(() {
        resultText = null;
        resultForInsertion = null;
        errorText = widget.strings.calculatorInvalidFinancialInputs;
      });
      return;
    }

    if (financialMode == _FinancialMode.split) {
      final peopleValue = BigInt.tryParse(people.text.trim());
      final split = peopleValue == null
          ? null
          : splitMinorUnits(amountValue, peopleValue);
      if (split == null) {
        setState(() {
          resultText = null;
          resultForInsertion = null;
          errorText = widget.strings.calculatorInvalidFinancialInputs;
        });
        return;
      }
      final formatted =
          '${widget.strings.calculatorPerPerson}: ${split.perPerson} · '
          '${widget.strings.calculatorRemainder}: ${split.remainder}';
      setState(() {
        resultText = formatted;
        resultForInsertion = _toInsertableAmount(split.perPerson);
        errorText = null;
        _addHistory(
          '${widget.strings.calculatorSplit}: $amountValue / $peopleValue',
          formatted,
        );
      });
      return;
    }

    final percentageText = percentage.text.trim();
    final value = financialMode == _FinancialMode.percentage
        ? calculatePercentageOfMinorUnits(amountValue, percentageText)
        : calculateDiscountedMinorUnits(amountValue, percentageText);
    if (value == null) {
      setState(() {
        resultText = null;
        resultForInsertion = null;
        errorText = widget.strings.calculatorInvalidFinancialInputs;
      });
      return;
    }

    final label = financialMode == _FinancialMode.percentage
        ? widget.strings.calculatorPercentage
        : widget.strings.calculatorDiscount;
    final formatted = '${widget.strings.result}: $value';
    setState(() {
      resultText = formatted;
      resultForInsertion = _toInsertableAmount(value);
      errorText = null;
      _addHistory(
        '$label: $amountValue · $percentageText%',
        value.toString(),
      );
    });
  }

  String? _toInsertableAmount(BigInt value) {
    if (value < BigInt.zero) return null;
    return int.tryParse(value.toString())?.toString();
  }

  void _addHistory(String source, String answer) {
    history.add(_CalculatorHistoryEntry(source, answer));
    if (history.length > 20) history.removeAt(0);
  }

  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(widget.strings.calculatorCopied)),
    );
  }

  void _reuse(String value) {
    expression.text = value;
    expression.selection = TextSelection.collapsed(offset: value.length);
    setState(() {
      mode = _CalculatorMode.scientific;
      _clearResult();
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    final screenSize = MediaQuery.sizeOf(context);
    final dialogWidth = (screenSize.width - 80).clamp(0.0, 440.0).toDouble();

    return AlertDialog(
      title: Text(strings.calculator),
      content: SizedBox(
        width: dialogWidth,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: screenSize.height * 0.68),
          child: SingleChildScrollView(
            child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  key: const Key('calculator-scientific-mode'),
                  label: Text(strings.calculatorScientific),
                  selected: mode == _CalculatorMode.scientific,
                  onSelected: (_) => setState(() {
                    mode = _CalculatorMode.scientific;
                    _clearResult();
                  }),
                ),
                ChoiceChip(
                  key: const Key('calculator-financial-mode'),
                  label: Text(strings.calculatorFinancial),
                  selected: mode == _CalculatorMode.financial,
                  onSelected: (_) => setState(() {
                    mode = _CalculatorMode.financial;
                    _clearResult();
                  }),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (mode == _CalculatorMode.scientific)
              _buildScientificCalculator(strings)
            else
              _buildFinancialCalculator(strings),
            if (errorText != null) ...[
              const SizedBox(height: 10),
              Text(
                errorText!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            if (resultText != null) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SelectableText(
                        resultText!,
                        key: const Key('calculator-result'),
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (resultForInsertion == null) ...[
                        const SizedBox(height: 6),
                        Text(
                          strings.calculatorUseResultUnavailable,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: IconButton(
                          tooltip: strings.calculatorCopy,
                          onPressed: () => _copy(resultText!),
                          icon: const Icon(Icons.copy_outlined),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (history.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      strings.calculatorHistory,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(history.clear),
                    child: Text(strings.calculatorClearHistory),
                  ),
                ],
              ),
              ...history.reversed.take(5).map(
                (entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.expression,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              entry.result,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: strings.calculatorReuse,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _reuse(entry.result),
                        icon: const Icon(Icons.replay_outlined),
                      ),
                      IconButton(
                        tooltip: strings.calculatorCopy,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _copy(entry.result),
                        icon: const Icon(Icons.copy_outlined),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(strings.cancel),
        ),
        FilledButton(
          onPressed: resultForInsertion == null
              ? null
              : () => Navigator.pop(context, resultForInsertion),
          child: Text(strings.useResult),
        ),
      ],
    );
  }

  Widget _buildScientificCalculator(AppLocalizations strings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('calculator-expression'),
          controller: expression,
          readOnly: true,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.end,
          onChanged: (_) => setState(_clearResult),
          decoration: InputDecoration(
            labelText: strings.calculatorExpression,
            hintText: '0',
            suffixIcon: IconButton(
              tooltip: strings.calculatorClear,
              onPressed: () {
                expression.clear();
                setState(_clearResult);
              },
              icon: const Icon(Icons.backspace_outlined),
            ),
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 5,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 1.28,
          children: _keys.map((key) {
            if (key == '=') {
              return FilledButton(
                key: const Key('calculator-key-equals'),
                onPressed: _calculateExpression,
                child: Text(key, style: const TextStyle(fontSize: 20)),
              );
            }
            return OutlinedButton(
              key: Key('calculator-key-$key'),
              onPressed: () => _pressKey(key),
              style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
              child: Text(key, style: const TextStyle(fontSize: 17)),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFinancialCalculator(AppLocalizations strings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          strings.calculatorMoneyUnitHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ChoiceChip(
              label: Text(strings.calculatorPercentage),
              selected: financialMode == _FinancialMode.percentage,
              onSelected: (_) => setState(() {
                financialMode = _FinancialMode.percentage;
                _clearResult();
              }),
            ),
            ChoiceChip(
              label: Text(strings.calculatorDiscount),
              selected: financialMode == _FinancialMode.discount,
              onSelected: (_) => setState(() {
                financialMode = _FinancialMode.discount;
                _clearResult();
              }),
            ),
            ChoiceChip(
              label: Text(strings.calculatorSplit),
              selected: financialMode == _FinancialMode.split,
              onSelected: (_) => setState(() {
                financialMode = _FinancialMode.split;
                _clearResult();
              }),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          key: const Key('calculator-financial-amount'),
          controller: amount,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(_clearResult),
          decoration: InputDecoration(
            labelText: strings.calculatorAmount,
            suffixText: strings.amountMinorUnits,
          ),
        ),
        const SizedBox(height: 8),
        if (financialMode == _FinancialMode.split)
          TextField(
            key: const Key('calculator-financial-people'),
            controller: people,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(_clearResult),
            decoration: InputDecoration(
              labelText: strings.calculatorPeople,
            ),
          )
        else
          TextField(
            key: const Key('calculator-financial-percentage'),
            controller: percentage,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            onChanged: (_) => setState(_clearResult),
            decoration: InputDecoration(
              labelText: strings.calculatorPercent,
              suffixText: '%',
            ),
          ),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const Key('calculator-financial-calculate'),
          onPressed: _calculateFinancial,
          icon: const Icon(Icons.calculate_outlined),
          label: Text(strings.calculate),
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
