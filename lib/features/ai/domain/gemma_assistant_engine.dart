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
    this.timeout = const Duration(seconds: 100),
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
      final functions = _functionsFor(
        text,
        availableActions,
        conversationContext,
      );
      final needsCategoryCatalog = functions.any(
        (function) =>
            function.name == 'save_home_expense' ||
            function.name == 'save_home_category',
      );
      final prompt = _composePrompt(
        text,
        conversationContext,
        needsCategoryCatalog ? expenseCategories : const <String, String>{},
      );
      final output = await generator
          .generate(prompt, functions, media: media)
          .timeout(timeout);
      final exposedFunctionNames = functions
          .map((function) => function.name)
          .toSet();
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
        if (!exposedFunctionNames.contains('ask_clarification')) {
          return const AssistantResult.notUnderstood();
        }
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
      if (descriptor == null ||
          !availableActions.contains(output.name) ||
          !exposedFunctionNames.contains(output.name)) {
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

  List<GemmaFunctionSpec> _functionsFor(
    String currentText,
    List<String> availableActions,
    String conversationContext,
  ) {
    // A general conversation must not carry twenty-plus finance schemas.
    // Route finance requests to the smallest safe set of app actions instead.
    final normalizedCurrent = _input.normalize(currentText);
    final normalizedHistory = _input.normalize(conversationContext);
    final isAnswerToClarification = currentText.trim().length <= 60 &&
        _input.containsAny(normalizedHistory, const [
          'اي شهر تقصد', 'ما الشهر المطلوب', 'ما الشهر',
          'ما المبلغ', 'ما الاسم', 'ما التاريخ', 'ما الاتجاه',
          'ما نوع', 'اذكر الشهر', 'اذكر التاريخ',
        ]);
    final isFollowUp = isAnswerToClarification ||
        _input.containsAny(normalizedCurrent, const [
          'هذا', 'هذه', 'لهذا', 'لذلك', 'نفسه', 'نفسها',
          'نفس المبلغ', 'نفس الشهر', 'نعم', 'لا', 'الشهر الحالي',
          'هالشهر', 'الشهر الماضي', 'الشهر القادم',
        ]);
    final routingText = _input.normalize(
      isFollowUp ? '$conversationContext\n$currentText' : currentText,
    );
    bool has(Iterable<String> phrases) =>
        _input.containsAny(routingText, phrases);

    final work = has(const [
      'راتب', 'راتبا', 'راتبي', 'معاش', 'مرتب', 'سلفة', 'سلفه', 'تسبيق',
      'سجلات العمل', 'قسم العمل', 'الباقي', 'المتبقي',
      'قبضت', 'استلمت', 'salary', 'advance', 'remaining', 'paycheck',
    ]);
    final bill = has(const [
      'فاتورة', 'الفاتورة', 'فواتير', 'الفواتير', 'ايجار', 'اجار',
      'الإيجار', 'الايجار', 'rent', 'اشتراك', 'bill', 'invoice',
    ]);
    final home = has(const [
      'مصروف', 'مصاريف', 'المصاريف', 'مشتريات',
      'صرفت', 'صرف', 'انفقت', 'أنفقت', 'expenses', 'household', 'home expense',
    ]);
    final debt = has(const [
      'دين', 'الديون', 'ديون', 'دائن', 'مدين',
      'سداد الدين', 'دين علي', 'كم علي', 'لي عند', 'debt', 'loan',
    ]);
    final transfer = has(const [
      'تحويل', 'تحويلات', 'حولت', 'حوّل', 'نقلت',
      'نقل للبيت', 'نقل للمنزل', 'transferred',
    ]);
    final category = has(const [
      'تصنيف', 'تصنيفات', 'فئة المصروف', 'فئات المصروف', 'category',
    ]);
    final dashboard = has(const [
      'ملخص', 'ملخصا', 'الوضع المالي', 'الرصيد', 'الميزانية',
      'كم معي', 'قديش معي', 'كم علي', 'كم لي',
      'summary', 'balance',
    ]);
    final financeIntent =
        work || bill || home || debt || transfer || category || dashboard;

    final navigation = has(const [
      'افتح', 'انتقل', 'اذهب الى', 'روح الى', 'وديني',
      'خذني', 'open section', 'navigate',
    ]);
    final deletion = has(const [
      'احذف', 'حذف', 'امسح', 'الغ', 'إزالة', 'delete', 'remove',
    ]);
    final history = has(const [
      'سجل الدفعات', 'تاريخ الدفعات', 'الدفعات السابقة',
      'سجل الدفع', 'payment history',
    ]);
    final payment = has(const [
      'دفعة', 'دفعات', 'دفعت', 'دفع', 'ادفع', 'سداد',
      'سدد', 'سددت', 'تسديد', 'دفعة جزئية', 'payment', 'paid',
    ]);
    final read = history || has(const [
      'اعرض', 'وريني', 'فرجيني', 'هات', 'جيب', 'طلع',
      'اعطني', 'اعطيني', 'ارني', 'كم', 'قديش', 'شكد',
      'شو عندي', 'تفاصيل', 'قائمة', 'المجموع', 'اجمالي',
      'إجمالي', 'ما هو', 'ما هي', 'هل استلمت', 'كم دفعت',
      'قديش دفعت', 'كم سددت', 'قديش سددت', 'متى دفعت',
      'هل وصلني', 'هل دفعت', 'هل سددت', 'هل تم الدفع',
      'متى سددت', 'متى دفعت', 'show', 'list', 'how much',
    ]);
    final write = !history && has(const [
      'اضف', 'أضف', 'إضافة', 'اضافة', 'ضيف', 'سجل', 'سجّل', 'اعمل',
      'أنشئ', 'انشئ', 'حط', 'حطلي', 'دفع', 'ادفع', 'سداد', 'دفعت',
      'سدد', 'سددت', 'استلمت', 'حول', 'حوّل', 'صرف',
      'اشتريت', 'عدّل', 'عدل', 'غيّر', 'غير',
      'add', 'create', 'record', 'pay', 'transfer', 'edit', 'update',
    ]);

    final selected = <String>{};
    final allowed = availableActions.toSet();
    void include(String name) {
      if (allowed.contains(name)) selected.add(name);
    }

    if (navigation) {
      include('navigate_to_section');
    }

    if (deletion) {
      if (work) include('delete_work_entry');
      if (bill) include('delete_home_bill');
      if (home && !bill) include('delete_home_expense');
      if (debt) include('delete_debt');
      if (transfer) include('delete_work_home_transfer');
      if (category) include('delete_home_category');
      // "احذف السجل المحدد" has no section. Keep all safe delete choices
      // available so the model can identify the record type or ask.
      if (selected.isEmpty || (!work && !bill && !home && !debt && !transfer && !category)) {
        for (final name in availableActions.where((name) => name.startsWith('delete_'))) {
          include(name);
        }
      }
    } else if (write && !read) {
      if (bill && payment) {
        include('record_home_bill_payment');
      } else if (debt && payment) {
        include('record_debt_payment');
      } else {
        if (transfer) include('save_work_home_transfer');
        if (bill) include('save_home_bill');
        if (debt) include('save_debt');
        if (work) include('save_work_entry');
        if (home && !bill) include('save_home_expense');
        if (category) include('save_home_category');
      }
    } else if (read || (financeIntent && !navigation)) {
      if (dashboard) {
        include('read_dashboard_summary');
        if (has(const ['مجموع', 'المجموع', 'اجمالي', 'إجمالي', 'total'])) {
          include('read_month_total');
        }
      }
      if (work) {
        include('read_work_records');
        if (has(const ['الباقي', 'المتبقي', 'شو ضل', 'كم ضل', 'قديش ضل', 'remaining'])) {
          include('read_work_remaining');
        }
      }
      if (bill) {
        include('read_home_bills');
        if (payment || history) include('read_home_bill_payments');
      }
      if (home && !bill) include('read_home_expenses');
      if (debt) {
        include('read_debts');
        if (payment || history) include('read_debt_payments');
      }
      if (transfer) include('read_work_transfers');
      if (category) include('read_home_categories');

      // An unqualified payment-history question may refer to either bills
      // or debts; expose only those two read-only tools and let Gemma clarify.
      if (history && !bill && !debt) {
        include('read_home_bill_payments');
        include('read_debt_payments');
      }
    }

    if (financeIntent && selected.isEmpty && !navigation) {
      // Do not dump the whole schema catalogue into the context for an
      // underspecified finance question.
      selected.add('ask_clarification');
    }

    final functions = ActionRegistry.descriptors
        .where((descriptor) => selected.contains(descriptor.name))
        .map(_functionFor)
        .toList(growable: true);
    if (selected.isNotEmpty && !selected.contains('ask_clarification')) {
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
    }
    if (selected.contains('ask_clarification') &&
        !functions.any((function) => function.name == 'ask_clarification')) {
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
    }
    return functions;
  }

  static String _composePrompt(
    String currentText,
    String conversationContext,
    Map<String, String> expenseCategories,
  ) {
    final rawContext = conversationContext.trim();
    // Keep only recent dialogue. The complete chat stays saved in the UI;
    // Gemma receives a compact window so long chats cannot consume its KV cache.
    final context = rawContext.length <= 900
        ? rawContext
        : '…${rawContext.substring(rawContext.length - 900)}';
    final categoryCatalog = expenseCategories.entries
        .take(40)
        .map((entry) => '${entry.key} = ${entry.value}')
        .join('؛ ');
    final categoryInstruction = categoryCatalog.isEmpty
        ? ''
        : '\nالتصنيفات الفعلية المتاحة في هذا التطبيق (المعرّف = الاسم): $categoryCatalog. عند تسجيل مصروف اختر التصنيف المطابق من هذه القائمة، ولا تخترع تصنيفاً أو معرّفاً.';
    if (context.isEmpty) {
      return categoryCatalog.isEmpty ? currentText : '$categoryInstruction\n$currentText';
    }
    return 'سياق المحادثة السابق للرجوع إليه لفهم الإحالات واستكمال الحوار فقط:\n'
        '$context$categoryInstruction\n\n'
        'رسالة المستخدم الحالية:\n$currentText';
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
