import 'package:expense_app/core/time/month_key.dart';
import 'package:expense_app/l10n/generated/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

class MonthSelector extends StatelessWidget {
  const MonthSelector({
    super.key,
    required this.pickerKey,
    required this.selectedMonth,
    required this.availableMonths,
    required this.onChanged,
  });

  final Key pickerKey;
  final MonthKey selectedMonth;
  final List<MonthKey> availableMonths;
  final ValueChanged<MonthKey> onChanged;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.calendar_month_outlined,
                    color: theme.colorScheme.onSecondaryContainer,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    strings.selectedMonth,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<MonthKey>(
              key: pickerKey,
              initialValue: selectedMonth,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
              items: availableMonths
                  .map(
                    (month) => DropdownMenuItem(
                      value: month,
                      child: Text(month.toString()),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) onChanged(value);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class SummaryMetricData {
  const SummaryMetricData({
    required this.title,
    required this.value,
    required this.icon,
    this.emphasized = false,
  });

  final String title;
  final String value;
  final IconData icon;
  final bool emphasized;
}

class SummaryMetricGrid extends StatelessWidget {
  const SummaryMetricGrid({
    super.key,
    required this.metrics,
  });

  final List<SummaryMetricData> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = metrics.length == 1
            ? 1
            : constraints.maxWidth >= 560
                ? 3
                : 2;
        final width = (constraints.maxWidth - (columns - 1) * 10) / columns;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: width,
                child: _SummaryMetricTile(metric: metric),
              ),
          ],
        );
      },
    );
  }
}

class _SummaryMetricTile extends StatelessWidget {
  const _SummaryMetricTile({required this.metric});

  final SummaryMetricData metric;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground =
        metric.emphasized ? scheme.onPrimaryContainer : scheme.onSurface;

    return Container(
      constraints: const BoxConstraints(minHeight: 104),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: metric.emphasized
            ? scheme.primaryContainer
            : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: metric.emphasized
              ? scheme.primaryContainer
              : scheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                metric.icon,
                size: 19,
                color: metric.emphasized
                    ? scheme.onPrimaryContainer
                    : scheme.primary,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  metric.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            metric.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
