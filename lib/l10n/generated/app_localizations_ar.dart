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
  String get addTransfer => 'إضافة تحويل إلى المنزل';

  @override
  String get transferAmount => 'مبلغ التحويل';

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

  @override
  String get monthlyOverview => 'ملخص الشهر الحالي';

  @override
  String get workRecordsTotal => 'إجمالي سجلات العمل';

  @override
  String get salaryTotal => 'إجمالي الرواتب';

  @override
  String get advancesTotal => 'إجمالي السلف';

  @override
  String get paymentsTotal => 'إجمالي الدفعات';

  @override
  String get homeExpensesTotal => 'إجمالي مصروفات المنزل';

  @override
  String get transfersTotal => 'إجمالي التحويلات إلى المنزل';

  @override
  String get creditorBalance => 'إجمالي المبالغ المستحقة لك';

  @override
  String get debtorBalance => 'إجمالي المبالغ المستحقة عليك';

  @override
  String get recordDebtPayment => 'تسجيل دفعة';

  @override
  String get paymentHistory => 'سجل الدفعات';

  @override
  String get paidAt => 'تاريخ الدفع';

  @override
  String get paymentAmount => 'مبلغ الدفعة';

  @override
  String get settled => 'تمت التسوية بالكامل';

  @override
  String get gemmaEngine => 'استخدام Gemma على الجهاز';

  @override
  String get gemmaEngineDescription => 'يستخدم Gemma عند جاهزية النموذج، وإلا يعمل المساعد التجريبي.';

  @override
  String get gemmaModelManagement => 'إدارة نموذج Gemma';

  @override
  String get gemmaModelDetails => 'Gemma 4 E2B · ملف النموذج 2.59 GB · يُخزَّن ضمن بيانات التطبيق وليس داخل ملف APK. يتطلب ذاكرة جهاز 8 GB على الأقل.';

  @override
  String get gemmaNotDownloaded => 'النموذج غير منزّل';

  @override
  String get gemmaDownloading => 'جارٍ تنزيل النموذج';

  @override
  String get gemmaReady => 'النموذج جاهز';

  @override
  String get gemmaError => 'حدث خطأ في النموذج';

  @override
  String get gemmaDownloadModel => 'تنزيل النموذج';

  @override
  String get gemmaResumeDownload => 'إعادة المحاولة';

  @override
  String get gemmaCancelDownload => 'إلغاء التنزيل';

  @override
  String get gemmaDeleteModel => 'حذف النموذج';

  @override
  String get gemmaDownloadResumeNote => 'يعمل التنزيل في الخلفية مع إشعار. إذا انقطع، فقد تبدأ إعادة المحاولة من البداية؛ خادم Hugging Face لا يدعم الاستكمال الجزئي.';

  @override
  String get gemmaWifiTitle => 'تنبيه التنزيل';

  @override
  String get gemmaWifiWarning => 'حجم ملف النموذج نحو 2.59 GB. استخدم Wi-Fi ومساحة تخزين كافية. سيعمل التنزيل في الخلفية مع إشعار؛ اسمح بإذن الإشعارات عندما يطلبه الهاتف، ويمكنك بعدها إطفاء الشاشة. إذا انقطع التنزيل فقد يبدأ من البداية لأن خادم Hugging Face لا يدعم استكمال الجزء المتبقي.';


}
