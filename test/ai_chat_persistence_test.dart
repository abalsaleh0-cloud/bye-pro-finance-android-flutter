import 'package:drift/native.dart';
import 'package:expense_app/core/database/app_database.dart';
import 'package:expense_app/core/database/database_providers.dart';
import 'package:expense_app/features/ai/presentation/ai_chat_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late ProviderContainer container;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  test('persists messages and restores them in a new provider container', () async {
    final controller = container.read(aiChatMessagesProvider.notifier);
    controller.add(const AiChatMessage('رسالة المستخدم', fromUser: true));
    controller.add(const AiChatMessage('رد المساعد'));
    await controller.flush();

    final restoredContainer = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    try {
      final restoredController =
          restoredContainer.read(aiChatMessagesProvider.notifier);
      await restoredController.flush();

      final messages = restoredContainer.read(aiChatMessagesProvider);
      expect(messages, hasLength(2));
      expect(messages.first.text, 'رسالة المستخدم');
      expect(messages.first.fromUser, isTrue);
      expect(messages.last.text, 'رد المساعد');
      expect(messages.last.fromUser, isFalse);
    } finally {
      restoredContainer.dispose();
    }
  });

  test('restores whether an assistant message may be used as dialogue context', () async {
    final controller = container.read(aiChatMessagesProvider.notifier);
    controller.add(const AiChatMessage('ما الشهر المقصود؟', includeInModelContext: true));
    controller.add(const AiChatMessage('نتيجة مالية من قاعدة البيانات: 2500'));
    await controller.flush();

    final restoredContainer = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    try {
      final restoredController = restoredContainer.read(aiChatMessagesProvider.notifier);
      await restoredController.flush();
      final messages = restoredContainer.read(aiChatMessagesProvider);
      expect(messages.first.includeInModelContext, isTrue);
      expect(messages.last.includeInModelContext, isFalse);
    } finally {
      restoredContainer.dispose();
    }
  });

  test('builds context from dialogue and excludes tool results', () {
    final messages = [
      const AiChatMessage('أضف راتب 1500', fromUser: true),
      const AiChatMessage('أي شهر تقصد؟', includeInModelContext: true),
      const AiChatMessage('النتيجة المالية: 2500'),
      const AiChatMessage('لهذا الشهر', fromUser: true),
    ];

    final context = buildAiConversationContext(messages);
    expect(context, contains('أضف راتب 1500'));
    expect(context, contains('أي شهر تقصد؟'));
    expect(context, contains('لهذا الشهر'));
    expect(context, isNot(contains('2500')));
  });

  test('limits context to the newest messages and character budget', () {
    final messages = List.generate(
      12,
      (index) => AiChatMessage('رسالة رقم $index', fromUser: true),
    );

    final context = buildAiConversationContext(
      messages,
      maxMessages: 3,
      maxCharacters: 80,
    );
    expect(context, contains('رسالة رقم 11'));
    expect(context, contains('رسالة رقم 10'));
    expect(context, isNot(contains('رسالة رقم 0')));
    expect(context.length, lessThanOrEqualTo(80));
  });

  test('clear persists an empty conversation', () async {
    final controller = container.read(aiChatMessagesProvider.notifier);
    controller.add(const AiChatMessage('رسالة'));
    await controller.flush();

    controller.clear();
    await controller.flush();

    expect(await database.readSetting('ai_chat_messages_v1'), '[]');
  });

  test('ignores malformed persisted data without throwing', () async {
    await database.writeSetting('ai_chat_messages_v1', '{broken json');
    final controller = container.read(aiChatMessagesProvider.notifier);
    await controller.flush();
    expect(container.read(aiChatMessagesProvider), isEmpty);
  });
}
