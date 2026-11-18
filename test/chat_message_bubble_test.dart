import 'package:expense_app/core/theme/app_design_tokens.dart';
import 'package:expense_app/core/theme/app_theme.dart';
import 'package:expense_app/core/widgets/chat_message_bubble.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Finder _bubbleContainer(String key) => find.descendant(
      of: find.byKey(Key(key)),
      matching: find.byType(Container),
    );

void main() {
  testWidgets('outgoing chat bubble uses Telegram Dark Blue palette', (tester) async {
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

    final bubble = tester.widget<Container>(_bubbleContainer('outgoing-chat-bubble'));
    final decoration = bubble.decoration! as BoxDecoration;
    final radius = AppDesignTokens.standard().cardRadius;

    expect(decoration.color, const Color(0xFF3E618A));
    expect(decoration.color, AppTheme.dark.colorScheme.tertiaryContainer);
    expect(
      decoration.borderRadius,
      BorderRadius.only(
        topLeft: Radius.circular(radius),
        topRight: Radius.circular(radius),
        bottomLeft: Radius.circular(radius),
        bottomRight: const Radius.circular(6),
      ),
    );
    expect(
      tester.widget<Text>(find.text('رسالة تجريبية')).style!.color,
      Colors.white,
    );
  });

  testWidgets('incoming chat bubble uses Telegram Dark Blue surface', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(
          body: Align(
            alignment: Alignment.centerLeft,
            child: ChatMessageBubble(
              key: Key('incoming-dark-chat-bubble'),
              text: 'رد تجريبي',
              isOutgoing: false,
            ),
          ),
        ),
      ),
    );

    final bubble = tester.widget<Container>(
      _bubbleContainer('incoming-dark-chat-bubble'),
    );
    expect(
      (bubble.decoration! as BoxDecoration).color,
      const Color(0xFF232E3B),
    );
    expect(find.text('رد تجريبي'), findsOneWidget);
  });

  testWidgets('outgoing chat bubble uses Telegram Blue light palette', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: Align(
            alignment: Alignment.centerRight,
            child: ChatMessageBubble(
              key: Key('outgoing-light-chat-bubble'),
              text: 'رسالة فاتحة',
              isOutgoing: true,
            ),
          ),
        ),
      ),
    );

    final bubble = tester.widget<Container>(
      _bubbleContainer('outgoing-light-chat-bubble'),
    );
    expect(
      (bubble.decoration! as BoxDecoration).color,
      const Color(0xFFEFFFDE),
    );
    expect(find.text('رسالة فاتحة'), findsOneWidget);
  });
}