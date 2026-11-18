import 'assistant_engine.dart';

/// Selects the model only when the user opted in and the model is verified
/// ready. The deterministic engine remains the fallback for text commands.
AssistantEngine selectAssistantEngine({
  required bool gemmaEnabled,
  required bool gemmaReady,
  required AssistantEngine gemmaEngine,
  required AssistantEngine localEngine,
}) {
  if (!gemmaEnabled || !gemmaReady) return localEngine;
  return FallbackAssistantEngine(
    primary: gemmaEngine,
    fallback: localEngine,
  );
}
