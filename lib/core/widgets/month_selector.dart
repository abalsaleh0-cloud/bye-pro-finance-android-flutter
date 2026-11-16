import 'package:expense_app/core/time/month_key.dart';
import 'package:expense_app/core/theme/app_design_tokens.dart';
import 'package:expense_app/l10n/generated/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

class MonthSelector extends StatelessWidget {
  const MonthSelector({
    super.key,
    required this.pickerKey,
    required this.selectedMonth,
    required this.availableMonths,
    required this.onChanged,
    this.trailing,
  });

  final Key pickerKey;
  final MonthKey selectedMonth;
  final List<MonthKey> availableMonths;
  final ValueChanged<MonthKey> onChanged;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final tokens = AppDesignTokens.of(context);

    Future<void> pickFromOfficialCalendar() async {
      final picked = await showDatePicker(
        context: context,
        initialDate: DateTime(selectedMonth.year, selectedMonth.month, 1),
        firstDate: DateTime(1900),
        lastDate: DateTime(2100),
      );
      if (!context.mounted || picked == null) return;
      onChanged(MonthKey(year: picked.year, month: picked.month));
    }

    const selectorWidth = 148.0;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(tokens.controlRadius),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: SizedBox(
        height: tokens.buttonHeight,
        child: Row(
          children: [
            Icon(
              Icons.calendar_month_outlined,
              color: theme.colorScheme.primary,
              size: 19,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                strings.selectedMonth,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              key: const Key('month-selector-date-control'),
              width: selectorWidth,
              height: tokens.buttonHeight,
              padding: const EdgeInsetsDirectional.only(start: 8, end: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(tokens.controlRadius),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<MonthKey>(
                  key: pickerKey,
                  value: selectedMonth,
                  isExpanded: true,
                  menuWidth: selectorWidth,
                  menuMaxHeight: 320,
                  borderRadius: BorderRadius.circular(tokens.controlRadius),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  items: availableMonths
                      .map(
                        (month) => DropdownMenuItem(
                          value: month,
                          child: Text(
                            month.toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) onChanged(value);
                  },
                ),
              ),
            ),
            IconButton(
              key: const Key('month-selector-official-calendar'),
              tooltip: strings.calendar,
              visualDensity: VisualDensity.compact,
              onPressed: pickFromOfficialCalendar,
              icon: const Icon(Icons.edit_calendar_outlined),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 2),
              trailing!,
            ],
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
    final tokens = AppDesignTokens.of(context);
    return Column(
      children: [
        for (var index = 0; index < metrics.length; index++) ...[
          if (index > 0)
            Divider(
              height: 1,
              thickness: 1,
              indent: tokens.recordIconBoxSize + 24,
              endIndent: 12,
            ),
          _SummaryMetricTile(
            key: Key('summary-metric-row-$index'),
            metric: metrics[index],
          ),
        ],
      ],
    );
  }
}

class _SummaryMetricTile extends StatelessWidget {
  const _SummaryMetricTile({
    super.key,
    required this.metric,
  });

  final SummaryMetricData metric;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = AppDesignTokens.of(context);
    final foreground =
        metric.emphasized ? scheme.primary : scheme.onSurface;

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: tokens.metricTileMinHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: metric.emphasized
                ? scheme.primaryContainer.withValues(alpha: .20)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(tokens.controlRadius),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              children: [
                Container(
                  width: tokens.recordIconBoxSize,
                  height: tokens.recordIconBoxSize,
                  decoration: BoxDecoration(
                    color: metric.emphasized
                        ? scheme.primaryContainer
                        : scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(tokens.controlRadius),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    metric.icon,
                    size: tokens.standardIconSize,
                    color: metric.emphasized
                        ? scheme.onPrimaryContainer
                        : scheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    metric.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  metric.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
