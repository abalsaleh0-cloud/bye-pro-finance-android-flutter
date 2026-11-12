import 'assistant_engine.dart';
import 'action_registry.dart';

/// Holds a write command until the user explicitly approves it.
final class AssistantConfirmation {
  AssistantCommand? _pending;

  AssistantCommand? get pending => _pending;
  bool get hasPending => _pending != null;

  void request(AssistantCommand command) {
    _pending = command;
  }

  void cancel() {
    _pending = null;
  }

  Future<ActionExecution?> approve(
    Future<ActionExecution> Function(AssistantCommand command) execute,
  ) async {
    final command = _pending;
    if (command == null) return null;
    final result = await execute(command);
    _pending = null;
    return result;
  }
}
