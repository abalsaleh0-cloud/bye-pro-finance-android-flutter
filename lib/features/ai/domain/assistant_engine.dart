// ignore_for_file: curly_braces_in_flow_control_structures, prefer_interpolation_to_compose_strings

import 'dart:typed_data';

import 'number_normalizer.dart';

enum AssistantResultKind { command, clarification, notUnderstood }
final class AssistantCommand {
  const AssistantCommand({required this.name, required this.parameters});
  final String name;
  final Map<String,Object?> parameters;
}
final class AssistantResult {
  const AssistantResult._(this.kind,{this.command,this.message});
  const AssistantResult.command(AssistantCommand value):this._(AssistantResultKind.command,command:value);
  const AssistantResult.clarification(String value):this._(AssistantResultKind.clarification,message:value);
  const AssistantResult.notUnderstood():this._(AssistantResultKind.notUnderstood);
  final AssistantResultKind kind;
  final AssistantCommand? command;
  final String? message;
}
final class AssistantMedia {
  const AssistantMedia({this.imageBytes, this.audioBytes});
  final Uint8List? imageBytes;
  final Uint8List? audioBytes;
  bool get hasImage => imageBytes != null;
  bool get hasAudio => audioBytes != null;
}

abstract interface class AssistantEngine {
  Future<AssistantResult> interpret(String input, List<String> availableActions, {AssistantMedia? media});
}
final class FakeAssistantEngine implements AssistantEngine {
  const FakeAssistantEngine();
  static const _numbers=NumberNormalizer();
  @override
  Future<AssistantResult> interpret(String input,List<String> availableActions,{AssistantMedia? media}) async {
    final text=input.trim();
    if(text.isEmpty) return const AssistantResult.notUnderstood();
    if(RegExp(r'الباقي|المتبقي').hasMatch(text)) {
      if(!availableActions.contains('read_work_remaining')) return const AssistantResult.notUnderstood();
      return const AssistantResult.command(AssistantCommand(name:'read_work_remaining',parameters:{}));
    }
    if(RegExp(r'مجموع|إجمالي|اجمالي').hasMatch(text)) {
      final section=_section(text), month=_month(text);
      if(section==null) return const AssistantResult.clarification('مجموع أي قسم تقصد: العمل أم المنزل أم الديون؟');
      if(month==null) return const AssistantResult.clarification('ما الشهر المطلوب؟ اكتب السنة والشهر مثل 2026-11.');
      if(!availableActions.contains('read_month_total')) return const AssistantResult.notUnderstood();
      return AssistantResult.command(AssistantCommand(name:'read_month_total',parameters:{'section':section,'year':month.$1,'month':month.$2}));
    }
    final amount=_amount(text), month=_month(text);
    if(RegExp(r'راتب|سلفة|سلفه|دفعة|دفعه').hasMatch(text)) {
      if(amount==null) return const AssistantResult.clarification('ما المبلغ؟ لن أفترض أي قيمة.');
      if(month==null) return const AssistantResult.clarification('ما الشهر المستحق؟ اكتب السنة والشهر مثل 2026-11.');
      final kind=text.contains('راتب')?'salary':RegExp(r'سلفة|سلفه').hasMatch(text)?'advance':'salaryPayment';
      return AssistantResult.command(AssistantCommand(name:'save_work_entry',parameters:{'kind':kind,'amountMinorUnits':amount,'year':month.$1,'month':month.$2}));
    }
    if(RegExp(r'تحويل|حوّل|حول').hasMatch(text) && RegExp(r'المنزل|للبيت').hasMatch(text)) {
      if(amount==null) return const AssistantResult.clarification('ما مبلغ التحويل؟ لن أخمّن.');
      if(!availableActions.contains('save_work_home_transfer')) return const AssistantResult.notUnderstood();
      return AssistantResult.command(AssistantCommand(name:'save_work_home_transfer',parameters:{'amountMinorUnits':amount}));
    }
    if(RegExp(r'مصروف|المنزل').hasMatch(text)) {
      if(amount==null) return const AssistantResult.clarification('ما مبلغ المصروف؟ لن أخمّن المبلغ.');
      final category=_capture(text,r'(?:تصنيف|فئة)\s+([\p{L}0-9_-]+)');
      if(category==null) return const AssistantResult.clarification('ما تصنيف المصروف؟ اذكره بعد كلمة تصنيف.');
      if(month==null) return const AssistantResult.clarification('ما الشهر المستحق للمصروف؟ اكتب السنة والشهر.');
      final date=_capture(text,r'(20\d{2}-\d{2}-\d{2})') ?? month.$1.toString()+'-'+month.$2.toString().padLeft(2,'0')+'-01';
      if(!availableActions.contains('save_home_expense')) return const AssistantResult.notUnderstood();
      return AssistantResult.command(AssistantCommand(name:'save_home_expense',parameters:{'amountMinorUnits':amount,'categoryId':category,'date':date,'year':month.$1,'month':month.$2}));
    }
    if(RegExp(r'دين|دَين').hasMatch(text)) {
      if(amount==null) return const AssistantResult.clarification('ما مبلغ الدين؟');
      final direction=text.contains('دائن')?'creditor':text.contains('مدين')?'debtor':null;
      if(direction==null) return const AssistantResult.clarification('هل الدين دائن (مبلغ لك) أم مدين (مبلغ عليك)؟');
      final person=_capture(text,r'(?:لدى|على|مع)\s+([\p{L}0-9_-]+)');
      if(person==null) return const AssistantResult.clarification('ما اسم الطرف المعني بالدين؟');
      if(month==null) return const AssistantResult.clarification('ما الشهر المستحق للدين؟');
      return AssistantResult.command(AssistantCommand(name:'save_debt',parameters:{'amountMinorUnits':amount,'direction':direction,'counterparty':person,'year':month.$1,'month':month.$2}));
    }
    return const AssistantResult.notUnderstood();
  }
  static int? _amount(String text) {
    final withoutMonth = text.replaceAll(
      RegExp(r'20\d{2}[-/](?:0?[1-9]|1[0-2])\b'),
      ' ',
    );
    final match = RegExp(
      r'(?<![A-Za-z\u0600-\u06FF])([0-9٠-٩۰-۹,٬]+)(?![A-Za-z\u0600-\u06FF])',
    ).firstMatch(withoutMonth);
    if (match != null) return _numbers.parseInteger(match.group(1)!);
    final words = RegExp(
      r'(?:ألف|الف|خمسمئة|خمسمائة|خمسمية|مئة|مائة|خمسة|خمس|واحد|واحدة|اثنين|ثلاثة|ثلاث|أربعة|اربعة|عشرة|عشرون|ثلاثون|أربعون|خمسون)(?:\s*و?\s*(?:ألف|الف|خمسمئة|خمسمائة|خمسمية|مئة|مائة|خمسة|خمس|واحد|واحدة|اثنين|ثلاثة|ثلاث|أربعة|اربعة))*',
    ).firstMatch(withoutMonth)?.group(0);
    return words == null ? null : _numbers.parseInteger(words);
  }
  static (int,int)? _month(String text) {
    final m=RegExp(r'\b(20\d{2})[-/](0?[1-9]|1[0-2])\b').firstMatch(text);
    return m==null?null:(int.parse(m.group(1)!),int.parse(m.group(2)!));
  }
  static String? _section(String text) {
    if(text.contains('العمل')) return 'work';
    if(RegExp(r'المنزل|البيت').hasMatch(text)) return 'home';
    if(RegExp(r'الديون|دين').hasMatch(text)) return 'debts';
    return null;
  }
  static String? _capture(String text,String pattern)=>RegExp(pattern,unicode:true).firstMatch(text)?.group(1);
}
