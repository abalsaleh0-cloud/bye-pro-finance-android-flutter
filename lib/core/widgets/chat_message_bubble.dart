import 'package:expense_app/core/theme/app_design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Rounded chat bubble used by the assistant conversation.
class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.text,
    required this.isOutgoing,
  });

  final String text;
  final bool isOutgoing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius = AppDesignTokens.of(context).cardRadius;

    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isOutgoing ? scheme.tertiaryContainer : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(radius),
          topRight: Radius.circular(radius),
          bottomLeft: Radius.circular(isOutgoing ? radius : 6),
          bottomRight: Radius.circular(isOutgoing ? 6 : radius),
        ),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: isOutgoing ? scheme.onTertiaryContainer : scheme.onSurface,
          fontSize: 16,
          height: 1.35,
        ),
      ),
    );
  }
}
