import 'dart:async';
import 'dart:convert';

import 'package:expense_app/core/database/database_providers.dart';
import 'package:expense_app/core/database/app_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final class AiChatMessage {
  const AiChatMessage(
    this.text, {
    this.fromUser = false,
    bool? includeInModelContext,
  }) : includeInModelContext = includeInModelContext ?? fromUser;

  final String text;
  final bool fromUser;
  final bool includeInModelContext;

  Map<String, Object?> toJson() => {
        'text': text,
        'fromUser': fromUser,
        'includeInModelContext': includeInModelContext,
      };

  static AiChatMessage? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final text = value['text'];
    final fromUser = value['fromUser'];
    if (text is! String || fromUser is! bool) return null;
    final includeInModelContext = value['includeInModelContext'];
    return AiChatMessage(
      text,
      fromUser: fromUser,
      // Old chat entries only treat user messages as contextual dialogue.
      includeInModelContext: includeInModelContext is bool
          ? includeInModelContext
          : fromUser,
    );
  }
}

final class AiChatConversation {
  const AiChatConversation({
    required this.id,
    required this.title,
    required this.updatedAt,
    required this.messages,
  });

  final String id;
  final String title;
  final DateTime updatedAt;
  final List<AiChatMessage> messages;

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'updatedAt': updatedAt.toIso8601String(),
        'messages': messages.map((message) => message.toJson()).toList(),
      };

  static AiChatConversation? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final id = value['id'];
    final title = value['title'];
    final updatedAt = value['updatedAt'];
    final rawMessages = value['messages'];
    if (id is! String ||
        id.isEmpty ||
        title is! String ||
        updatedAt is! String ||
        rawMessages is! List) {
      return null;
    }
    final date = DateTime.tryParse(updatedAt);
    if (date == null) return null;
    final messages = rawMessages
        .map(AiChatMessage.fromJson)
        .whereType<AiChatMessage>()
        .toList(growable: false);
    return AiChatConversation(
      id: id,
      title: title,
      updatedAt: date,
      messages: messages,
    );
  }
}

final class AiChatWorkspaceState {
  const AiChatWorkspaceState({
    this.conversations = const [],
    this.activeConversationId,
  });

  final List<AiChatConversation> conversations;
  final String? activeConversationId;

  AiChatConversation? get activeConversation {
    final id = activeConversationId;
    if (id == null) return null;
    for (final conversation in conversations) {
      if (conversation.id == id) return conversation;
    }
    return null;
  }

  List<AiChatMessage> get messages =>
      activeConversation?.messages ?? const [];
}

/// Builds a bounded transcript from dialogue turns deliberately marked safe.
/// Database/tool results and UI status messages remain excluded by default.
String buildAiConversationContext(
  List<AiChatMessage> messages, {
  int maxMessages = 12,
  int maxCharacters = 2400,
}) {
  if (maxMessages <= 0 || maxCharacters <= 0) return '';

  final eligible = messages
      .where((message) => message.includeInModelContext)
      .toList(growable: false);
  final start = eligible.length > maxMessages
      ? eligible.length - maxMessages
      : 0;
  final recent = eligible.sublist(start);
  final lines = <String>[];
  var remaining = maxCharacters;

  for (final message in recent.reversed) {
    final value = message.text.trim();
    if (value.isEmpty) continue;

    final prefix = message.fromUser ? 'المستخدم: ' : 'المساعد: ';
    final available = remaining - prefix.length;
    if (available <= 0) break;

    final excerpt = value.length > available
        ? '…${value.substring(value.length - available + 1)}'
        : value;
    final line = '$prefix$excerpt';
    lines.add(line);
    remaining -= line.length + 1;
    if (remaining <= 0) break;
  }

  return lines.reversed.join('\n');
}

class AiChatController extends Notifier<AiChatWorkspaceState> {
  static const _storageKey = 'ai_chat_conversations_v2';
  static const _legacyStorageKey = 'ai_chat_messages_v1';
  static const _maxMessagesPerConversation = 500;
  static const _maxConversations = 30;
  static int _idSequence = 0;

  AppDatabase? _database;
  bool _restored = false;
  int _revision = 0;
  Future<void> _writeQueue = Future<void>.value();
  Future<void>? _restoreFuture;

  @override
  AiChatWorkspaceState build() {
    final database = ref.watch(appDatabaseProvider);
    _database = database;
    _restoreFuture = _restore(database);
    unawaited(_restoreFuture);
    return const AiChatWorkspaceState();
  }

  String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_idSequence++}';

  String _titleFromMessage(String text) {
    final firstLine = text
        .split('\n')
        .first
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (firstLine.isEmpty) return '';
    const maxTitleLength = 42;
    return firstLine.length <= maxTitleLength
        ? firstLine
        : '${firstLine.substring(0, maxTitleLength - 1)}…';
  }

  AiChatConversation _newConversation({String title = ''}) =>
      AiChatConversation(
        id: _newId(),
        title: title,
        updatedAt: DateTime.now(),
        messages: const [],
      );

  List<AiChatConversation> _sortAndLimit(
    List<AiChatConversation> conversations, {
    String? keepId,
  }) {
    conversations.sort(
      (left, right) => right.updatedAt.compareTo(left.updatedAt),
    );
    if (conversations.length <= _maxConversations) {
      return List.unmodifiable(conversations);
    }
    final kept = conversations.take(_maxConversations).toList();
    if (keepId != null && !kept.any((item) => item.id == keepId)) {
      final pinned = conversations.firstWhere((item) => item.id == keepId);
      kept[kept.length - 1] = pinned;
      kept.sort(
        (left, right) => right.updatedAt.compareTo(left.updatedAt),
      );
    }
    return List.unmodifiable(kept);
  }

  Future<void> _restore(AppDatabase database) async {
    final startingRevision = _revision;
    try {
      var restored = false;
      final raw = await database.readSetting(_storageKey);
      if (raw != null) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic> &&
              decoded['conversations'] is List) {
            final conversations = (decoded['conversations'] as List)
                .map(AiChatConversation.fromJson)
                .whereType<AiChatConversation>()
                .toList();
            final requestedActiveId = decoded['activeConversationId'];
            final ordered = _sortAndLimit(conversations);
            final activeId = requestedActiveId is String &&
                    ordered.any((item) => item.id == requestedActiveId)
                ? requestedActiveId
                : ordered.firstOrNull?.id;
            if (_revision == startingRevision) {
              state = AiChatWorkspaceState(
                conversations: ordered,
                activeConversationId: activeId,
              );
              restored = true;
            }
          }
        } catch (_) {
          // Fall back to the previous single-conversation format below.
        }
      }

      if (!restored && _revision == startingRevision) {
        final legacyRaw = await database.readSetting(_legacyStorageKey);
        if (legacyRaw != null && _revision == startingRevision) {
          try {
            final decoded = jsonDecode(legacyRaw);
            if (decoded is List) {
              final messages = decoded
                  .map(AiChatMessage.fromJson)
                  .whereType<AiChatMessage>()
                  .toList(growable: false);
              if (messages.isNotEmpty) {
                final firstUserMessage = messages
                    .where((message) => message.fromUser)
                    .firstOrNull;
                final migrated = AiChatConversation(
                  id: _newId(),
                  title: firstUserMessage == null
                      ? ''
                      : _titleFromMessage(firstUserMessage.text),
                  updatedAt: DateTime.now(),
                  messages: messages.length <= _maxMessagesPerConversation
                      ? messages
                      : messages.sublist(
                          messages.length - _maxMessagesPerConversation,
                        ),
                );
                state = AiChatWorkspaceState(
                  conversations: [migrated],
                  activeConversationId: migrated.id,
                );
              }
            }
          } catch (_) {
            // A damaged legacy chat cache must never prevent the app opening.
          }
        }
      }
    } catch (_) {
      // A damaged or unavailable chat cache must never prevent the app opening.
    } finally {
      _restored = true;
      _queuePersist(database);
    }
  }

  void add(AiChatMessage message) {
    _revision++;
    final now = DateTime.now();
    final current = state.activeConversation;
    final conversation = current ?? _newConversation();
    final updatedMessages = [...conversation.messages, message];
    final firstUserMessage = updatedMessages
        .where((item) => item.fromUser)
        .firstOrNull;
    final title = conversation.title.isNotEmpty
        ? conversation.title
        : firstUserMessage == null
            ? ''
            : _titleFromMessage(firstUserMessage.text);
    final updated = AiChatConversation(
      id: conversation.id,
      title: title,
      updatedAt: now,
      messages: updatedMessages.length <= _maxMessagesPerConversation
          ? List.unmodifiable(updatedMessages)
          : List.unmodifiable(
              updatedMessages.sublist(
                updatedMessages.length - _maxMessagesPerConversation,
              ),
            ),
    );
    final conversations = state.conversations
        .where((item) => item.id != conversation.id)
        .toList()
      ..add(updated);
    state = AiChatWorkspaceState(
      conversations: _sortAndLimit(conversations, keepId: updated.id),
      activeConversationId: updated.id,
    );
    _persistIfRestored();
  }

  /// Starts a fresh thread without removing any saved conversation.
  void newConversation() {
    final active = state.activeConversation;
    if (active != null && active.messages.isEmpty) return;
    _revision++;
    final conversation = _newConversation();
    final conversations = [...state.conversations, conversation];
    state = AiChatWorkspaceState(
      conversations: _sortAndLimit(conversations, keepId: conversation.id),
      activeConversationId: conversation.id,
    );
    _persistIfRestored();
  }

  void selectConversation(String id) {
    if (!state.conversations.any((item) => item.id == id) ||
        state.activeConversationId == id) {
      return;
    }
    _revision++;
    state = AiChatWorkspaceState(
      conversations: state.conversations,
      activeConversationId: id,
    );
    _persistIfRestored();
  }

  /// Removes only the selected conversation and its dialogue, never finance data.
  void deleteConversation(String id) {
    if (!state.conversations.any((item) => item.id == id)) return;
    _revision++;
    final remaining =
        state.conversations.where((item) => item.id != id).toList();
    final activeId = state.activeConversationId == id
        ? remaining.firstOrNull?.id
        : state.activeConversationId;
    state = AiChatWorkspaceState(
      conversations: List.unmodifiable(remaining),
      activeConversationId: activeId,
    );
    _persistIfRestored();
  }

  void clearActiveConversation() {
    final active = state.activeConversation;
    if (active == null || active.messages.isEmpty) return;
    _revision++;
    final cleared = AiChatConversation(
      id: active.id,
      title: '',
      updatedAt: DateTime.now(),
      messages: const [],
    );
    final conversations = state.conversations
        .where((item) => item.id != active.id)
        .toList()
      ..add(cleared);
    state = AiChatWorkspaceState(
      conversations: _sortAndLimit(conversations, keepId: cleared.id),
      activeConversationId: cleared.id,
    );
    _persistIfRestored();
  }

  void _persistIfRestored() {
    if (_restored && _database != null) _queuePersist(_database!);
  }

  void _queuePersist(AppDatabase database) {
    final snapshot = {
      'activeConversationId': state.activeConversationId,
      'conversations':
          state.conversations.map((conversation) => conversation.toJson()).toList(),
    };
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

final aiChatWorkspaceProvider =
    NotifierProvider<AiChatController, AiChatWorkspaceState>(
  AiChatController.new,
);
