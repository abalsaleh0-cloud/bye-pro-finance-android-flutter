import 'package:expense_app/core/theme/app_design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// One shared pill-tab control for every nested section in the app.
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
    final scheme = Theme.of(context).colorScheme;
    final tokens = AppDesignTokens.of(context);
    return SizedBox(
      height: tokens.sectionTabHeight,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        child: Row(
          children: [
            for (var index = 0; index < labels.length; index++) ...[
              if (index > 0) const SizedBox(width: 8),
              Material(
                color: index == selectedIndex
                    ? scheme.primaryContainer
                    : scheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(tokens.controlRadius),
                  side: BorderSide(
                    color: index == selectedIndex
                        ? scheme.primary
                        : scheme.outlineVariant,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: Key('$keyPrefix-$index'),
                  onTap: () => onSelected(index),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: 88,
                      minHeight: tokens.touchTargetSize,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Center(
                        child: Text(
                          labels[index],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
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
            ],
          ],
        ),
      ),
    );
  }
}
