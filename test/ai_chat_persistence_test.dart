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
    addTearDown(restoredContainer.dispose);

    final restored = restoredContainer.read(aiChatMessagesProvider);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final messages = restoredContainer.read(aiChatMessagesProvider);
    expect(messages, hasLength(2));
    expect(messages.first.text, 'رسالة المستخدم');
    expect(messages.first.fromUser, isTrue);
    expect(messages.last.text, 'رد المساعد');
    expect(messages.last.fromUser, isFalse);
    expect(restored, isEmpty);
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
    expect(
      () => container.read(aiChatMessagesProvider),
      returnsNormally,
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(container.read(aiChatMessagesProvider), isEmpty);
  });
}
