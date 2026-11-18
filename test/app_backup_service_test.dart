import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:expense_app/core/database/app_database.dart';
import 'package:expense_app/features/settings/data/app_backup_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late AppBackupService backupService;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    backupService = AppBackupService();
    await database.customSelect('SELECT 1').get();
  });

  tearDown(() async {
    await database.close();
  });

  test('backup restores work entries and app preferences', () async {
    await database.customStatement(
      'INSERT INTO work_entries '
      '(id, kind, amount_minor_units, due_year, due_month, recorded_at_epoch_millis, note) '
      'VALUES (?, ?, ?, ?, ?, ?, ?)',
      ['work-1', 'salary', 125000, 2026, 11, 1794960000000, 'test salary'],
    );
    await database.writeSetting('theme_mode', 'dark');

    final backup = await backupService.exportJson(database);

    await database.customStatement('DELETE FROM work_entries');
    await database.writeSetting('theme_mode', 'light');

    await backupService.restoreJson(database, backup);

    final workRows = await database
        .customSelect(
          'SELECT * FROM work_entries WHERE id = ?',
          variables: [const Variable<String>('work-1')],
        )
        .get();
    expect(workRows, hasLength(1));
    expect(workRows.single.read<int>('amount_minor_units'), 125000);
    expect(await database.readSetting('theme_mode'), 'dark');
  });

  test('invalid backup is rejected before replacing existing data', () async {
    await database.customStatement(
      'INSERT INTO work_entries '
      '(id, kind, amount_minor_units, due_year, due_month, recorded_at_epoch_millis, note) '
      'VALUES (?, ?, ?, ?, ?, ?, ?)',
      ['keep-me', 'salary', 50000, 2026, 11, 1794960000000, null],
    );

    await expectLater(
      backupService.restoreJson(database, '{"format":"wrong"}'),
      throwsA(isA<FormatException>()),
    );

    final rows = await database.customSelect('SELECT id FROM work_entries').get();
    expect(rows.map((row) => row.read<String>('id')), ['keep-me']);
  });
}
