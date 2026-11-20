import 'dart:convert';
import 'dart:typed_data';

import 'package:expense_app/core/database/database_providers.dart';
import 'package:expense_app/core/providers/app_settings_provider.dart';
import 'package:expense_app/features/settings/data/app_backup_service.dart';
import 'package:expense_app/features/ai/presentation/ai_chat_state.dart';
import 'package:expense_app/l10n/generated/app_localizations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class BackupRestoreSettingsSection extends ConsumerStatefulWidget {
  const BackupRestoreSettingsSection({super.key});

  @override
  ConsumerState<BackupRestoreSettingsSection> createState() =>
      _BackupRestoreSettingsSectionState();
}

class _BackupRestoreSettingsSectionState
    extends ConsumerState<BackupRestoreSettingsSection> {
  final AppBackupService _backupService = AppBackupService();
  bool _busy = false;

  String _text(String ar, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : ar;

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  Future<void> _createBackup() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final contents =
          await _backupService.exportJson(ref.read(appDatabaseProvider));
      final bytes = Uint8List.fromList(utf8.encode(contents));
      final uri = await FilePicker.saveFile(
        dialogTitle: _text('حفظ النسخة الاحتياطية', 'Save backup'),
        fileName:
            'bye-pro-finance-backup-${DateTime.now().toIso8601String().replaceAll(':', '-')}.json',
        bytes: bytes,
      );
      if (uri != null) {
        _showMessage(_text(
          'تم إنشاء النسخة الاحتياطية وحفظها.',
          'Backup created and saved.',
        ));
      }
    } catch (_) {
      _showMessage(
        _text('تعذر إنشاء النسخة الاحتياطية.', 'Could not create the backup.'),
        error: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreBackup() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty || bytes.length > 50 * 1024 * 1024) {
        throw const FormatException('ملف النسخة الاحتياطية غير صالح أو حجمه كبير.');
      }
      final contents = utf8.decode(bytes, allowMalformed: false);

      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(_text('استعادة النسخة الاحتياطية؟', 'Restore backup?')),
          content: Text(_text(
            'سيتم استبدال البيانات المالية الحالية بالبيانات الموجودة في النسخة الاحتياطية. لا يمكن التراجع عن هذه العملية.',
            'Current financial data will be replaced with the backup data. This action cannot be undone.',
          )),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(_text('إلغاء', 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(_text('استعادة', 'Restore')),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;

      // Finish pending chat writes before replacing app_settings from backup.
      await ref.read(aiChatWorkspaceProvider.notifier).flush();
      await _backupService.restoreJson(
        ref.read(appDatabaseProvider),
        contents,
      );
      ref.invalidate(appSettingsProvider);
      ref.invalidate(homeExpenseCategoriesProvider);
      ref.invalidate(aiChatWorkspaceProvider);
      ref.invalidate(homeExpensesProvider);
      ref.invalidate(workEntriesProvider);
      ref.invalidate(workTransfersProvider);
      ref.invalidate(debtsProvider);
      ref.invalidate(homeBillsProvider);
      ref.invalidate(allHomeBillPaymentsProvider);
      ref.invalidate(allDebtPaymentsProvider);

      _showMessage(_text(
        'تمت استعادة البيانات بنجاح.',
        'Data restored successfully.',
      ));
    } catch (_) {
      _showMessage(
        _text(
          'تعذرت استعادة النسخة. تأكد من أن الملف صادر من هذا التطبيق.',
          'Restore failed. Make sure the file was created by this app.',
        ),
        error: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isEnglish = Localizations.localeOf(context).languageCode == 'en';
    final strings = AppLocalizations.of(context)!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.backup_outlined, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _text('النسخ الاحتياطي والاستعادة', 'Backup and restore'),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              strings.backupContentsNotice,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _busy ? null : _createBackup,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_alt_rounded),
              label: Text(isEnglish ? 'Create backup' : 'إنشاء نسخة احتياطية'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _restoreBackup,
              icon: const Icon(Icons.restore_rounded),
              label: Text(isEnglish ? 'Restore backup' : 'استعادة نسخة احتياطية'),
            ),
          ],
        ),
      ),
    );
  }
}
