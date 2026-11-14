// ignore_for_file: curly_braces_in_flow_control_structures, prefer_interpolation_to_compose_strings

import 'dart:typed_data';

import 'assistant_input_normalizer.dart';

enum AssistantResultKind { command, answer, clarification, notUnderstood }
final class AssistantCommand {
  const AssistantCommand({required this.name, required this.parameters});
  final String name;
  final Map<String,Object?> parameters;
}
final class AssistantResult {
  const AssistantResult._(this.kind,{this.command,this.message});
  const AssistantResult.command(AssistantCommand value):this._(AssistantResultKind.command,command:value);
  const AssistantResult.answer(String value):this._(AssistantResultKind.answer,message:value);
  const AssistantResult.clarification(String value):this._(AssistantResultKind.clarification,message:value);
  const AssistantResult.notUnderstood():this._(AssistantResultKind.notUnderstood);
  final AssistantResultKind kind;
  final AssistantCommand? command;
  final String? message;
}
final class AssistantInputException implements Exception {
  const AssistantInputException(this.message);
  final String message;
}

final class AssistantMedia {
  const AssistantMedia({this.imageBytes, this.audioBytes});
  final Uint8List? imageBytes;
  final Uint8List? audioBytes;
  bool get hasImage => imageBytes != null;
  bool get hasAudio => audioBytes != null;
}

abstract interface class AssistantEngine {
  Future<AssistantResult> interpret(
    String input,
    List<String> availableActions, {
    AssistantMedia? media,
    String conversationContext = '',
  });
}
final class FakeAssistantEngine implements AssistantEngine {
  const FakeAssistantEngine();

  static const _input = AssistantInputNormalizer();

  @override
  Future<AssistantResult> interpret(
    String input,
    List<String> availableActions, {
    AssistantMedia? media,
    String conversationContext = '',
  }) async {
    if (media != null) return const AssistantResult.notUnderstood();
    final text = _input.normalize(input);
    if (text.isEmpty) return const AssistantResult.notUnderstood();

    bool has(Iterable<String> phrases) => _input.containsAny(text, phrases);
    bool can(String action) => availableActions.contains(action);

    if (has(const [
      'ملخص',
      'وضعى المالي',
      'وضعي المالي',
      'الوضع المالي',
      'كيف اموري المالية',
      'كيف وضعي',
      'اعطني نظرة مالية',
      'اعرض وضع الحساب',
      'financial summary',
      'dashboard summary',
    ])) {
      if (!can('read_dashboard_summary')) {
        return const AssistantResult.notUnderstood();
      }
      final requestedMonth = _input.extractMonth(input);
      return AssistantResult.command(
        AssistantCommand(
          name: 'read_dashboard_summary',
          parameters: {
            if (requestedMonth != null) 'year': requestedMonth.$1,
            if (requestedMonth != null) 'month': requestedMonth.$2,
          },
        ),
      );
    }

    final navigationVerb = has(const [
      'افتح',
      'انتقل',
      'اذهب',
      'روح',
      'وديني',
      'خذني',
      'حولني',
      'اعرض قسم',
      'go to',
      'open',
    ]);
    if (navigationVerb && can('navigate_to_section')) {
      final section = _navigationSection(has);
      if (section != null) {
        return AssistantResult.command(
          AssistantCommand(
            name: 'navigate_to_section',
            parameters: {'section': section},
          ),
        );
      }
    }

    final readVerb = has(const [
      'اعرض',
      'وريني',
      'فرجيني',
      'هات',
      'جيب',
      'طلع',
      'شوف',
      'اشوف',
      'اعطيني',
      'ارني',
      'قائمة',
      'تفاصيل',
      'عرض',
      'كم',
      'قديش',
      'شكد',
      'شو عندي',
      'show',
      'list',
      'how much',
    ]);

    final remainingQuestion = has(const [
      'الباقي',
      'المتبقي',
      'شو ضل',
      'كم بقي',
      'قديش بقي',
      'قديش ضل',
      'شكد باقي',
      'شكد ضل',
      'كم ضل',
      'كم تبقى',
      'remaining',
      'left at work',
    ]);
    if (remainingQuestion &&
        !has(const ['الفاتورة', 'الفواتير', 'الدين', 'المنزل', 'البيت'])) {
      if (!can('read_work_remaining')) {
        return const AssistantResult.notUnderstood();
      }
      return const AssistantResult.command(
        AssistantCommand(name: 'read_work_remaining', parameters: {}),
      );
    }

    final totalQuestion = has(const [
      'مجموع',
      'اجمالي',
      'المجموع',
      'الاجمالي',
      'كم صرفت',
      'قديش صرفت',
      'total',
      'sum',
    ]);
    if (totalQuestion) {
      final section = _section(has);
      if (section == null) {
        return const AssistantResult.clarification(
          'مجموع أي قسم تقصد: العمل أم المنزل أم الديون؟',
        );
      }
      final requestedMonth = _input.extractMonth(input);
      if (requestedMonth == null) {
        return const AssistantResult.clarification(
          'أي شهر تقصد؟ اذكر اسم الشهر أو رقمه والسنة.',
        );
      }
      if (!can('read_month_total')) {
        return const AssistantResult.notUnderstood();
      }
      return AssistantResult.command(
        AssistantCommand(
          name: 'read_month_total',
          parameters: {
            'section': section,
            'year': requestedMonth.$1,
            'month': requestedMonth.$2,
          },
        ),
      );
    }

    if (readVerb) {
      final readAction = _readAction(has);
      if (readAction != null && can(readAction)) {
        return AssistantResult.command(
          AssistantCommand(name: readAction, parameters: {}),
        );
      }
    }

    final writeVerb = has(const [
      'اضف',
      'ضيف',
      'زيد',
      'سجل',
      'سجلي',
      'احفظ',
      'ادخل',
      'دخل',
      'قيد',
      'حط',
      'حطلي',
      'نزل',
      'اعمل',
      'سوي',
      'سجل لي',
      'انشئ',
      'اضافة',
      'تسجيل',
      'add',
      'create',
      'record',
      'save',
    ]);

    final receiptVerb = has(const [
      'استلمت',
      'قبضت',
      'وصلني',
      'وصلتني',
      'نزل بحسابي',
      'نزل لي',
      'اخذت',
      'اخدت',
      'استلام',
      'received',
      'got paid',
    ]);

    final amount = _input.extractAmount(input);
    final requestedMonth = _input.extractMonth(input);

    final isTransfer = has(const [
      'حول',
      'حولت',
      'تحويل',
      'نقلت',
      'نقل',
      'ودي',
      'وديت',
      'حطيت للبيت',
      'للمنزل',
      'للبيت',
      'transfer',
    ]) && has(const ['المنزل', 'البيت', 'للبيت', 'للمنزل', 'home']);
    if (isTransfer && (writeVerb || receiptVerb)) {
      if (amount == null) {
        return const AssistantResult.clarification('كم مبلغ التحويل؟');
      }
      if (!can('save_work_home_transfer')) {
        return const AssistantResult.notUnderstood();
      }
      return AssistantResult.command(
        AssistantCommand(
          name: 'save_work_home_transfer',
          parameters: {'amountMinorUnits': amount},
        ),
      );
    }

    final isAdvance = has(const [
      'سلفة',
      'سلفه',
      'تسبيق',
      'مقدم من الراتب',
      'مقدمه من الراتب',
      'advance',
    ]);
    final isPayment = has(const [
      'دفعة',
      'دفعه',
      'دفعات',
      'قسط',
      'اقساط',
      'جزء من الراتب',
      'salary payment',
      'payment',
    ]);
    final isSalary = has(const [
      'راتب',
      'راتبي',
      'معاش',
      'معاشي',
      'مرتب',
      'اجرة',
      'اجر',
      'دخل العمل',
      'salary',
      'paycheck',
    ]);

    if ((writeVerb || receiptVerb) && (isSalary || isAdvance || isPayment)) {
      if (amount == null) {
        return const AssistantResult.clarification('ما المبلغ المطلوب تسجيله؟');
      }
      if (requestedMonth == null) {
        return const AssistantResult.clarification(
          'لأي شهر هذا الراتب أو السلفة أو الدفعة؟',
        );
      }
      if (!can('save_work_entry')) {
        return const AssistantResult.notUnderstood();
      }
      final kind = isAdvance
          ? 'advance'
          : (isPayment || receiptVerb)
              ? 'payment'
              : 'salary';
      return AssistantResult.command(
        AssistantCommand(
          name: 'save_work_entry',
          parameters: {
            'kind': kind,
            'amountMinorUnits': amount,
            'year': requestedMonth.$1,
            'month': requestedMonth.$2,
          },
        ),
      );
    }

    final isRent = has(const [
      'ايجار',
      'اجار',
      'بدل سكن',
      'rent',
    ]);
    final isBill = has(const [
      'فاتورة',
      'فاتوره',
      'فواتير',
      'اشتراك',
      'bill',
    ]);
    if ((writeVerb || receiptVerb) && (isRent || isBill)) {
      if (amount == null) {
        return const AssistantResult.clarification(
          'ما قيمة الفاتورة أو الإيجار؟',
        );
      }
      if (requestedMonth == null) {
        return const AssistantResult.clarification(
          'ما الشهر المستحق لهذه الفاتورة أو الإيجار؟',
        );
      }
      if (!can('save_home_bill')) {
        return const AssistantResult.notUnderstood();
      }
      final title = isRent ? 'الإيجار' : _billTitle(text);
      if (title == null || title.trim().isEmpty) {
        return const AssistantResult.clarification(
          'ما اسم الفاتورة أو الاشتراك؟',
        );
      }
      return AssistantResult.command(
        AssistantCommand(
          name: 'save_home_bill',
          parameters: {
            'title': title,
            'kind': isRent ? 'rent' : 'monthly',
            'amountMinorUnits': amount,
            'year': requestedMonth.$1,
            'month': requestedMonth.$2,
          },
        ),
      );
    }

    final isHomeExpense = has(const [
      'مصروف',
      'مصروفات',
      'مشتريات البيت',
      'اغراض البيت',
      'مشتريات المنزل',
      'صرف البيت',
      'expense',
      'groceries',
    ]);
    if ((writeVerb || receiptVerb) && isHomeExpense) {
      if (amount == null) {
        return const AssistantResult.clarification('كم قيمة مصروف المنزل؟');
      }
      final category = _category(has, text);
      if (category == null) {
        return const AssistantResult.clarification(
          'ما تصنيف المصروف؟ مثل الطعام أو الكهرباء أو المواصلات.',
        );
      }
      if (requestedMonth == null) {
        return const AssistantResult.clarification(
          'ما شهر وتاريخ المصروف؟',
        );
      }
      if (!can('save_home_expense')) {
        return const AssistantResult.notUnderstood();
      }
      final explicitDate = RegExp(
        r'(20\d{2}-\d{2}-\d{2})',
      ).firstMatch(_input.normalize(input))?.group(1);
      final date = explicitDate ??
          (requestedMonth.$1.toString() +
              '-' +
              requestedMonth.$2.toString().padLeft(2, '0') +
              '-01');
      return AssistantResult.command(
        AssistantCommand(
          name: 'save_home_expense',
          parameters: {
            'amountMinorUnits': amount,
            'categoryId': category,
            'date': date,
            'year': requestedMonth.$1,
            'month': requestedMonth.$2,
          },
        ),
      );
    }

    final isDebt = has(const [
      'دين',
      'ديون',
      'علي دين',
      'لي دين',
      'debt',
    ]);
    if (writeVerb && isDebt) {
      if (amount == null) {
        return const AssistantResult.clarification('ما مبلغ الدين؟');
      }
      final direction = _debtDirection(has);
      if (direction == null) {
        return const AssistantResult.clarification(
          'هل المبلغ لك عند شخص (دائن)، أم عليك لشخص (مدين)؟',
        );
      }
      final counterparty = _counterparty(text);
      if (counterparty == null) {
        return const AssistantResult.clarification('ما اسم الشخص أو الجهة؟');
      }
      if (requestedMonth == null) {
        return const AssistantResult.clarification('ما الشهر المستحق للدين؟');
      }
      if (!can('save_debt')) return const AssistantResult.notUnderstood();
      return AssistantResult.command(
        AssistantCommand(
          name: 'save_debt',
          parameters: {
            'amountMinorUnits': amount,
            'direction': direction,
            'counterparty': counterparty,
            'year': requestedMonth.$1,
            'month': requestedMonth.$2,
          },
        ),
      );
    }

    return const AssistantResult.notUnderstood();
  }

  static String? _navigationSection(
    bool Function(Iterable<String>) has,
  ) {
    if (has(const ['الرئيسية', 'لوحة التحكم', 'dashboard', 'home screen'])) {
      return 'dashboard';
    }
    if (has(const ['الديون', 'الذمم', 'debts'])) return 'debts';
    if (has(const ['المنزل', 'البيت', 'المصروفات', 'home'])) return 'home';
    if (has(const ['العمل', 'الرواتب', 'الراتب', 'salary', 'work'])) {
      return 'work';
    }
    if (has(const ['الذكاء الاصطناعي', 'المساعد', 'ai assistant'])) return 'ai';
    if (has(const ['الاعدادات', 'الضبط', 'settings'])) return 'settings';
    return null;
  }

  static String? _readAction(bool Function(Iterable<String>) has) {
    if (has(const ['تحويلات', 'التحويلات', 'التحويلات للبيت', 'transfers'])) {
      return 'read_work_transfers';
    }
    if (has(const ['فواتير', 'فواتير المنزل', 'الايجار', 'الاشتراكات', 'bills', 'rent'])) {
      return 'read_home_bills';
    }
    if (has(const ['مصروفات المنزل', 'مصروفات البيت', 'مشتريات البيت', 'home expenses'])) {
      return 'read_home_expenses';
    }
    if (has(const ['الديون', 'الدين', 'ديوني', 'المبالغ المستحقة', 'debts'])) {
      return 'read_debts';
    }
    if (has(const ['سجلات العمل', 'الرواتب', 'الراتب', 'السلف', 'الدفعات', 'work records'])) {
      return 'read_work_records';
    }
    return null;
  }

  static String? _section(bool Function(Iterable<String>) has) {
    if (has(const ['العمل', 'الرواتب', 'الراتب', 'work'])) return 'work';
    if (has(const ['المنزل', 'البيت', 'المصروفات', 'home'])) return 'home';
    if (has(const ['الديون', 'الدين', 'debts'])) return 'debts';
    return null;
  }

  static String? _category(
    bool Function(Iterable<String>) has,
    String text,
  ) {
    final explicit = RegExp(
      r'(?:تصنيف|فئة|بند)\s+([a-z0-9_-]+)',
    ).firstMatch(text)?.group(1);
    if (explicit != null && explicit.trim().isNotEmpty) return explicit.trim();

    const aliases = <String, List<String>>{
      'groceries': ['طعام', 'اكل', 'اطعمة', 'بقالة', 'مقاضي', 'مواد غذائية', 'غذاء', 'groceries', 'food'],
      'utilities': ['كهرباء', 'ماء', 'مي', 'غاز', 'انترنت', 'مياه', 'utilities'],
      'housing': ['سكن', 'ايجار', 'اجار', 'housing'],
      'cleaning': ['تنظيف', 'منظفات', 'مواد تنظيف', 'cleaning'],
      'maintenance': ['صيانة', 'تصليح', 'اصلاح', 'maintenance'],
      'transport': ['مواصلات', 'بنزين', 'وقود', 'تاكسي', 'نقل', 'transport'],
      'personal': ['ملابس', 'شخصي', 'مستلزمات شخصية', 'personal'],
      'health': ['صحة', 'دواء', 'ادوية', 'علاج', 'طبيب', 'مستشفى', 'health'],
      'other': ['اخرى', 'متفرقات', 'other'],
    };
    for (final entry in aliases.entries) {
      if (has(entry.value)) return entry.key;
    }
    return null;
  }

  static String? _billTitle(String text) {
    final match = RegExp(
      r'(?:فاتورة|اشتراك)\s+([\p{L} ]+?)(?=\s+(?:بمبلغ|بقيمة|مبلغ|لشهر|شهر|هذا الشهر|الشهر الحالي|20\d{2}|[0-9]))',
      unicode: true,
    ).firstMatch(text);
    final title = match?.group(1)?.trim();
    return title == null || title.isEmpty ? null : title;
  }

  static String? _debtDirection(
    bool Function(Iterable<String>) has,
  ) {
    if (has(const ['دائن', 'لي عند', 'الي عند', 'شخص مدين لي', 'creditor'])) {
      return 'creditor';
    }
    if (has(const ['مدين', 'علي', 'عليه', 'علي لشخص', 'debtor'])) {
      return 'debtor';
    }
    return null;
  }

  static String? _counterparty(String text) {
    final match = RegExp(
      r'(?:مع|لدى|عند|على|لصالح|من)\s+([\p{L}]+)',
      unicode: true,
    ).firstMatch(text);
    final name = match?.group(1)?.trim();
    if (name == null ||
        name.isEmpty ||
        const {'شخص', 'احد', 'طرف', 'البيت', 'المنزل'}.contains(name)) {
      return null;
    }
    return name;
  }
}