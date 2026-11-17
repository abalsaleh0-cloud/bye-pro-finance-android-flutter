import 'package:expense_app/core/theme/app_design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Flat, horizontally scrollable section tabs with a subtle active underline.
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
              if (index > 0) const SizedBox(width: 20),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  key: Key('$keyPrefix-$index'),
                  borderRadius: BorderRadius.circular(tokens.controlRadius),
                  onTap: () => onSelected(index),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: 72,
                      minHeight: tokens.touchTargetSize,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            labels[index],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: index == selectedIndex
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant,
                              fontWeight: index == selectedIndex
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 5),
                          AnimatedContainer(
                            duration: tokens.motionDuration,
                            curve: Curves.easeOut,
                            width: index == selectedIndex ? 28 : 0,
                            height: 2,
                            decoration: BoxDecoration(
                              color: index == selectedIndex
                                  ? scheme.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
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
