import 'package:flutter_riverpod/flutter_riverpod.dart';

final class AiChatMessage {
  const AiChatMessage(this.text, {this.fromUser = false});

  final String text;
  final bool fromUser;
}

class AiChatController extends Notifier<List<AiChatMessage>> {
  @override
  List<AiChatMessage> build() => const [];

  void add(AiChatMessage message) {
    state = [...state, message];
  }

  void clear() {
    state = const [];
  }
}

final aiChatMessagesProvider =
    NotifierProvider<AiChatController, List<AiChatMessage>>(
  AiChatController.new,
);
