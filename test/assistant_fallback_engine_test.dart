import 'dart:typed_data';

import 'package:expense_app/features/ai/domain/assistant_engine.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubAssistantEngine implements AssistantEngine {
  _StubAssistantEngine(this.result);

  final AssistantResult result;
  var calls = 0;

  @override
  Future<AssistantResult> interpret(
    String input,
    List<String> availableActions, {
    AssistantMedia? media,
    String conversationContext = '',
  }) async {
    calls++;
    return result;
  }
}

void main() {
  const actions = [
    'save_work_entry',
    'read_work_remaining',
    'read_dashboard_summary',
  ];

  test('uses Arabic parser only when Gemma does not understand', () async {
    final primary = _StubAssistantEngine(
      const AssistantResult.notUnderstood(),
    );
    final fallback = const FakeAssistantEngine();
    final engine = FallbackAssistantEngine(
      primary: primary,
      fallback: fallback,
    );

    final result = await engine.interpret(
      'ضيف مرتب ١٥٠٠ هالشهر',
      actions,
    );

    expect(primary.calls, 1);
    expect(result.kind, AssistantResultKind.command);
    expect(result.command!.name, 'save_work_entry');
    expect(result.command!.parameters['amountMinorUnits'], 1500);
  });

  test('preserves a clarification returned by Gemma', () async {
    final primary = _StubAssistantEngine(
      const AssistantResult.clarification('ما المبلغ المطلوب؟'),
    );
    final fallback = _StubAssistantEngine(
      const AssistantResult.notUnderstood(),
    );
    final engine = FallbackAssistantEngine(
      primary: primary,
      fallback: fallback,
    );

    final result = await engine.interpret('سجل راتب', actions);

    expect(result.kind, AssistantResultKind.clarification);
    expect(result.message, 'ما المبلغ المطلوب؟');
    expect(fallback.calls, 0);
  });

  test('merges multi-turn clarification answers before falling back', () async {
    final primary = _StubAssistantEngine(
      const AssistantResult.notUnderstood(),
    );
    final engine = FallbackAssistantEngine(
      primary: primary,
      fallback: const FakeAssistantEngine(),
    );

    final result = await engine.interpret(
      'تشرين الثاني 2026',
      [
        'save_debt',
        'read_work_remaining',
      ],
      conversationContext: 'المستخدم: سجل دين 500\n'
          'المساعد: هل المبلغ لك عند شخص أم عليك لشخص؟\n'
          'المستخدم: لي عند أحمد\n'
          'المساعد: ما الشهر المستحق للدين؟',
    );

    expect(result.kind, AssistantResultKind.command);
    expect(result.command!.name, 'save_debt');
    expect(result.command!.parameters['amountMinorUnits'], 500);
    expect(result.command!.parameters['direction'], 'creditor');
    expect(result.command!.parameters['counterparty'], 'احمد');
    expect(result.command!.parameters['year'], 2026);
    expect(result.command!.parameters['month'], 11);
  });

  test('does not send media to the text-only fallback', () async {
    final primary = _StubAssistantEngine(
      const AssistantResult.notUnderstood(),
    );
    final fallback = _StubAssistantEngine(
      const AssistantResult.notUnderstood(),
    );
    final engine = FallbackAssistantEngine(
      primary: primary,
      fallback: fallback,
    );

    final result = await engine.interpret(
      'حلل الصورة',
      actions,
      media: AssistantMedia(imageBytes: Uint8List.fromList([1, 2, 3])),
    );

    expect(result.kind, AssistantResultKind.notUnderstood);
    expect(primary.calls, 1);
    expect(fallback.calls, 0);
  });

  test('forwards conversation context to the fallback parser', () async {
    final primary = _StubAssistantEngine(
      const AssistantResult.notUnderstood(),
    );
    final engine = FallbackAssistantEngine(
      primary: primary,
      fallback: const FakeAssistantEngine(),
    );

    final result = await engine.interpret(
      'ألف وخمسمئة',
      actions,
      conversationContext: 'المستخدم: أضف راتب لشهر 2026-11\n'
          'المساعد: ما المبلغ المطلوب تسجيله؟',
    );

    expect(result.kind, AssistantResultKind.command);
    expect(result.command!.parameters['amountMinorUnits'], 1500);
    expect(result.command!.parameters['month'], 11);
  });
}
