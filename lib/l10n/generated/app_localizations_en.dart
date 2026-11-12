// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Expenses';

  @override
  String get dashboard => 'Home';

  @override
  String get work => 'Work';

  @override
  String get homeSection => 'Household';

  @override
  String get debts => 'Debts';

  @override
  String get ai => 'AI Assistant';

  @override
  String get settings => 'Settings';

  @override
  String get darkTheme => 'Dark mode';

  @override
  String get language => 'Language';

  @override
  String get arabic => 'Arabic';

  @override
  String get english => 'English';

  @override
  String get noRecords => 'No records yet';

  @override
  String get amountMinorUnits => 'Amount in minor currency units';

  @override
  String get dueMonth => 'Due month';

  @override
  String get recordedAt => 'Recorded';

  @override
  String get salary => 'Salary';

  @override
  String get advance => 'Advance';

  @override
  String get payment => 'Payment';

  @override
  String get creditor => 'Creditor';

  @override
  String get debtor => 'Debtor';

  @override
  String get originalAmount => 'Original amount';

  @override
  String get outstandingAmount => 'Outstanding amount';

  @override
  String get counterparty => 'Counterparty';

  @override
  String get addTransfer => 'Add transfer to household';

  @override
  String get transferAmount => 'Transfer amount';

  @override
  String get transfers => 'Transfers to household';

  @override
  String get expenses => 'Expenses';

  @override
  String get entries => 'Entries';

  @override
  String get loading => 'Loading';

  @override
  String get dataError => 'Unable to load data';

  @override
  String get addExpense => 'Add expense';

  @override
  String get addEntry => 'Add work entry';

  @override
  String get addDebt => 'Add debt';

  @override
  String get editRecord => 'Edit record';

  @override
  String get deleteRecord => 'Delete record';

  @override
  String get confirmDelete => 'Are you sure you want to delete this record?';

  @override
  String get delete => 'Delete';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get category => 'Category';

  @override
  String get expenseDate => 'Expense date';

  @override
  String get note => 'Note';

  @override
  String get entryType => 'Entry type';

  @override
  String get debtDirection => 'Debt direction';

  @override
  String get invalidRecord =>
      'Check the entered values, amounts, and due month';

  @override
  String get monthlyOverview => 'Current month overview';

  @override
  String get workRecordsTotal => 'Total work entries';

  @override
  String get salaryTotal => 'Total salary';

  @override
  String get advancesTotal => 'Total advances';

  @override
  String get paymentsTotal => 'Total payments';

  @override
  String get homeExpensesTotal => 'Total household expenses';

  @override
  String get transfersTotal => 'Total transfers to household';

  @override
  String get creditorBalance => 'Total owed to you';

  @override
  String get debtorBalance => 'Total you owe';

  @override
  String get recordDebtPayment => 'Record payment';

  @override
  String get paymentHistory => 'Payment history';

  @override
  String get paidAt => 'Paid at';

  @override
  String get paymentAmount => 'Payment amount';

  @override
  String get settled => 'Fully settled';

  @override
  String get gemmaEngine => 'Use on-device Gemma';

  @override
  String get gemmaEngineDescription => 'Uses Gemma when the model is ready; otherwise the experimental assistant is used.';

  @override
  String get gemmaModelManagement => 'Gemma model management';

  @override
  String get gemmaModelDetails => 'Gemma 4 E2B · 2.59 GB · Requires at least 8 GB device memory. Wi-Fi is recommended.';

  @override
  String get gemmaNotDownloaded => 'Model not downloaded';

  @override
  String get gemmaDownloading => 'Downloading model';

  @override
  String get gemmaReady => 'Model ready';

  @override
  String get gemmaError => 'Model error';

  @override
  String get gemmaDownloadModel => 'Download model';

  @override
  String get gemmaResumeDownload => 'Resume / retry download';

  @override
  String get gemmaCancelDownload => 'Cancel download';

  @override
  String get gemmaDeleteModel => 'Delete model';

  @override
  String get gemmaDownloadResumeNote => 'A retry may restart from the beginning; the Hugging Face CDN does not guarantee byte-range resume.';

}
