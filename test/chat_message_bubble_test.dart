import 'package:expense_app/core/theme/app_design_tokens.dart';
import 'package:expense_app/core/theme/app_theme.dart';
import 'package:expense_app/core/widgets/chat_message_bubble.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('outgoing chat bubble is right-tail shaped in dark mode', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(
          body: Align(
            alignment: Alignment.centerRight,
            child: ChatMessageBubble(
              key: Key('outgoing-chat-bubble'),
              text: 'رسالة تجريبية',
              isOutgoing: true,
            ),
          ),
        ),
      ),
    );

    final bubble = tester.widget<Container>(
      find.byKey(const Key('outgoing-chat-bubble')),
    );
    final decoration = bubble.decoration! as BoxDecoration;
    final radius = AppDesignTokens.standard().cardRadius;

    expect(decoration.color, AppTheme.dark.colorScheme.primary);
    expect(
      decoration.borderRadius,
      BorderRadius.only(
        topLeft: Radius.circular(radius),
        topRight: Radius.circular(radius),
        bottomLeft: Radius.circular(radius),
        bottomRight: const Radius.circular(6),
      ),
    );
    expect(bubble.padding, const EdgeInsets.symmetric(horizontal: 16, vertical: 10));
    expect(find.text('رسالة تجريبية'), findsOneWidget);
  });

  testWidgets('incoming chat bubble is left-tail shaped in light mode', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: Align(
            alignment: Alignment.centerLeft,
            child: ChatMessageBubble(
              key: Key('incoming-chat-bubble'),
              text: 'رد تجريبي',
              isOutgoing: false,
            ),
          ),
        ),
      ),
    );

    final bubble = tester.widget<Container>(
      find.byKey(const Key('incoming-chat-bubble')),
    );
    final decoration = bubble.decoration! as BoxDecoration;
    final radius = AppDesignTokens.standard().cardRadius;

    expect(decoration.color, AppTheme.light.colorScheme.surfaceContainerHigh);
    expect(
      decoration.borderRadius,
      BorderRadius.only(
        topLeft: Radius.circular(radius),
        topRight: Radius.circular(radius),
        bottomLeft: const Radius.circular(6),
        bottomRight: Radius.circular(radius),
      ),
    );
    expect(find.text('رد تجريبي'), findsOneWidget);
  });
}
