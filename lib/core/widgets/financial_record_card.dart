import 'package:expense_app/core/theme/app_design_tokens.dart';
import 'package:material_ui/material_ui.dart';

class FinancialRecordCard extends StatelessWidget {
  const FinancialRecordCard({
    super.key,
    required this.icon,
    required this.title,
    required this.amount,
    required this.details,
    this.amountLabel,
    this.badge,
    this.actions = const [],
    this.footer,
  });

  final IconData icon;
  final String title;
  final String amount;
  final List<String> details;
  final String? amountLabel;
  final Widget? badge;
  final List<Widget> actions;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = AppDesignTokens.of(context);
    final visibleDetails =
        details.where((detail) => detail.trim().isNotEmpty);

    return Card(
      color: scheme.surfaceContainerHigh.withValues(alpha: .28),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: tokens.recordIconBoxSize,
                  height: tokens.recordIconBoxSize,
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(tokens.controlRadius),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    color: scheme.onSecondaryContainer,
                    size: tokens.standardIconSize,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (visibleDetails.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          visibleDetails.join(' • '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (amountLabel != null)
                      Text(
                        amountLabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    Text(
                      amount,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                if (badge != null) ...[
                  const SizedBox(width: 8),
                  badge!,
                ],
              ],
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 4),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: actions,
                ),
              ),
            ],
            if (footer != null) ...[
              const Divider(height: 16),
              footer!,
            ],
          ],
        ),
      ),
    );
  }
}
