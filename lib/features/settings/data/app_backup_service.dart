import 'dart:convert';

import 'package:expense_app/core/database/app_database.dart';

/// Exports and restores the user's finance records and app preferences.
/// PIN hashes and biometric settings are intentionally excluded.
class AppBackupService {
  static const String formatName = 'bye_pro_finance_backup';
  static const int formatVersion = 1;

  static const List<String> _tables = [
    'home_expenses',
    'work_entries',
    'work_home_transfers',
    'debts',
    'debt_payments',
    'home_bills',
    'home_bill_payments',
    'app_settings',
  ];

  static const List<String> _deleteOrder = [
    'home_bill_payments',
    'debt_payments',
    'home_bills',
    'debts',
    'home_expenses',
    'work_home_transfers',
    'work_entries',
    'app_settings',
  ];

  static const List<String> _restoreOrder = [
    'home_expenses',
    'work_entries',
    'work_home_transfers',
    'debts',
    'debt_payments',
    'home_bills',
    'home_bill_payments',
    'app_settings',
  ];

  Future<String> exportJson(AppDatabase database) async {
    final tables = <String, List<Map<String, Object?>>>{};

    for (final table in _tables) {
      final rows = await database.customSelect('SELECT * FROM "$table"').get();
      tables[table] = rows
          .map((row) => Map<String, Object?>.from(row.data))
          .toList(growable: false);
    }

    return jsonEncode({
      'format': formatName,
      'formatVersion': formatVersion,
      'databaseSchemaVersion': database.schemaVersion,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'tables': tables,
    });
  }

  Future<void> restoreJson(AppDatabase database, String contents) async {
    if (contents.isEmpty || contents.length > 50 * 1024 * 1024) {
      throw const FormatException('ملف النسخة الاحتياطية غير صالح أو حجمه كبير.');
    }

    final decoded = jsonDecode(contents);
    if (decoded is! Map<String, dynamic> ||
        decoded['format'] != formatName ||
        decoded['formatVersion'] != formatVersion ||
        decoded['databaseSchemaVersion'] != database.schemaVersion ||
        decoded['tables'] is! Map<String, dynamic>) {
      throw const FormatException(
        'ملف النسخة الاحتياطية غير متوافق مع إصدار التطبيق الحالي.',
      );
    }

    final rawTables = decoded['tables'] as Map<String, dynamic>;
    final restoredRows = <String, List<Map<String, Object?>>>{};
    var totalRows = 0;

    for (final table in _tables) {
      final rawRows = rawTables[table] ?? const <dynamic>[];
      if (rawRows is! List) {
        throw FormatException('بيانات الجدول $table غير صالحة.');
      }

      totalRows += rawRows.length;
      if (totalRows > 100000) {
        throw const FormatException('ملف النسخة الاحتياطية يحتوي على بيانات كثيرة جداً.');
      }

      final schemaRows =
          await database.customSelect('PRAGMA table_info("$table")').get();
      final allowedColumns = schemaRows
          .map((row) => row.data['name'])
          .whereType<String>()
          .toSet();

      final parsedRows = <Map<String, Object?>>[];
      for (final item in rawRows) {
        if (item is! Map) {
          throw FormatException('يوجد سجل غير صالح في الجدول $table.');
        }
        final row = Map<String, Object?>.from(item);
        if (row.isEmpty ||
            row.keys.any((column) => !allowedColumns.contains(column))) {
          throw FormatException('توجد أعمدة غير معروفة في الجدول $table.');
        }
        parsedRows.add(row);
      }
      restoredRows[table] = parsedRows;
    }

    // A single transaction ensures a failed restore keeps the original data.
    await database.transaction(() async {
      for (final table in _deleteOrder) {
        await database.customStatement('DELETE FROM "$table"');
      }

      for (final table in _restoreOrder) {
        for (final row in restoredRows[table] ?? const []) {
          final columns = row.keys.toList(growable: false);
          final columnSql = columns.map((column) => '"$column"').join(', ');
          final placeholders = List.filled(columns.length, '?').join(', ');
          final values = columns.map((column) => row[column]).toList();

          await database.customStatement(
            'INSERT INTO "$table" ($columnSql) VALUES ($placeholders)',
            values,
          );
        }
      }
    });
  }
}
