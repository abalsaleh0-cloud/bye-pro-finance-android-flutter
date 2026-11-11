// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'المصروفات';

  @override
  String get dashboard => 'الرئيسية';

  @override
  String get work => 'العمل';

  @override
  String get homeSection => 'المنزل';

  @override
  String get debts => 'الديون';

  @override
  String get ai => 'الذكاء الاصطناعي';

  @override
  String get settings => 'الإعدادات';

  @override
  String get darkTheme => 'الوضع الداكن';

  @override
  String get language => 'اللغة';

  @override
  String get arabic => 'العربية';

  @override
  String get english => 'الإنجليزية';

  @override
  String get noRecords => 'لا توجد سجلات بعد';

  @override
  String get amountMinorUnits => 'المبلغ بأصغر وحدة نقدية';

  @override
  String get dueMonth => 'الشهر المستحق';

  @override
  String get recordedAt => 'تاريخ التسجيل';

  @override
  String get salary => 'راتب';

  @override
  String get advance => 'سلفة';

  @override
  String get payment => 'دفعة';

  @override
  String get creditor => 'دائن';

  @override
  String get debtor => 'مدين';

  @override
  String get originalAmount => 'المبلغ الأصلي';

  @override
  String get outstandingAmount => 'المبلغ المتبقي';

  @override
  String get counterparty => 'الطرف المعني';

  @override
  String get transfers => 'التحويلات إلى المنزل';

  @override
  String get expenses => 'المصروفات';

  @override
  String get entries => 'السجلات';

  @override
  String get loading => 'جارٍ التحميل';

  @override
  String get dataError => 'تعذر تحميل البيانات';

  @override
  String get addExpense => 'إضافة مصروف';

  @override
  String get addEntry => 'إضافة سجل عمل';

  @override
  String get addDebt => 'إضافة دين';

  @override
  String get editRecord => 'تعديل السجل';

  @override
  String get deleteRecord => 'حذف السجل';

  @override
  String get confirmDelete => 'هل أنت متأكد من حذف هذا السجل؟';

  @override
  String get delete => 'حذف';

  @override
  String get save => 'حفظ';

  @override
  String get cancel => 'إلغاء';

  @override
  String get category => 'التصنيف';

  @override
  String get expenseDate => 'تاريخ المصروف';

  @override
  String get note => 'ملاحظة';

  @override
  String get entryType => 'نوع السجل';

  @override
  String get debtDirection => 'نوع الدين';

  @override
  String get invalidRecord =>
      'تحقق من البيانات المدخلة والمبالغ والشهر المستحق';
}
