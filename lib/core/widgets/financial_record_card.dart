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
    final visibleDetails = details.where((detail) => detail.trim().isNotEmpty);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    color: scheme.onSecondaryContainer,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (visibleDetails.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          visibleDetails.join(' • '),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(width: 8),
                  badge!,
                ],
              ],
            ),
            const SizedBox(height: 14),
            if (amountLabel != null) ...[
              Text(
                amountLabel!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
            ],
            Text(
              amount,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: actions,
                ),
              ),
            ],
            if (footer != null) ...[
              const Divider(height: 20),
              footer!,
            ],
          ],
        ),
      ),
    );
  }
}
