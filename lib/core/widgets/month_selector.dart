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
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 10, 10),
        child: Row(
          children: [
            Icon(
              Icons.calendar_month_outlined,
              color: theme.colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                strings.selectedMonth,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              key: const Key('month-selector-date-control'),
              width: selectorWidth,
              height: 48,
              padding: const EdgeInsetsDirectional.only(start: 8, end: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(tokens.controlRadius),
                border: Border.all(color: theme.colorScheme.outlineVariant),
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
    return Column(
      children: [
        for (var index = 0; index < metrics.length; index++) ...[
          if (index > 0) const SizedBox(height: 10),
          _SummaryMetricTile(metric: metrics[index]),
        ],
      ],
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
    final tokens = AppDesignTokens.of(context);
    final foreground =
        metric.emphasized ? scheme.onPrimaryContainer : scheme.onSurface;

    return Container(
      constraints: const BoxConstraints(minHeight: 96),
      padding: EdgeInsets.all(tokens.cardPadding),
      decoration: BoxDecoration(
        color: metric.emphasized
            ? scheme.primaryContainer
            : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(tokens.cardRadius),
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
