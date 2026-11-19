import 'dart:convert';

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

  test('persists messages and restores the active chat in a new container',
      () async {
    final controller = container.read(aiChatWorkspaceProvider.notifier);
    controller.add(const AiChatMessage('رسالة المستخدم', fromUser: true));
    controller.add(
      const AiChatMessage(
        'رد Gemma',
        includeInModelContext: true,
        assistantSource: 'gemma',
      ),
    );
    await controller.flush();

    final restoredContainer = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    try {
      final restoredController =
          restoredContainer.read(aiChatWorkspaceProvider.notifier);
      await restoredController.flush();

      final workspace = restoredContainer.read(aiChatWorkspaceProvider);
      expect(workspace.conversations, hasLength(1));
      expect(workspace.messages, hasLength(2));
      expect(workspace.messages.first.text, 'رسالة المستخدم');
      expect(workspace.messages.first.fromUser, isTrue);
      expect(workspace.messages.last.text, 'رد Gemma');
      expect(workspace.messages.last.fromUser, isFalse);
      expect(workspace.messages.last.assistantSource, 'gemma');
      expect(workspace.activeConversation?.title, 'رسالة المستخدم');
      expect(workspace.messages.last.includeInModelContext, isTrue);
    } finally {
      restoredContainer.dispose();
    }
  });

  test('persists the local-after-Gemma fallback source label', () async {
    final controller = container.read(aiChatWorkspaceProvider.notifier);
    controller.add(
      const AiChatMessage(
        'لم أفهم. لم يتم تسجيل شيء.',
        assistantSource: 'localAfterGemma',
      ),
    );
    await controller.flush();

    final restoredContainer = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    try {
      final restoredController =
          restoredContainer.read(aiChatWorkspaceProvider.notifier);
      await restoredController.flush();
      expect(
        restoredContainer
            .read(aiChatWorkspaceProvider)
            .messages
            .single
            .assistantSource,
        'localAfterGemma',
      );
    } finally {
      restoredContainer.dispose();
    }
  });

  test('keeps separate conversations and restores the selected one', () async {
    final controller = container.read(aiChatWorkspaceProvider.notifier);
    controller.add(const AiChatMessage('محادثة أولى', fromUser: true));
    final firstId = container
        .read(aiChatWorkspaceProvider)
        .activeConversationId!;

    controller.newConversation();
    controller.add(const AiChatMessage('محادثة ثانية', fromUser: true));
    final secondId = container
        .read(aiChatWorkspaceProvider)
        .activeConversationId!;

    expect(secondId, isNot(firstId));
    expect(container.read(aiChatWorkspaceProvider).conversations, hasLength(2));

    controller.selectConversation(firstId);
    await controller.flush();

    final restoredContainer = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    try {
      final restoredController =
          restoredContainer.read(aiChatWorkspaceProvider.notifier);
      await restoredController.flush();
      final workspace = restoredContainer.read(aiChatWorkspaceProvider);
      expect(workspace.activeConversationId, firstId);
      expect(workspace.messages.single.text, 'محادثة أولى');
      expect(workspace.conversations.map((item) => item.id),
          contains(secondId));
    } finally {
      restoredContainer.dispose();
    }
  });

  test('deleting a chat removes only that conversation', () async {
    final controller = container.read(aiChatWorkspaceProvider.notifier);
    controller.add(const AiChatMessage('احتفظ بهذه المحادثة', fromUser: true));
    final keptId = container
        .read(aiChatWorkspaceProvider)
        .activeConversationId!;

    controller.newConversation();
    controller.add(const AiChatMessage('هذه ستحذف', fromUser: true));
    final deletedId = container
        .read(aiChatWorkspaceProvider)
        .activeConversationId!;

    controller.deleteConversation(deletedId);
    await controller.flush();

    final workspace = container.read(aiChatWorkspaceProvider);
    expect(workspace.conversations, hasLength(1));
    expect(workspace.conversations.single.id, keptId);
    expect(workspace.activeConversationId, keptId);
    expect(workspace.messages.single.text, 'احتفظ بهذه المحادثة');

    final restoredContainer = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    try {
      final restoredController =
          restoredContainer.read(aiChatWorkspaceProvider.notifier);
      await restoredController.flush();
      final restored = restoredContainer.read(aiChatWorkspaceProvider);
      expect(restored.conversations, hasLength(1));
      expect(restored.conversations.single.id, keptId);
      expect(restored.conversations.any((item) => item.id == deletedId), isFalse);
    } finally {
      restoredContainer.dispose();
    }
  });

  test('migrates the previous single-chat storage without losing messages',
      () async {
    await database.writeSetting(
      'ai_chat_messages_v1',
      jsonEncode([
        const AiChatMessage('سؤال سابق', fromUser: true).toJson(),
        const AiChatMessage(
          'رد سابق',
          includeInModelContext: true,
        ).toJson(),
      ]),
    );

    final controller = container.read(aiChatWorkspaceProvider.notifier);
    await controller.flush();

    final workspace = container.read(aiChatWorkspaceProvider);
    expect(workspace.conversations, hasLength(1));
    expect(workspace.messages, hasLength(2));
    expect(workspace.messages.first.text, 'سؤال سابق');
    expect(workspace.activeConversation?.title, 'سؤال سابق');
    expect(await database.readSetting('ai_chat_conversations_v2'), isNotNull);
    expect(await database.readSetting('ai_chat_messages_v1'), '[]');
  });

  test('restores whether assistant dialogue can be used as model context',
      () async {
    final controller = container.read(aiChatWorkspaceProvider.notifier);
    controller.add(const AiChatMessage('ما الشهر المقصود؟',
        includeInModelContext: true));
    controller.add(const AiChatMessage('نتيجة مالية من قاعدة البيانات: 2500'));
    await controller.flush();

    final restoredContainer = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    try {
      final restoredController =
          restoredContainer.read(aiChatWorkspaceProvider.notifier);
      await restoredController.flush();
      final messages =
          restoredContainer.read(aiChatWorkspaceProvider).messages;
      expect(messages.first.includeInModelContext, isTrue);
      expect(messages.last.includeInModelContext, isFalse);
    } finally {
      restoredContainer.dispose();
    }
  });

  test('builds context from recent dialogue and excludes tool results', () {
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
      20,
      (index) => AiChatMessage('رسالة رقم $index', fromUser: true),
    );

    final context = buildAiConversationContext(
      messages,
      maxMessages: 4,
      maxCharacters: 90,
    );
    expect(context, contains('رسالة رقم 19'));
    expect(context, contains('رسالة رقم 18'));
    expect(context, isNot(contains('رسالة رقم 0')));
    expect(context.length, lessThanOrEqualTo(90));
  });

  test('clearing active dialogue persists an empty active conversation',
      () async {
    final controller = container.read(aiChatWorkspaceProvider.notifier);
    controller.add(const AiChatMessage('رسالة'));
    await controller.flush();

    controller.clearActiveConversation();
    await controller.flush();

    final workspace = container.read(aiChatWorkspaceProvider);
    expect(workspace.messages, isEmpty);
    final raw = await database.readSetting('ai_chat_conversations_v2');
    expect(raw, isNotNull);
    expect(raw, contains('"messages":[]'));
  });

  test('ignores malformed persisted data without throwing', () async {
    await database.writeSetting('ai_chat_conversations_v2', '{broken json');
    await database.writeSetting('ai_chat_messages_v1', '{broken json');
    final controller = container.read(aiChatWorkspaceProvider.notifier);
    await controller.flush();
    expect(container.read(aiChatWorkspaceProvider).messages, isEmpty);
  });

  test('limits the number of saved conversations', () async {
    final controller = container.read(aiChatWorkspaceProvider.notifier);
    for (var index = 0; index < 35; index++) {
      controller.newConversation();
      controller.add(AiChatMessage('محادثة $index', fromUser: true));
    }
    await controller.flush();
    expect(container.read(aiChatWorkspaceProvider).conversations.length, 30);
  });
}
