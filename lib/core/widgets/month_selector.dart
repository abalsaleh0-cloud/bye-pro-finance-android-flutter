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

    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 6, 10, 6),
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
            SizedBox(
              width: 148,
              child: DropdownButtonFormField<MonthKey>(
                key: pickerKey,
                initialValue: selectedMonth,
                isExpanded: true,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                borderRadius: BorderRadius.circular(tokens.controlRadius),
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
            if (trailing != null) ...[
              const SizedBox(width: 4),
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
