import 'package:expense_app/core/theme/app_design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Horizontally scrollable section tabs with a consistent rounded-pill surface.
class SectionPillTabs extends StatelessWidget {
  const SectionPillTabs({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.keyPrefix = 'section-pill-tab',
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = AppDesignTokens.of(context);

    return SizedBox(
      height: tokens.sectionTabHeight,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
        child: Row(
          children: [
            for (var index = 0; index < labels.length; index++) ...[
              if (index > 0) const SizedBox(width: 8),
              AnimatedContainer(
                key: Key('$keyPrefix-pill-$index'),
                duration: tokens.motionDuration,
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  color: index == selectedIndex
                      ? scheme.primaryContainer
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(tokens.controlRadius),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: Key('$keyPrefix-$index'),
                    borderRadius:
                        BorderRadius.circular(tokens.controlRadius),
                    onTap: () => onSelected(index),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: 72,
                        minHeight: tokens.touchTargetSize,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Center(
                          child: Text(
                            labels[index],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: index == selectedIndex
                                  ? scheme.onPrimaryContainer
                                  : scheme.onSurfaceVariant,
                              fontWeight: index == selectedIndex
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
