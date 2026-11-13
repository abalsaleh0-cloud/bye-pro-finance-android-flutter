import 'dart:async';
import 'dart:convert';

import 'package:expense_app/core/database/database_providers.dart';
import 'package:expense_app/core/database/app_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final class AiChatMessage {
  const AiChatMessage(this.text, {this.fromUser = false});

  final String text;
  final bool fromUser;

  Map<String, Object?> toJson() => {
        'text': text,
        'fromUser': fromUser,
      };

  static AiChatMessage? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final text = value['text'];
    final fromUser = value['fromUser'];
    if (text is! String || fromUser is! bool) return null;
    return AiChatMessage(text, fromUser: fromUser);
  }
}

class AiChatController extends Notifier<List<AiChatMessage>> {
  static const _storageKey = 'ai_chat_messages_v1';
  static const _maxMessages = 500;

  AppDatabase? _database;
  bool _restored = false;
  int _revision = 0;
  Future<void> _writeQueue = Future<void>.value();
  Future<void>? _restoreFuture;

  @override
  List<AiChatMessage> build() {
    final database = ref.watch(appDatabaseProvider);
    _database = database;
    _restoreFuture = _restore(database);
    unawaited(_restoreFuture);
    return const [];
  }

  Future<void> _restore(AppDatabase database) async {
    final startingRevision = _revision;
    try {
      final raw = await database.readSetting(_storageKey);
      if (_revision == startingRevision && raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final messages = decoded
              .map(AiChatMessage.fromJson)
              .whereType<AiChatMessage>()
              .toList(growable: false);
          state = messages.length <= _maxMessages
              ? messages
              : messages.sublist(messages.length - _maxMessages);
        }
      }
    } catch (_) {
      // A damaged or unavailable chat cache must never prevent the app opening.
    } finally {
      _restored = true;
      if (_revision != startingRevision) {
        _queuePersist(database);
      }
    }
  }

  void add(AiChatMessage message) {
    _revision++;
    final updated = [...state, message];
    state = updated.length <= _maxMessages
        ? updated
        : updated.sublist(updated.length - _maxMessages);
    if (_restored) _queuePersist(_database!);
  }

  void clear() {
    _revision++;
    state = const [];
    if (_restored) _queuePersist(_database!);
  }

  void _queuePersist(AppDatabase database) {
    final snapshot = state.map((message) => message.toJson()).toList();
    final encoded = jsonEncode(snapshot);
    _writeQueue = _writeQueue
        .then((_) => database.writeSetting(_storageKey, encoded))
        .catchError((Object _) {
          // Chat persistence is best-effort; a storage error must not break chat.
        });
  }

  /// Waits for pending writes; useful when coordinating app shutdown and tests.
  Future<void> flush() async {
    await _restoreFuture;
    await _writeQueue;
  }
}

final aiChatMessagesProvider =
    NotifierProvider<AiChatController, List<AiChatMessage>>(
  AiChatController.new,
);
