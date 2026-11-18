// ignore_for_file: curly_braces_in_flow_control_structures, prefer_interpolation_to_compose_strings

import 'dart:typed_data';

import 'assistant_input_normalizer.dart';
import 'number_normalizer.dart';

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
    Map<String, String> expenseCategories = const {},
  });
}
/// Tries the local language model first and the deterministic Arabic
/// parser only when the model cannot interpret the request.
final class FallbackAssistantEngine implements AssistantEngine {
  const FallbackAssistantEngine({
    required this.primary,
    required this.fallback,
  });

  final AssistantEngine primary;
  final AssistantEngine fallback;

  @override
  Future<AssistantResult> interpret(
    String input,
    List<String> availableActions, {
    AssistantMedia? media,
    String conversationContext = '',
    Map<String, String> expenseCategories = const {},
  }) async {
    final result = await primary.interpret(
      input,
      availableActions,
      media: media,
      conversationContext: conversationContext,
      expenseCategories: expenseCategories,
    );
    if (result.kind != AssistantResultKind.notUnderstood || media != null) {
      return result;
    }
    return fallback.interpret(
      input,
      availableActions,
      conversationContext: conversationContext,
      expenseCategories: expenseCategories,
    );
  }
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
    Map<String, String> expenseCategories = const {},
  }) async {
    if (media != null) return const AssistantResult.notUnderstood();
    final effectiveInput = _mergeClarificationReply(input, conversationContext);
    final text = _input.normalize(effectiveInput);
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
      final requestedMonth = _input.extractMonth(effectiveInput);
      return AssistantResult.command(
        AssistantCommand(
          name: 'read_dashboard_summary',
          parameters: {
            'year': ?requestedMonth?.$1,
            'month': ?requestedMonth?.$2,
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
      'الباقي عندي',
      'المتبقي عندي',
      'كم بقي عندي',
      'قديش ضل عندي',
      'قديش باقي عندي',
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
      final requestedMonth = _input.extractMonth(effectiveInput);
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
        final requestedMonth = _input.extractMonth(effectiveInput);
        final allRecords = has(const ['كل', 'جميع', 'كافة', 'من البداية', 'all records', 'everything']);
        final parameters = <String, Object?>{
          'year': ?requestedMonth?.$1,
          'month': ?requestedMonth?.$2,
          if (allRecords) 'allRecords': true,
        };
        if (readAction == 'read_home_bill_payments') {
          final billTitle = _billTitle(effectiveInput);
          if (billTitle == null) {
            return const AssistantResult.clarification('دفعات أي فاتورة تريد عرضها؟ اذكر اسم الفاتورة.');
          }
          parameters['billTitle'] = billTitle;
        } else if (readAction == 'read_debt_payments') {
          final counterparty = _counterparty(effectiveInput);
          if (counterparty == null) {
            return const AssistantResult.clarification('دفعات أي دين تريد عرضها؟ اذكر اسم الشخص أو الجهة.');
          }
          parameters['counterparty'] = counterparty;
          final direction = _debtDirection(has);
          if (direction != null) parameters['direction'] = direction;
        }
        return AssistantResult.command(
          AssistantCommand(name: readAction, parameters: parameters),
        );
      }
    }

    final writeVerb = has(const [
      'اضف',
      'ضيف',
      'زيد',
      'سجل',
      'سجلي',
      'سجلت',
      'سجللي',
      'ضفت',
      'ضيفلي',
      'أضفت',
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
      'سدد',
      'سددت',
      'سداد',
      'تسديد',
      'دفعت',
      'ادفع',
      'add',
      'create',
      'record',
      'save',
    ]);

    final receiptVerb = has(const [
      'استلمت',
      'استلم',
      'قبضت',
      'قبض',
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

    final currentText = _input.normalize(input);
    bool hasCurrent(Iterable<String> phrases) =>
        _input.containsAny(currentText, phrases);
    final isQuestion = hasCurrent(const [
      'هل',
      'كم',
      'قديش',
      'شكد',
      'متى',
      'وين',
      'شو',
      'ما هو',
      'ما هي',
      'what',
      'when',
      'where',
      'how',
    ]) || input.contains('؟') || input.contains('?');
    final isWriteIntent = !isQuestion && (writeVerb || receiptVerb);

    if (isQuestion &&
        receiptVerb &&
        has(const [
          'راتب',
          'راتبي',
          'معاش',
          'معاشي',
          'دفعة',
          'دفعات',
          'payment',
        ])) {
      if (can('read_work_records')) {
        return const AssistantResult.command(
          AssistantCommand(name: 'read_work_records', parameters: {}),
        );
      }
    }

    final amount = _input.extractAmount(effectiveInput);
    final explicitDate = _input.extractDate(effectiveInput) ?? _extractRelativeDate(has);
    // A fully specified date is the source of truth for its month. This
    // avoids silently moving an explicit date to a separately mentioned month.
    final requestedMonth = explicitDate == null
        ? _input.extractMonth(effectiveInput)
        : (explicitDate.year, explicitDate.month);
    final operationDate = requestedMonth == null
        ? explicitDate
        : (explicitDate != null && explicitDate.year == requestedMonth.$1 &&
                explicitDate.month == requestedMonth.$2
            ? explicitDate
            : _defaultDateForMonth(requestedMonth.$1, requestedMonth.$2));
    final note = _extractNote(effectiveInput);

    final isCategoryIntent = has(const [
      'تصنيف', 'التصنيفات', 'فئة', 'فئة المصروف', 'تصنيفات المنزل',
      'expense category', 'categories',
    ]);
    final isDeleteIntent = has(const [
      'احذف', 'حذف', 'امسح', 'ازل', 'إزالة', 'delete', 'remove',
    ]);
    final isEditIntent = has(const [
      'عدل', 'عدّل', 'تعديل', 'غير', 'غيّر', 'تغيير', 'edit', 'update',
    ]);
    final explicitId = _extractIdentifier(effectiveInput);

    if (isDeleteIntent && isCategoryIntent) {
      final categoryName = _category(has, text, expenseCategories);
      if (explicitId == null && categoryName == null) {
        return const AssistantResult.clarification('ما اسم التصنيف أو معرّفه الذي تريد حذفه؟');
      }
      if (!can('delete_home_category')) return const AssistantResult.notUnderstood();
      return AssistantResult.command(AssistantCommand(
        name: 'delete_home_category',
        parameters: {
          'id': ?explicitId,
          if (explicitId == null) 'name': expenseCategories[categoryName] ?? categoryName!,
        },
      ));
    }

    if (isEditIntent && isCategoryIntent && !isDeleteIntent) {
      final categoryId = _category(has, text, expenseCategories);
      if (categoryId == null) {
        return const AssistantResult.clarification(
          'ما اسم التصنيف المخصص الذي تريد تعديل اسمه؟',
        );
      }
      if (!categoryId.startsWith('custom_')) {
        return const AssistantResult.clarification(
          'التصنيفات الأساسية ثابتة. أستطيع تعديل اسم التصنيف المخصص فقط.',
        );
      }
      final newName = RegExp(
        r'(?:الى|إلى|ليصبح|لتصبح|باسم|اسم جديد)\s+(.+?)(?=\s+(?:ملاحظة|note)|$)',
        caseSensitive: false,
        unicode: true,
      ).firstMatch(effectiveInput)?.group(1)?.trim();
      if (newName == null || newName.isEmpty) {
        return const AssistantResult.clarification(
          'ما الاسم الجديد للتصنيف؟',
        );
      }
      if (!can('save_home_category')) return const AssistantResult.notUnderstood();
      return AssistantResult.command(AssistantCommand(
        name: 'save_home_category',
        parameters: {'id': categoryId, 'name': newName},
      ));
    }

    if (isWriteIntent && isCategoryIntent && !isDeleteIntent && !isEditIntent) {
      final nameMatch = RegExp(
        r'(?:تصنيف|فئة)\s+(.+?)(?=\s+(?:ملاحظة|note)|$)',
        caseSensitive: false,
        unicode: true,
      ).firstMatch(effectiveInput);
      final name = nameMatch?.group(1)?.trim();
      if (name == null || name.isEmpty) {
        return const AssistantResult.clarification('ما اسم التصنيف الجديد؟');
      }
      if (!can('save_home_category')) return const AssistantResult.notUnderstood();
      return AssistantResult.command(AssistantCommand(
        name: 'save_home_category',
        parameters: {'name': name},
      ));
    }

    if (isDeleteIntent) {
      final action = has(const ['فاتورة', 'فواتير', 'اشتراك', 'ايجار', 'اجار'])
          ? 'delete_home_bill'
          : has(const ['دين', 'ديون'])
              ? 'delete_debt'
              : has(const ['تحويل', 'للبيت', 'للمنزل'])
                  ? 'delete_work_home_transfer'
                  : has(const ['مصروف', 'مشتريات البيت', 'expense'])
                      ? 'delete_home_expense'
                      : 'delete_work_entry';
      if (action == 'delete_home_bill' && explicitId == null) {
        final billTitle = _billTitle(effectiveInput);
        if (billTitle == null) {
          return const AssistantResult.clarification('ما اسم الفاتورة أو الإيجار الذي تريد حذفه؟');
        }
        if (!can(action)) return const AssistantResult.notUnderstood();
        return AssistantResult.command(AssistantCommand(
          name: action,
          parameters: {'billTitle': billTitle},
        ));
      }
      if (action == 'delete_debt' && explicitId == null) {
        final counterparty = _counterparty(effectiveInput);
        if (counterparty == null) {
          return const AssistantResult.clarification('اذكر اسم صاحب الدين أو معرّف الدين الذي تريد حذفه.');
        }
        final direction = _debtDirection(has);
        if (!can(action)) return const AssistantResult.notUnderstood();
        return AssistantResult.command(AssistantCommand(
          name: action,
          parameters: {
            'counterparty': counterparty,
            'direction': ?direction,
          },
        ));
      }
      if (action == 'delete_work_home_transfer' && explicitId == null) {
        if (amount == null) {
          return const AssistantResult.clarification('كم مبلغ التحويل الذي تريد حذفه؟');
        }
        if (requestedMonth == null && explicitDate == null) {
          return const AssistantResult.clarification('ما تاريخ أو شهر التحويل حتى أحدده بدقة؟');
        }
        if (!can(action)) return const AssistantResult.notUnderstood();
        return AssistantResult.command(AssistantCommand(
          name: action,
          parameters: {
            'amountMinorUnits': amount,
            'year': ?requestedMonth?.$1,
            'month': ?requestedMonth?.$2,
            if (explicitDate != null)
              'date': explicitDate.toIso8601String().split('T').first,
          },
        ));
      }
      if (action == 'delete_work_entry' && explicitId == null) {
        final kind = has(const ['سلفة', 'سلفه', 'تسبيق'])
            ? 'advance'
            : has(const ['دفعة', 'دفعه', 'قسط'])
                ? 'payment'
                : has(const ['راتب', 'معاش', 'مرتب'])
                    ? 'salary'
                    : null;
        if (kind == null) {
          return const AssistantResult.clarification(
            'هل تريد حذف راتب أم سلفة أم دفعة؟',
          );
        }
        if (amount == null) {
          return const AssistantResult.clarification('ما مبلغ سجل العمل الذي تريد حذفه؟');
        }
        if (requestedMonth == null && explicitDate == null) {
          return const AssistantResult.clarification('ما شهر أو تاريخ سجل العمل؟');
        }
        if (!can(action)) return const AssistantResult.notUnderstood();
        return AssistantResult.command(AssistantCommand(
          name: action,
          parameters: {
            'kind': kind,
            'amountMinorUnits': amount,
            'year': ?requestedMonth?.$1,
            'month': ?requestedMonth?.$2,
            if (explicitDate != null)
              'date': explicitDate.toIso8601String().split('T').first,
          },
        ));
      }
      if (action == 'delete_home_expense' && explicitId == null) {
        final categoryId = _category(has, text, expenseCategories);
        if (categoryId == null || amount == null) {
          return const AssistantResult.clarification(
            'اذكر تصنيف المصروف ومبلغه، أو معرّف السجل.',
          );
        }
        if (requestedMonth == null && explicitDate == null) {
          return const AssistantResult.clarification(
            'ما الشهر أو التاريخ المسجل فيه المصروف حتى أتأكد من اختيار السجل الصحيح؟',
          );
        }
        if (!can(action)) return const AssistantResult.notUnderstood();
        return AssistantResult.command(AssistantCommand(
          name: action,
          parameters: {
            'categoryId': categoryId,
            'categoryName': expenseCategories[categoryId] ?? categoryId,
            'amountMinorUnits': amount,
            'year': ?requestedMonth?.$1,
            'month': ?requestedMonth?.$2,
            if (explicitDate != null)
              'date': explicitDate.toIso8601String().split('T').first,
          },
        ));
      }
      if (explicitId == null) {
        return const AssistantResult.clarification('اذكر رقم السجل أو معرّفه حتى أحذف السجل الصحيح.');
      }
      if (!can(action)) return const AssistantResult.notUnderstood();
      return AssistantResult.command(AssistantCommand(
        name: action,
        parameters: {'id': explicitId},
      ));
    }

    // Updates use the same repository-backed save action and require an exact ID.
    // The complete fields are supplied so existing values are never guessed.
    if (isEditIntent && explicitId != null) {
      if (amount == null) {
        return const AssistantResult.clarification('ما المبلغ الجديد؟');
      }
      if (has(const ['راتب', 'معاش', 'سلفة', 'دفعة', 'مرتب'])) {
        final kind = has(const ['سلفة', 'سلفه', 'تسبيق'])
            ? 'advance'
            : has(const ['دفعة', 'دفعه', 'قسط'])
                ? 'payment'
                : 'salary';
        if (requestedMonth == null) {
          return const AssistantResult.clarification('ما الشهر والسنة المسجل فيهما هذا السجل؟');
        }
        if (!can('save_work_entry')) return const AssistantResult.notUnderstood();
        return AssistantResult.command(AssistantCommand(
          name: 'save_work_entry',
          parameters: {
            'id': explicitId, 'kind': kind, 'amountMinorUnits': amount,
            'year': requestedMonth.$1, 'month': requestedMonth.$2,
            'date': (operationDate ?? _defaultDateForMonth(requestedMonth.$1, requestedMonth.$2)).toIso8601String().split('T').first,
            'note': ?note,
          },
        ));
      }
      if (has(const ['مصروف', 'مشتريات البيت'])) {
        final categoryId = _category(has, text, expenseCategories);
        if (categoryId == null || requestedMonth == null) {
          return const AssistantResult.clarification('اذكر التصنيف والشهر وتاريخ المصروف الجديد.');
        }
        if (!can('save_home_expense')) return const AssistantResult.notUnderstood();
        final date = (operationDate ?? _defaultDateForMonth(requestedMonth.$1, requestedMonth.$2)).toIso8601String().split('T').first;
        return AssistantResult.command(AssistantCommand(
          name: 'save_home_expense',
          parameters: {
            'id': explicitId, 'amountMinorUnits': amount, 'categoryId': categoryId,
            'categoryName': expenseCategories[categoryId] ?? categoryId,
            'date': date, 'year': requestedMonth.$1, 'month': requestedMonth.$2,
            'note': ?note,
          },
        ));
      }
      if (has(const ['تحويل', 'للبيت', 'للمنزل'])) {
        if (!can('save_work_home_transfer')) return const AssistantResult.notUnderstood();
        return AssistantResult.command(AssistantCommand(
          name: 'save_work_home_transfer',
          parameters: {
            'id': explicitId, 'amountMinorUnits': amount,
            'date': (operationDate ?? DateTime.now()).toIso8601String().split('T').first,
            'note': ?note,
          },
        ));
      }
      if (has(const ['فاتورة', 'فاتوره', 'اشتراك', 'ايجار', 'اجار', 'rent', 'bill'])) {
        final title = _billTitle(effectiveInput);
        if (title == null) {
          return const AssistantResult.clarification('ما اسم الفاتورة أو الإيجار الجديد؟');
        }
        if (requestedMonth == null) {
          return const AssistantResult.clarification('ما شهر الاستحقاق الجديد؟');
        }
        if (!can('save_home_bill')) return const AssistantResult.notUnderstood();
        final isRent = has(const ['ايجار', 'اجار', 'بدل سكن', 'rent']);
        return AssistantResult.command(AssistantCommand(
          name: 'save_home_bill',
          parameters: {
            'id': explicitId,
            'title': title,
            'kind': isRent ? 'rent' : 'monthly',
            'amountMinorUnits': amount,
            'year': requestedMonth.$1,
            'month': requestedMonth.$2,
            'date': (operationDate ?? _defaultDateForMonth(requestedMonth.$1, requestedMonth.$2))
                .toIso8601String().split('T').first,
            'note': ?note,
          },
        ));
      }
      if (has(const ['دين', 'ديون', 'debt'])) {
        final direction = _debtDirection(has);
        if (direction == null) {
          return const AssistantResult.clarification('هل اتجاه الدين دائن أم مدين؟');
        }
        final counterparty = _counterparty(effectiveInput);
        if (counterparty == null) {
          return const AssistantResult.clarification('ما اسم الشخص أو الجهة في سجل الدين؟');
        }
        if (requestedMonth == null) {
          return const AssistantResult.clarification('ما شهر الاستحقاق الجديد للدين؟');
        }
        if (!can('save_debt')) return const AssistantResult.notUnderstood();
        return AssistantResult.command(AssistantCommand(
          name: 'save_debt',
          parameters: {
            'id': explicitId,
            'amountMinorUnits': amount,
            'direction': direction,
            'counterparty': counterparty,
            'year': requestedMonth.$1,
            'month': requestedMonth.$2,
            'date': (operationDate ?? _defaultDateForMonth(requestedMonth.$1, requestedMonth.$2))
                .toIso8601String().split('T').first,
            'note': ?note,
          },
        ));
      }
    }

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
    if (isTransfer && !isQuestion && !readVerb) {
      if (amount == null) {
        return const AssistantResult.clarification('كم مبلغ التحويل؟');
      }
      if (!can('save_work_home_transfer')) {
        return const AssistantResult.notUnderstood();
      }
      return AssistantResult.command(
        AssistantCommand(
          name: 'save_work_home_transfer',
          parameters: {
            'amountMinorUnits': amount,
            'date': (operationDate ?? DateTime.now()).toIso8601String().split('T').first,
            'note': ?note,
          },
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

    if (isWriteIntent && (isSalary || isAdvance || isPayment)) {
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
            'date': (operationDate ?? DateTime.now()).toIso8601String().split('T').first,
            'note': ?note,
          },
        ),
      );
    }

    final billPaymentIntent = isWriteIntent &&
        has(const ['دفعت', 'سددت', 'سداد', 'تسديد', 'دفعة', 'دفعه', 'ادفع']) &&
        has(const ['فاتورة', 'فاتوره', 'اشتراك', 'bill']);
    if (billPaymentIntent) {
      if (amount == null) return const AssistantResult.clarification('كم مبلغ الدفعة؟');
      final billTitle = _billTitle(effectiveInput);
      if (billTitle == null) return const AssistantResult.clarification('ما اسم الفاتورة التي دفعت لها؟');
      if (!can('record_home_bill_payment')) return const AssistantResult.notUnderstood();
      return AssistantResult.command(AssistantCommand(
        name: 'record_home_bill_payment',
        parameters: {
          'billTitle': billTitle,
          'amountMinorUnits': amount,
          'date': (operationDate ?? DateTime.now()).toIso8601String().split('T').first,
          'note': ?note,
        },
      ));
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
    if (isWriteIntent && (isRent || isBill)) {
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
            'date': (operationDate ?? DateTime.now()).toIso8601String().split('T').first,
            'note': ?note,
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
    if (isWriteIntent && isHomeExpense) {
      if (amount == null) {
        return const AssistantResult.clarification('كم قيمة مصروف المنزل؟');
      }
      final category = _category(has, text, expenseCategories);
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
      final date = (operationDate ?? _defaultDateForMonth(requestedMonth.$1, requestedMonth.$2))
          .toIso8601String()
          .split('T')
          .first;
      return AssistantResult.command(
        AssistantCommand(
          name: 'save_home_expense',
          parameters: {
            'amountMinorUnits': amount,
            'categoryId': category,
            'categoryName': expenseCategories[category] ?? category,
            'date': date,
            'year': requestedMonth.$1,
            'month': requestedMonth.$2,
            'note': ?note,
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
    final debtPaymentIntent = isWriteIntent && isDebt &&
        has(const ['دفعت', 'سددت', 'سداد', 'تسديد', 'دفعة', 'دفعه', 'ادفع']);
    if (debtPaymentIntent) {
      if (amount == null) return const AssistantResult.clarification('كم مبلغ الدفعة التي سددتها؟');
      final counterparty = _counterparty(effectiveInput);
      if (counterparty == null) return const AssistantResult.clarification('لمن سددت الدفعة؟ اذكر اسم الشخص أو الجهة.');
      if (!can('record_debt_payment')) return const AssistantResult.notUnderstood();
      final direction = _debtDirection(has);
      return AssistantResult.command(AssistantCommand(
        name: 'record_debt_payment',
        parameters: {
          'counterparty': counterparty,
          'direction': ?direction,
          'amountMinorUnits': amount,
          'date': (operationDate ?? DateTime.now()).toIso8601String().split('T').first,
          'note': ?note,
        },
      ));
    }

    if (isWriteIntent && isDebt && !debtPaymentIntent) {
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
            'date': (operationDate ?? DateTime.now()).toIso8601String().split('T').first,
            'note': ?note,
          },
        ),
      );
    }

    return const AssistantResult.notUnderstood();
  }

  static String _mergeClarificationReply(
    String currentInput,
    String conversationContext,
  ) {
    const normalizer = AssistantInputNormalizer();
    final lines = conversationContext
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    if (lines.isEmpty || !lines.last.startsWith('المساعد:')) {
      return currentInput;
    }

    final question = lines.last.substring('المساعد:'.length).trim();
    final normalizedQuestion = normalizer.normalize(question);
    final normalizedAnswer = normalizer.normalize(currentInput);
    final amountQuestion = normalizer.containsAny(normalizedQuestion, const [
      'ما المبلغ',
      'كم المبلغ',
      'ما مبلغ',
      'كم مبلغ',
      'مبلغ الدفعة',
      'مبلغ الدين',
      'قيمة المبلغ',
      'كم قيمة',
      'قيمة الفاتورة',
      'قيمة الايجار',
      'قيمة المصروف',
      'قيمة الراتب',
    ]);
    final monthQuestion = normalizer.containsAny(normalizedQuestion, const [
      'اي شهر',
      'ما الشهر',
      'لأي شهر',
      'الشهر المستحق',
      'السنة والشهر',
    ]);
    final directionQuestion = normalizer.containsAny(normalizedQuestion, const [
      'هل المبلغ لك',
      'هل الدين دائن',
      'هل الدين مدين',
      'دائن ام مدين',
    ]);
    final nameQuestion = normalizer.containsAny(normalizedQuestion, const [
      'ما اسم الشخص',
      'اسم الشخص او الجهة',
      'ما اسم الطرف',
      'اسم صاحب الدين',
      'صاحب الدين',
      'ما اسم التصنيف الجديد',
      'اسم التصنيف الجديد',
      'ما اسم التصنيف',
      'اسم الفاتورة',
      'اسم الاشتراك',
    ]);
    final categoryQuestion = normalizer.containsAny(normalizedQuestion, const [
      'ما تصنيف المصروف',
      'ما فئة المصروف',
      'تصنيف المصروف',
    ]);
    final dateQuestion = normalizer.containsAny(normalizedQuestion, const [
      'ما تاريخ المصروف',
      'ما التاريخ',
    ]);
    final identifierQuestion = normalizer.containsAny(normalizedQuestion, const [
      'رقم السجل',
      'رقم الفاتورة',
      'اي فاتورة تريد',
      'اي دين تريد',
      'معرف السجل',
    ]);

    final answerHasAmount = normalizer.extractAmount(currentInput) != null;
    final answerHasMonth = normalizer.extractMonth(currentInput) != null;
    final answerHasDirection = _debtDirection(
      (phrases) => normalizer.containsAny(normalizedAnswer, phrases),
    ) != null;
    final answerHasCategory = _category(
      (phrases) => normalizer.containsAny(normalizedAnswer, phrases),
      normalizedAnswer,
      const {},
    ) != null ||
        (currentInput.trim().isNotEmpty &&
            currentInput.trim().length <= 48 &&
            !normalizer.containsAny(normalizedAnswer, const [
              'اضف', 'سجل', 'احذف', 'عدل', 'add', 'delete', 'update',
            ]));
    final answerHasDate = DateTime.tryParse(currentInput.trim()) != null ||
        RegExp(r'\b\d{1,2}[-/.]\d{1,2}[-/.]20\d{2}\b')
            .hasMatch(_numbersForClarification.normalizeDigits(currentInput));
    final answerHasIdentifier = RegExp(r'^[A-Za-z0-9_-]{2,64}$')
        .hasMatch(currentInput.trim());
    final answerIsShortText = currentInput.trim().isNotEmpty &&
        currentInput.trim().length <= 80 &&
        !normalizer.containsAny(normalizedAnswer, const [
          'اضف',
          'ضيف',
          'سجل',
          'احذف',
          'عدل',
          'افتح',
          'حول',
          'add',
          'delete',
          'update',
          'open',
        ]);

    final isExpectedAnswer =
        (amountQuestion && answerHasAmount) ||
        (monthQuestion && answerHasMonth) ||
        (directionQuestion && answerHasDirection) ||
        (nameQuestion && answerIsShortText) ||
        (categoryQuestion && answerHasCategory) ||
        (dateQuestion && answerHasDate) ||
        (identifierQuestion && answerHasIdentifier);
    if (!isExpectedAnswer) return currentInput;

    var originalRequestIndex = -1;
    for (var index = lines.length - 2; index >= 0; index--) {
      if (!lines[index].startsWith('المستخدم:')) continue;
      final candidate = lines[index].substring('المستخدم:'.length).trim();
      final normalizedCandidate = normalizer.normalize(candidate);
      final looksLikeWrite = normalizer.containsAny(
        normalizedCandidate,
        const [
          'اضف',
          'اضافة',
          'ضيف',
          'سجل',
          'تسجيل',
          'احفظ',
          'ادخل',
          'حط',
          'سوي',
          'انشئ',
          'سدد',
          'سداد',
          'تسديد',
          'دفعت',
          'ادفع',
          'احذف',
          'حذف',
          'امسح',
          'ازل',
          'عدل',
          'تعديل',
          'غير',
          'add',
          'create',
          'record',
          'save',
          'delete',
          'remove',
          'edit',
          'update',
        ],
      );
      if (looksLikeWrite) {
        originalRequestIndex = index;
        break;
      }
    }
    if (originalRequestIndex < 0) return currentInput;

    final previousUserTurns = <String>[];
    for (var index = originalRequestIndex; index < lines.length - 1; index++) {
      final line = lines[index];
      if (line.startsWith('المستخدم:')) {
        final turn = line.substring('المستخدم:'.length).trim();
        if (turn.isNotEmpty) previousUserTurns.add(turn);
      }
    }
    if (previousUserTurns.isEmpty) return currentInput;
    return [...previousUserTurns, currentInput.trim()].join(' ');
  }

  static const _numbersForClarification = NumberNormalizer();

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
    if (has(const ['سجل دفعات الفاتورة', 'دفعات الفاتورة', 'دفعات فاتورة', 'تاريخ دفعات الفاتورة', 'bill payment history'])) {
      return 'read_home_bill_payments';
    }
    if (has(const ['سجل دفعات الدين', 'دفعات الدين', 'دفعات ديون', 'تاريخ دفعات الدين', 'debt payment history'])) {
      return 'read_debt_payments';
    }
    if (has(const ['التصنيفات', 'تصنيفات المصروف', 'تصنيفات المنزل', 'expense categories'])) {
      return 'read_home_categories';
    }
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
    if (has(const ['سجلات العمل', 'الرواتب', 'الراتب', 'السلف', 'الدفعات', 'راتبي', 'معاشي', 'work records'])) {
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
    Map<String, String> availableCategories,
  ) {
    final normalizedText = _input.normalize(text);
    for (final entry in availableCategories.entries) {
      final label = entry.value.trim();
      if (label.isNotEmpty && _input.containsAny(normalizedText, [label])) {
        return entry.key;
      }
      if (_input.containsAny(normalizedText, [entry.key])) return entry.key;
    }
    final explicit = RegExp(
      r'(?:تصنيف|فئة|بند)\s+([\p{L}0-9_-]+)',
      unicode: true,
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
      r'(?:فاتورة|فاتوره|اشتراك)\s+([\p{L}0-9 _-]+?)(?=\s+(?:رقم|معرف|معرّف|id|بمبلغ|بقيمة|مبلغ|لشهر|شهر|هذا الشهر|الشهر الحالي|اليوم|امس|بتاريخ|ملاحظة|note|20\d{2}|[0-9])|$)',
      caseSensitive: false,
      unicode: true,
    ).firstMatch(text);
    final title = match?.group(1)?.trim();
    return title == null || title.isEmpty ? null : title;
  }

  static String? _debtDirection(
    bool Function(Iterable<String>) has,
  ) {
    if (has(const ['دائن', 'لي عند', 'الي عند', 'لي بذمة', 'مستحق لي', 'شخص مدين لي', 'creditor'])) {
      return 'creditor';
    }
    if (has(const ['مدين', 'علي دين', 'مبلغ علي', 'في ذمتي', 'علي ذمة', 'مستحق علي', 'انا مدين', 'عليه', 'debtor'])) {
      return 'debtor';
    }
    return null;
  }

  static DateTime? _extractRelativeDate(
    bool Function(Iterable<String>) has,
  ) {
    final today = DateTime.now();
    if (has(const ['قبل امس', 'قبل أمس', 'day before yesterday'])) {
      return DateTime(today.year, today.month, today.day - 2);
    }
    if (has(const ['امس', 'أمس', 'البارحة', 'yesterday'])) {
      return DateTime(today.year, today.month, today.day - 1);
    }
    if (has(const ['اليوم', 'هاليوم', 'today'])) {
      return DateTime(today.year, today.month, today.day);
    }
    return null;
  }

  static DateTime _defaultDateForMonth(int year, int month) {
    final today = DateTime.now().day;
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, today > lastDay ? lastDay : today);
  }

  static String? _extractNote(String text) {
    final match = RegExp(
      r'(?:ملاحظة|ملاحظات|note|notes)\s*(?::|هي|أنها|انه)?\s*(.+)$',
      caseSensitive: false,
      unicode: true,
    ).firstMatch(text);
    final value = match?.group(1)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  static String? _extractIdentifier(String text) {
    final match = RegExp(
      r'(?:معرّف|معرف|رقم\s+(?:السجل|الفاتورة|الدين|المصروف|التحويل|التصنيف)|id)\s*[:#：]?\s*([A-Za-z0-9_-]{2,64})',
      caseSensitive: false,
      unicode: true,
    ).firstMatch(text);
    final value = match?.group(1)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  static String? _counterparty(String text) {
    final patterns = <RegExp>[
      RegExp(r'(?:من\s+)?(?:دين|الدين)\s+(?:(?:عند|لدى|على|ل)\s+)?([\p{L}][\p{L} ]{0,35}?)(?=\s+(?:بمبلغ|بقيمة|مبلغ|اليوم|امس|بتاريخ|ملاحظة|note|من\s+الدين|رقم|معرف|معرّف|id|[0-9]|الف|ألف|مئة|مية)|$)', unicode: true),
      RegExp(r'(?:مع|لدى|عند|لصالح|ل)\s+([\p{L}][\p{L} ]{0,35}?)(?=\s+(?:بمبلغ|بقيمة|مبلغ|دين|دينا|اليوم|امس|بتاريخ|ملاحظة|note|رقم|معرف|معرّف|id|[0-9]|الف|ألف|مئة|مية)|$)', unicode: true),
    ];
    for (final pattern in patterns) {
      final value = pattern.firstMatch(text)?.group(1)?.trim();
      if (value != null &&
          value.isNotEmpty &&
          !const {'شخص', 'احد', 'طرف', 'البيت', 'المنزل'}.contains(value)) {
        return value;
      }
    }
    return null;
  }}