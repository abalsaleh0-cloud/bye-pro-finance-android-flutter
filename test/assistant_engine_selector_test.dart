import 'package:expense_app/features/ai/domain/assistant_engine.dart';
import 'package:expense_app/features/ai/domain/assistant_engine_selector.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubEngine implements AssistantEngine {
  _StubEngine(this.result);

  final AssistantResult result;
  var calls = 0;

  @override
  Future<AssistantResult> interpret(
    String input,
    List<String> availableActions, {
    AssistantMedia? media,
    String conversationContext = '',
    Map<String, String> expenseCategories = const {},
  }) async {
    calls++;
    return result;
  }
}

void main() {
  test('keeps the local engine active when Gemma is disabled', () {
    const local = FakeAssistantEngine();
    final gemma = _StubEngine(const AssistantResult.notUnderstood());

    final selected = selectAssistantEngine(
      gemmaEnabled: false,
      gemmaReady: true,
      gemmaEngine: gemma,
      localEngine: local,
    );

    expect(identical(selected, local), isTrue);
    expect(gemma.calls, 0);
  });

  test('keeps the local engine active until the model is ready', () {
    const local = FakeAssistantEngine();
    final gemma = _StubEngine(const AssistantResult.notUnderstood());

    final selected = selectAssistantEngine(
      gemmaEnabled: true,
      gemmaReady: false,
      gemmaEngine: gemma,
      localEngine: local,
    );

    expect(identical(selected, local), isTrue);
    expect(gemma.calls, 0);
  });

  test('uses Gemma first and falls back to local parsing for text commands', () async {
    final gemma = _StubEngine(const AssistantResult.notUnderstood());
    const local = FakeAssistantEngine();
    final selected = selectAssistantEngine(
      gemmaEnabled: true,
      gemmaReady: true,
      gemmaEngine: gemma,
      localEngine: local,
    );

    final result = await selected.interpret(
      'ضيف مرتب ١٥٠٠ هالشهر',
      const ['save_work_entry'],
    );

    expect(gemma.calls, 1);
    expect(result.kind, AssistantResultKind.command);
    expect(result.command!.name, 'save_work_entry');
    expect(result.command!.parameters['amountMinorUnits'], 1500);
    expect(result.source, AssistantResultSource.local);
    expect(result.usedGemmaFallback, isTrue);
  });

  test('keeps a valid Gemma clarification instead of silently guessing locally', () async {
    final gemma = _StubEngine(
      const AssistantResult.clarification('ما تاريخ العملية؟'),
    );
    const local = FakeAssistantEngine();
    final selected = selectAssistantEngine(
      gemmaEnabled: true,
      gemmaReady: true,
      gemmaEngine: gemma,
      localEngine: local,
    );

    final result = await selected.interpret(
      'أضف مصروفاً',
      const ['save_home_expense'],
    );

    expect(result.kind, AssistantResultKind.clarification);
    expect(result.message, 'ما تاريخ العملية؟');
    expect(result.source, AssistantResultSource.gemma);
    expect(result.usedGemmaFallback, isFalse);
  });
}
