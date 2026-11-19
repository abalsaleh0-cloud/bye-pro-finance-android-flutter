import 'package:expense_app/features/ai/domain/action_registry.dart';
import 'package:expense_app/features/ai/domain/assistant_engine.dart';
import 'package:expense_app/features/ai/domain/assistant_input_normalizer.dart';
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
    List<GemmaFunctionSpec> functions, {
    AssistantMedia? media,
  });
}

final class GemmaAssistantEngine implements AssistantEngine {
  GemmaAssistantEngine(
    this.generator, {
    this.timeout = const Duration(seconds: 30),
  });

  final GemmaTurnGenerator generator;
  final Duration timeout;
  static const _numbers = NumberNormalizer();
  static const _input = AssistantInputNormalizer();
  static const _partialUpdateActions = <String>{
    'save_work_entry',
    'save_home_expense',
    'save_home_bill',
    'save_debt',
    'save_work_home_transfer',
  };

  @override
  Future<AssistantResult> interpret(
    String input,
    List<String> availableActions, {
    AssistantMedia? media,
    String conversationContext = '',
    Map<String, String> expenseCategories = const {},
  }) async {
    final text = input.trim();
    if (text.isEmpty) return const AssistantResult.notUnderstood();

    try {
      final functions = _functionsForRequest(text, availableActions);

      final needsCategoryCatalog = functions.any((function) =>
          const {
            'save_home_expense',
            'read_home_categories',
            'save_home_category',
          }.contains(function.name));
      final promptCategories =
          needsCategoryCatalog ? expenseCategories : const <String, String>{};
      final prompt = _composePrompt(
        text,
        conversationContext,
        promptCategories,
      );
      GemmaModelOutput output;
      try {
        output = await generator
            .generate(prompt, functions, media: media)
            .timeout(timeout);
      } catch (error) {
        // A context-limit refusal can still happen on a small handset when
        // earlier turns plus schemas use more tokens than the model has left.
        // Retry once with the current request only; never discard the user's
        // actual message or remove financial safeguards/tools.
        if (conversationContext.trim().isEmpty ||
            !error.toString().contains('ContextLimitException')) {
          rethrow;
        }
        final retryPrompt = _composePrompt(
          text,
          '',
          promptCategories,
        );
        output = await generator
            .generate(retryPrompt, functions, media: media)
            .timeout(timeout);
      }
      if (output.parallelCalls) return const AssistantResult.notUnderstood();

      if (output.name == null) {
        final response = output.text?.trim() ?? '';
        if (media != null &&
            response.isNotEmpty &&
            response.length <= 4000 &&
            !response.startsWith('{')) {
          return AssistantResult.answer(response);
        }
        if (response.isEmpty ||
            response.length > 1200 ||
            response.startsWith('{') ||
            response.startsWith('```')) {
          return const AssistantResult.notUnderstood();
        }

        // Personal financial facts must come from an app-owned read tool.
        // General dialogue may legitimately contain numbers (for example,
        // numbered suggestions), so do not reject every numeric free-form reply.
        if (_looksLikePersonalRecordQuestion(text)) {
          return const AssistantResult.notUnderstood();
        }

        if (response.length <= 180 &&
            (response.endsWith('؟') || response.endsWith('?'))) {
          return AssistantResult.clarification(response);
        }
        return AssistantResult.answer(response);
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

      final hasStableId = normalized['id'] is String &&
          (normalized['id']! as String).trim().isNotEmpty;
      final isPartialUpdate =
          hasStableId && _partialUpdateActions.contains(output.name);
      if (isPartialUpdate) {
        final editableFields = _propertiesFor(output.name!)
            .keys
            .where((key) => key != 'id');
        if (!editableFields.any(normalized.containsKey)) {
          return const AssistantResult.clarification(
            'ما التغيير المطلوب على هذا السجل؟',
          );
        }
      } else {
        final missing = descriptor.requiredParameters
            .where((key) => normalized[key] == null)
            .toList(growable: false);
        if (missing.isNotEmpty) {
          return AssistantResult.clarification(_questionFor(missing.first));
        }
      }

      return AssistantResult.command(
        AssistantCommand(name: output.name!, parameters: normalized),
      );
    } on AssistantInputException catch (error) {
      // This clarification is produced by an app-side input guard (for
      // example, a device RAM limit), not by Gemma inference itself.
      return AssistantResult.clarification(error.message).withSource(
        AssistantResultSource.local,
      );
    } catch (_) {
      return const AssistantResult.notUnderstood();
    }
  }

  static bool _looksLikePersonalRecordQuestion(String text) {
    final normalized = _input.normalize(text);
    return _input.containsAny(normalized, const [
      'كم راتبي',
      'قديش راتبي',
      'شكد راتبي',
      'ما راتبي',
      'كم معاشي',
      'كم رصيدي',
      'قديش رصيدي',
      'ما رصيدي',
      'الرصيد الحالي',
      'كم الباقي',
      'قديش الباقي',
      'كم ضل',
      'قديش ضل',
      'كم استلمت',
      'قديش استلمت',
      'كم دفعت',
      'قديش دفعت',
      'كم صرفت',
      'قديش صرفت',
      'كم أنفقت',
      'قديش أنفقت',
      'كم دخلي',
      'قديش دخلي',
      'مجموع دخلي',
      'كم معي',
      'قديش معي',
      'كم علي',
      'قديش علي',
      'كم لي',
      'قديش لي',
      'مجموع الديون',
      'الديون المستحقة',
      'الفواتير المستحقة',
      'مجموع المصاريف',
      'اجمالي المصاريف',
      'اعرض المصروفات',
      'اعرض الديون',
      'اعرض الفواتير',
      'اعرض التحويلات',
      'اعرض الرواتب',
      'سجلات العمل',
      'مصروفاتي',
      'ديوني',
      'فواتيري',
      'تحويلاتي',
      'my balance',
      'my salary',
      'my expenses',
      'my debts',
    ]);
  }

  static String _composePrompt(
    String currentText,
    String conversationContext,
    Map<String, String> expenseCategories,
  ) {
    // Keep only a short tail of dialogue. The model's 2K-token context also
    // contains the system instructions, selected tool schemas, and its reply.
    final rawContext = conversationContext.trim();
    final context = rawContext.length <= 480
        ? rawContext
        : '…${rawContext.substring(rawContext.length - 479)}';
    final categoryCatalog = expenseCategories.entries
        .take(12)
        .map((entry) => '${entry.key} = ${entry.value}')
        .join('؛ ');
    final boundedCatalog = categoryCatalog.length <= 300
        ? categoryCatalog
        : '${categoryCatalog.substring(0, 299)}…';
    final categoryInstruction = boundedCatalog.isEmpty
        ? ''
        : '\nالتصنيفات المتاحة (المعرّف = الاسم): $boundedCatalog. اختر منها فقط.';
    if (context.isEmpty) {
      return categoryInstruction.isEmpty
          ? currentText
          : '$categoryInstruction\n$currentText';
    }
    return 'سياق حديث مختصر لفهم الإحالات فقط:\n'
        '$context$categoryInstruction\n\n'
        'رسالة المستخدم الحالية:\n$currentText';
  }

  List<GemmaFunctionSpec> _functionsForRequest(
    String text,
    List<String> availableActions,
  ) {
    final normalized = _input.normalize(text);
    bool has(List<String> phrases) => phrases.any((phrase) {
      final candidate = _input.normalize(phrase);
      // Arabic definite articles and attached conjunctions are common in
      // real user wording. Substring matching here intentionally broadens
      // only domain/tool selection; returned actions remain schema-validated.
      return candidate.isNotEmpty &&
          (normalized.contains(candidate) ||
              _input.containsAny(normalized, [candidate]));
    });

    final selected = <String>{};
    final work = has([
      'راتب', 'راتبي', 'رواتب', 'الرواتب', 'معاش', 'معاشي', 'مرتب', 'دخلي', 'سلفة', 'تسبيق',
      'دفعة راتب', 'الباقي', 'المتبقي', 'الباقي في العمل', 'المتبقي من الراتب',
    ]);
    final homeExpenses = has([
      'مصروف', 'مصروفات', 'المصروفات', 'مصاريف', 'مصاريفي', 'مصروفاتي', 'نفقة', 'مشتريات', 'صرفت', 'انفقت', 'مصروف البيت',
      'مصروف المنزل', 'مصروفات المنزل', 'مصاريف البيت', 'مصاريف المنزل',
    ]);
    final bills = has([
      'فاتورة', 'فواتير', 'فواتيري', 'فاتورتي', 'الاشتراكات الشهرية', 'ايجار', 'ايجارات', 'كهرباء', 'ماء',
      'مياه', 'انترنت', 'اشتراك', 'اشتراكات', 'غاز المنزل',
    ]);
    final debts = has([
      'دين', 'ديون', 'ديوني', 'مجموع الديون', 'كم علي', 'قديش علي', 'كم لي', 'قديش لي', 'دائن', 'مدين', 'سداد', 'سددت', 'قرض',
      'اقرضت', 'استلفت', 'دفعة الدين', 'دفعات الدين',
    ]);
    final transfers = has([
      'تحويل', 'تحويلات', 'التحويلات', 'تحويلاتي', 'حولت', 'حول', 'نقلت للبيت', 'نقلت للمنزل',
      'من العمل للبيت', 'من العمل للمنزل',
    ]);
    final categories = has(['تصنيف', 'تصنيفات', 'فئة مصروف', 'فئات المصروف']);

    if (work) {
      selected.addAll({
        'save_work_entry',
        'delete_work_entry',
        'read_work_records',
        'read_work_remaining',
      });
    }
    if (homeExpenses) {
      selected.addAll({
        'save_home_expense',
        'delete_home_expense',
        'read_home_expenses',
      });
    }
    if (bills) {
      selected.addAll({
        'save_home_bill',
        'delete_home_bill',
        'record_home_bill_payment',
        'read_home_bills',
        'read_home_bill_payments',
      });
    }
    if (debts) {
      selected.addAll({
        'save_debt',
        'delete_debt',
        'record_debt_payment',
        'read_debts',
        'read_debt_payments',
      });
    }
    if (transfers) {
      selected.addAll({
        'save_work_home_transfer',
        'delete_work_home_transfer',
        'read_work_transfers',
      });
    }
    if (categories) {
      selected.addAll({
        'read_home_categories',
        'save_home_category',
        'delete_home_category',
      });
    }

    final summary = has([
      'ملخص', 'ملخصا', 'ملخص الشهر', 'مجموع', 'اجمالي', 'الاجمالي', 'الرصيد',
      'رصيدي', 'كشف الحساب', 'كشف مالي',
    ]);
    if (summary) {
      selected.addAll({'read_dashboard_summary', 'read_month_total'});
    }
    final navigationVerb = has(['افتح', 'انتقل', 'اذهب', 'روح', 'خذني']);
    final navigationTarget = has([
      'قسم', 'العمل', 'المنزل', 'البيت', 'الديون', 'الرئيسية',
      'الاعدادات', 'الضبط', 'settings', 'home', 'dashboard',
    ]);
    if (navigationVerb && navigationTarget) {
      selected.add('navigate_to_section');
    }

    // Resolve generic follow-ups through the chat's prior subject. Only attach
    // deletion schemas for an unqualified delete request, never every finance
    // tool; payment-history ambiguity exposes only the two read tools.
    final genericDelete = has(['احذف', 'حذف', 'امسح', 'الغاء', 'إلغاء']);
    if (genericDelete && selected.isEmpty) {
      selected.addAll(
        availableActions.where((name) => name.startsWith('delete_')),
      );
    }
    final genericPaymentHistory = has([
      'سجل الدفعات', 'سجل الدفعات', 'تاريخ الدفعات', 'حركة الدفعات',
    ]);
    if (genericPaymentHistory && selected.isEmpty) {
      selected.addAll(
        availableActions.where((name) =>
            name == 'read_debt_payments' ||
            name == 'read_home_bill_payments'),
      );
    }

    final vagueFinancialRequest = has([
      'رصيد', 'حسابي', 'الباقي', 'المتبقي', 'كم ضل', 'راتب', 'دين', 'فاتورة', 'مصروف',
      'مبلغ', 'دينار', 'سجل مالي', 'بياناتي المالية',
    ]) || (RegExp(r'\d').hasMatch(text) &&
        has(['اضف', 'سجل', 'احفظ', 'عدل', 'احذف', 'ادفع', 'حول']));
    if (vagueFinancialRequest && selected.isEmpty) {
      selected.add('read_dashboard_summary');
    }
    if (selected.isEmpty) {
      // General writing, explanations, greetings, and ordinary conversation
      // do not need the large financial tool schema in the context window.
      return const <GemmaFunctionSpec>[];
    }

    final result = ActionRegistry.descriptors
        .where((descriptor) =>
            availableActions.contains(descriptor.name) &&
            selected.contains(descriptor.name))
        .map(_functionFor)
        .toList(growable: true);
    result.add(const GemmaFunctionSpec(
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
    return result;
  }

  GemmaFunctionSpec _functionFor(ActionDescriptor descriptor) {
    return GemmaFunctionSpec(
      name: descriptor.name,
      description: _descriptionFor(descriptor.name),
      properties: _propertiesFor(descriptor.name),
      // Save tools can represent both creation and record-ID edits. The
      // engine validates create requirements after the model returns, while
      // ID edits may supply only the fields the user asked to change.
      required: _partialUpdateActions.contains(descriptor.name)
          ? const <String>[]
          : (descriptor.requiredParameters.toList()..sort()),
    );
  }

  static String _descriptionFor(String name) => switch (name) {
        'save_work_entry' => 'Create a work income record for a due month.',
        'delete_work_entry' => 'Delete one work record by identifier or by a unique kind, amount and date/month match.',
        'save_home_expense' => 'Create a household expense record.',
        'delete_home_expense' => 'Delete one household expense by identifier or a unique category, amount and date/month match.',
        'save_home_bill' => 'Create or update a monthly household bill or home rent. kind is monthly or rent.',
        'delete_home_bill' => 'Delete a household bill or rent by identifier or exact unique bill title.',
        'record_home_bill_payment' => 'Record a payment or partial payment for an existing household bill or rent.',
        'read_home_bills' => 'List household bills and rent with their remaining unpaid amounts.',
        'read_work_records' => 'List saved work salary, advance, and payment records with identifiers.',
        'read_home_expenses' => 'List household daily expenses with identifiers.',
        'read_debts' => 'List debts, counterparties, outstanding amounts, and identifiers.',
        'read_work_transfers' => 'List work-to-home transfers with amounts and dates.',
        'read_debt_payments' => 'List payment history for one debt selected by debt ID or an exact unique counterparty name and optional direction.',
        'read_home_bill_payments' => 'List payment history for one household bill selected by bill ID or an exact unique bill title.',
        'save_work_home_transfer' => 'Transfer money from work to household. Use date for an exact day or year and month for a month-only date; preserve the original day when editing an existing transfer.',
        'delete_work_home_transfer' => 'Delete one work-to-household transfer by identifier or a unique amount and date/month match.',
        'save_debt' => 'Create a debt record.',
        'delete_debt' => 'Delete one debt by identifier or exact unique counterparty and optional direction.',
        'record_debt_payment' => 'Record a payment against an existing debt.',
        'read_work_remaining' => 'Request the remaining work balance from the app.',
        'read_month_total' => 'Request a section total for a specified month from the app.',
        'read_dashboard_summary' => 'Read the selected-month financial dashboard summary. All figures must be calculated by the app from its stored records; do not estimate or invent values.',
        'navigate_to_section' => 'Open one app section selected by the user without changing financial data.',
        'read_home_categories' => 'List all existing household expense categories available for selection.',
        'save_home_category' => 'Create a custom household expense category or rename an existing custom category by ID.',
        'delete_home_category' => 'Delete an unused custom expense category by ID or exact name; built-in categories are protected.',
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
          'date': date,
          'id': string,
          'note': note,
        },
      'delete_work_entry' => {
          'id': string,
          'kind': {'type': 'string', 'enum': ['salary', 'advance', 'payment', 'salaryPayment']},
          'amountMinorUnits': integer,
          'year': integer,
          'month': integer,
          'date': date,
        },
      'delete_home_expense' => {
          'id': string,
          'categoryId': string,
          'categoryName': string,
          'amountMinorUnits': integer,
          'year': integer,
          'month': integer,
          'date': date,
        },
      'delete_work_home_transfer' => {
          'id': string,
          'amountMinorUnits': integer,
          'year': integer,
          'month': integer,
          'date': date,
        },
      'delete_debt' => {
          'id': string,
          'debtId': string,
          'counterparty': string,
          'direction': {'type': 'string', 'enum': ['creditor', 'debtor']},
        },
      'save_home_bill' => {
          'title': string,
          'kind': {'type': 'string', 'enum': ['monthly', 'rent']},
          'amountMinorUnits': integer,
          'year': integer,
          'month': integer,
          'date': date,
          'id': string,
          'note': note,
        },
      'delete_home_bill' => {'id': string, 'billId': string, 'billTitle': string},
      'record_home_bill_payment' => {
          'billId': string,
          'billTitle': string,
          'amountMinorUnits': integer,
          'date': date,
          'note': note,
        },
      'read_home_bills' || 'read_work_records' || 'read_home_expenses' || 'read_debts' || 'read_work_transfers' => {
          'year': integer,
          'month': integer,
          'allRecords': {'type': 'boolean'},
        },
      'read_home_categories' => <String, Map<String, Object>>{},
      'save_home_category' => {'name': string, 'id': string},
      'delete_home_category' => {'id': string, 'name': string},
      'read_debt_payments' => {
          'debtId': string,
          'id': string,
          'counterparty': string,
          'direction': {'type': 'string', 'enum': ['creditor', 'debtor']},
        },
      'read_home_bill_payments' => {
          'billId': string,
          'id': string,
          'billTitle': string,
        },
      'save_home_expense' => {
          'amountMinorUnits': integer,
          'categoryId': string,
          'categoryName': string,
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
          'year': integer,
          'month': integer,
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
          'date': date,
          'id': string,
          'note': note,
        },
      'record_debt_payment' => {
          'debtId': string,
          'counterparty': string,
          'direction': {'type': 'string', 'enum': ['creditor', 'debtor']},
          'amountMinorUnits': integer,
          'date': date,
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
      'read_dashboard_summary' => {
          'year': integer,
          'month': integer,
        },
      'navigate_to_section' => {
          'section': {
            'type': 'string',
            'enum': ['dashboard', 'work', 'home', 'debts', 'ai', 'settings'],
          },
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
      if (value is String && key == 'amountMinorUnits') {
        final parsed = _numbers.parseInteger(value) ??
            _input.extractAmount(value);
        if (parsed == null) return null;
        result[key] = parsed;
      } else if (value is String && (key == 'year' || key == 'month')) {
        final parsed = _numbers.parseInteger(value);
        if (parsed != null) {
          result[key] = parsed;
        } else {
          final month = _input.extractMonth(value);
          if (month == null) return null;
          result[key] = key == 'year' ? month.$1 : month.$2;
        }
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
        'kind' => 'هل تقصد راتباً أم سلفة أم دفعة أم فاتورة شهرية أم إيجاراً؟',
        'direction' => 'هل الدين دائن أم مدين؟',
        'counterparty' => 'ما اسم الطرف المعني بالدين؟',
        'categoryId' || 'categoryName' => 'ما تصنيف المصروف؟',
        'name' => 'ما اسم التصنيف الذي تريد إضافته؟',
        'title' => 'ما اسم الفاتورة أو الإيجار؟',
        'billId' => 'أي فاتورة تريد تسجيل الدفعة عليها؟',
        'date' => 'ما تاريخ المصروف؟',
        'debtId' => 'أي دين تريد تسجيل الدفعة عليه؟',
        'id' => 'ما رقم السجل المطلوب؟',
        _ => 'أحتاج توضيحاً إضافياً قبل المتابعة.',
      };
}
