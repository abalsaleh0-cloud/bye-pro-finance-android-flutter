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
        padding: EdgeInsetsDirectional.fromSTEB(
          tokens.cardPadding - 2,
          tokens.pageVerticalPadding - 2,
          tokens.pageVerticalPadding - 2,
          tokens.pageVerticalPadding - 2,
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_month_outlined,
              color: theme.colorScheme.primary,
              size: tokens.standardIconSize,
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
              height: tokens.buttonHeight,
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
    final tokens = AppDesignTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(tokens.cardRadius),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .55)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < metrics.length; index++) ...[
            if (index > 0)
              Divider(
                height: 1,
                thickness: 1,
                indent: 68,
                endIndent: 16,
                color: scheme.outlineVariant.withValues(alpha: .45),
              ),
            _SummaryMetricTile(metric: metrics[index]),
          ],
        ],
      ),
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
    final foreground = scheme.onSurface;
    final iconBackground = metric.emphasized
        ? scheme.primaryContainer
        : scheme.surfaceContainerHighest;

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: tokens.metricTileMinHeight),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(
          tokens.cardPadding,
          12,
          tokens.cardPadding,
          12,
        ),
        child: Row(
          children: [
            Container(
              width: tokens.recordIconBoxSize,
              height: tokens.recordIconBoxSize,
              decoration: BoxDecoration(
                color: iconBackground,
                shape: BoxShape.circle,
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
                  color: foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                metric.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: metric.emphasized ? scheme.primary : foreground,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
