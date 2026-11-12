import 'package:expense_app/features/ai/domain/action_registry.dart';
import 'package:expense_app/features/ai/domain/assistant_engine.dart';
import 'package:expense_app/features/ai/domain/number_normalizer.dart';

final class GemmaFunctionSpec {
  const GemmaFunctionSpec({
    required this.name,
    required this.description,
    required this.properties,
    required this.required,
  });
  final String name;
  final String description;
  final Map<String, Map<String, Object>> properties;
  final List<String> required;
}

final class GemmaModelOutput {
  const GemmaModelOutput.call(this.name, this.arguments)
      : text = null,
        parallelCalls = false;
  const GemmaModelOutput.text(this.text)
      : name = null,
        arguments = null,
        parallelCalls = false;
  const GemmaModelOutput.multiple()
      : name = null,
        arguments = null,
        text = null,
        parallelCalls = true;
  final String? name;
  final Map<String, Object?>? arguments;
  final String? text;
  final bool parallelCalls;
}

abstract interface class GemmaTurnGenerator {
  Future<GemmaModelOutput> generate(
    String userText,
    List<GemmaFunctionSpec> functions,
  );
}

final class GemmaAssistantEngine implements AssistantEngine {
  GemmaAssistantEngine(
    this.generator, {
    this.timeout = const Duration(seconds: 30),
  });

  final GemmaTurnGenerator generator;
  final Duration timeout;
  static const _numbers = NumberNormalizer();

  @override
  Future<AssistantResult> interpret(
    String input,
    List<String> availableActions,
  ) async {
    final text = input.trim();
    if (text.isEmpty) return const AssistantResult.notUnderstood();

    try {
      final functions = ActionRegistry.descriptors
          .where((descriptor) => availableActions.contains(descriptor.name))
          .map(_functionFor)
          .toList(growable: true);
      functions.add(const GemmaFunctionSpec(
        name: 'ask_clarification',
        description: 'Ask one short Arabic clarification question. Do not guess.',
        properties: {
          'question': {
            'type': 'string',
            'description': 'A short question in Arabic.',
          },
        },
        required: ['question'],
      ));

      final output = await generator.generate(text, functions).timeout(timeout);
      if (output.parallelCalls) return const AssistantResult.notUnderstood();

      if (output.name == null) {
        final question = output.text?.trim() ?? '';
        if (question.isNotEmpty &&
            question.length <= 140 &&
            !RegExp(r'[0-9٠-٩۰-۹]').hasMatch(question) &&
            !question.startsWith('{') &&
            (question.endsWith('؟') || question.endsWith('?'))) {
          return AssistantResult.clarification(question);
        }
        return const AssistantResult.notUnderstood();
      }

      final arguments = output.arguments;
      if (arguments == null) return const AssistantResult.notUnderstood();
      if (output.name == 'ask_clarification') {
        final question = arguments['question'];
        if (question is String &&
            question.trim().isNotEmpty &&
            question.trim().length <= 140 &&
            !RegExp(r'[0-9٠-٩۰-۹]').hasMatch(question)) {
          return AssistantResult.clarification(question.trim());
        }
        return const AssistantResult.notUnderstood();
      }

      ActionDescriptor? descriptor;
      for (final item in ActionRegistry.descriptors) {
        if (item.name == output.name) descriptor = item;
      }
      if (descriptor == null || !availableActions.contains(output.name)) {
        return const AssistantResult.notUnderstood();
      }

      final normalized = _normalizeArguments(arguments);
      if (normalized == null) return const AssistantResult.notUnderstood();

      final allowed = _propertiesFor(output.name!).keys.toSet();
      if (normalized.keys.any((key) => !allowed.contains(key))) {
        return const AssistantResult.notUnderstood();
      }

      final missing = descriptor.requiredParameters
          .where((key) => normalized[key] == null)
          .toList(growable: false);
      if (missing.isNotEmpty) {
        return AssistantResult.clarification(_questionFor(missing.first));
      }

      return AssistantResult.command(
        AssistantCommand(name: output.name!, parameters: normalized),
      );
    } catch (_) {
      return const AssistantResult.notUnderstood();
    }
  }

  GemmaFunctionSpec _functionFor(ActionDescriptor descriptor) {
    return GemmaFunctionSpec(
      name: descriptor.name,
      description: _descriptionFor(descriptor.name),
      properties: _propertiesFor(descriptor.name),
      required: descriptor.requiredParameters.toList()..sort(),
    );
  }

  static String _descriptionFor(String name) => switch (name) {
        'save_work_entry' => 'Create a work income record for a due month.',
        'delete_work_entry' => 'Delete a work record by its identifier.',
        'save_home_expense' => 'Create a household expense record.',
        'delete_home_expense' => 'Delete a household expense by its identifier.',
        'save_work_home_transfer' => 'Transfer money from work to household.',
        'delete_work_home_transfer' => 'Delete a work-to-household transfer.',
        'save_debt' => 'Create a debt record.',
        'delete_debt' => 'Delete a debt by its identifier.',
        'record_debt_payment' => 'Record a payment against an existing debt.',
        'read_work_remaining' => 'Request the remaining work balance from the app.',
        'read_month_total' => 'Request a section total for a specified month from the app.',
        _ => 'Perform an allowed application action.',
      };

  static Map<String, Map<String, Object>> _propertiesFor(String name) {
    const string = <String, Object>{'type': 'string'};
    const integer = <String, Object>{'type': 'integer'};
    const date = <String, Object>{
      'type': 'string',
      'description': 'Date in YYYY-MM-DD format.',
    };
    const note = <String, Object>{
      'type': 'string',
      'description': 'Optional short note.',
    };
    return switch (name) {
      'save_work_entry' => {
          'kind': {
            'type': 'string',
            'enum': ['salary', 'advance', 'payment', 'salaryPayment'],
          },
          'amountMinorUnits': integer,
          'year': integer,
          'month': integer,
          'id': string,
          'note': note,
        },
      'delete_work_entry' ||
      'delete_home_expense' ||
      'delete_work_home_transfer' ||
      'delete_debt' => {'id': string},
      'save_home_expense' => {
          'amountMinorUnits': integer,
          'categoryId': string,
          'date': date,
          'year': integer,
          'month': integer,
          'id': string,
          'note': note,
        },
      'save_work_home_transfer' => {
          'amountMinorUnits': integer,
          'id': string,
          'date': date,
          'note': note,
        },
      'save_debt' => {
          'amountMinorUnits': integer,
          'direction': {
            'type': 'string',
            'enum': ['creditor', 'debtor'],
          },
          'counterparty': string,
          'year': integer,
          'month': integer,
          'id': string,
          'note': note,
        },
      'record_debt_payment' => {
          'debtId': string,
          'amountMinorUnits': integer,
          'note': note,
        },
      'read_work_remaining' => <String, Map<String, Object>>{},
      'read_month_total' => {
          'section': {
            'type': 'string',
            'enum': ['work', 'home', 'debts'],
          },
          'year': integer,
          'month': integer,
        },
      'ask_clarification' => {
          'question': {
            'type': 'string',
            'description': 'A short Arabic question.',
          },
        },
      _ => <String, Map<String, Object>>{},
    };
  }

  static Map<String, Object?>? _normalizeArguments(
    Map<String, Object?> arguments,
  ) {
    final result = <String, Object?>{};
    for (final entry in arguments.entries) {
      final key = entry.key;
      final value = entry.value;
      if (const {'amountMinorUnits', 'year', 'month'}.contains(key) &&
          value is String) {
        final parsed = _numbers.parseInteger(value);
        if (parsed == null) return null;
        result[key] = parsed;
      } else {
        result[key] = value;
      }
    }
    return result;
  }

  static String _questionFor(String key) => switch (key) {
        'amountMinorUnits' => 'ما المبلغ المطلوب؟',
        'year' || 'month' => 'ما الشهر المستحق؟ اكتب السنة والشهر.',
        'section' => 'أي قسم تقصد: العمل أم المنزل أم الديون؟',
        'kind' => 'هل تقصد راتباً أم سلفة أم دفعة؟',
        'direction' => 'هل الدين دائن أم مدين؟',
        'counterparty' => 'ما اسم الطرف المعني بالدين؟',
        'categoryId' => 'ما تصنيف المصروف؟',
        'date' => 'ما تاريخ المصروف؟',
        'debtId' => 'أي دين تريد تسجيل الدفعة عليه؟',
        'id' => 'ما رقم السجل المطلوب؟',
        _ => 'أحتاج توضيحاً إضافياً قبل المتابعة.',
      };
}
