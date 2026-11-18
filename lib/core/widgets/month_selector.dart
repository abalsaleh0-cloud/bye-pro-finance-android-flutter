import 'package:expense_app/core/time/month_key.dart';
import 'package:expense_app/core/time/calendar_date.dart';
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
    final scheme = theme.colorScheme;
    final selectedDate = DateTime(selectedMonth.year, selectedMonth.month, 1);
    final monthTitle =
        toAsciiDigits(MaterialLocalizations.of(context).formatMonthYear(selectedDate));

    Future<void> chooseMonth() async {
      final picked = await showModalBottomSheet<MonthKey>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) {
          final sheetTheme = Theme.of(sheetContext);
          final maxHeight = MediaQuery.sizeOf(sheetContext).height * .62;
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(20, 18, 20, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            strings.selectedMonth,
                            style: sheetTheme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: strings.calendar,
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: availableMonths.length,
                      separatorBuilder: (context, index) => const Divider(
                        height: 1,
                        indent: 20,
                        endIndent: 20,
                      ),
                      itemBuilder: (context, index) {
                        final month = availableMonths[index];
                        final date = DateTime(month.year, month.month, 1);
                        final label =
                            toAsciiDigits(MaterialLocalizations.of(context).formatMonthYear(date));
                        final isSelected = month == selectedMonth;
                        return ListTile(
                          key: Key('month-option-$month'),
                          dense: true,
                          title: Text(label),
                          trailing: isSelected
                              ? Icon(Icons.check, color: scheme.primary)
                              : null,
                          onTap: () => Navigator.pop(sheetContext, month),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
      if (!context.mounted || picked == null) return;
      onChanged(picked);
    }

    Future<void> pickFromOfficialCalendar() async {
      final picked = await showDatePicker(
        context: context,
        initialDate: selectedDate,
        firstDate: DateTime(1900),
        lastDate: DateTime(2100),
      );
      if (!context.mounted || picked == null) return;
      onChanged(MonthKey(year: picked.year, month: picked.month));
    }

    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              key: pickerKey,
              onPressed: chooseMonth,
              style: TextButton.styleFrom(
                alignment: AlignmentDirectional.centerStart,
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 2, vertical: 6),
                minimumSize: const Size(0, 40),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      monthTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
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
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .30)),
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
            _SummaryMetricTile(
              key: Key('summary-metric-row-$index'),
              metric: metrics[index],
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryMetricTile extends StatelessWidget {
  const _SummaryMetricTile({super.key, required this.metric});

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
          6,
          tokens.cardPadding,
          6,
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
                style: theme.textTheme.titleMedium?.copyWith(
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
