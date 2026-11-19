import 'package:expense_app/core/providers/app_settings_provider.dart';
import 'package:expense_app/core/theme/app_design_tokens.dart';
import 'package:expense_app/features/ai/data/gemma_model_manager.dart';
import 'package:expense_app/l10n/generated/app_localizations.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class GemmaModelSettingsSection extends ConsumerWidget {
  const GemmaModelSettingsSection({super.key});

  Future<void> _confirmDownload(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations strings,
  ) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.gemmaWifiTitle),
        content: Text(strings.gemmaWifiWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(strings.gemmaDownloadModel),
          ),
        ],
      ),
    );
    if (accepted == true) {
      final notifications = FlutterLocalNotificationsPlugin();
      final androidNotifications = notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final notificationPermission =
          await androidNotifications?.requestNotificationsPermission();
      if (notificationPermission == false && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.gemmaNotificationPermissionDenied)),
        );
      }
      await ref.read(gemmaModelManagerProvider.notifier).download();
      if (ref.read(gemmaModelManagerProvider).status ==
          GemmaModelStatus.ready) {
        // Download acceptance is an explicit opt-in to use the on-device model.
        await ref.read(appSettingsProvider.notifier).setGemmaEnabled(true);
      }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations strings,
  ) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.gemmaDeleteModel),
        content: Text(strings.gemmaDeleteModelWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(strings.delete),
          ),
        ],
      ),
    );
    if (accepted == true) {
      await ref.read(gemmaModelManagerProvider.notifier).deleteModel();
      await ref.read(appSettingsProvider.notifier).setGemmaEnabled(false);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppLocalizations.of(context)!;
    final model = ref.watch(gemmaModelManagerProvider);
    final manager = ref.read(gemmaModelManagerProvider.notifier);
    final tokens = AppDesignTokens.of(context);
    final status = switch (model.status) {
      GemmaModelStatus.notDownloaded => strings.gemmaNotDownloaded,
      GemmaModelStatus.downloading => strings.gemmaDownloading,
      GemmaModelStatus.ready => strings.gemmaReady,
      GemmaModelStatus.error => strings.gemmaError,
    };

    return Card(
      child: Padding(
        padding: EdgeInsets.all(tokens.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.gemmaModelManagement,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: tokens.sectionSpacing / 3),
            Text(strings.gemmaModelDetails),
            SizedBox(height: tokens.sectionSpacing / 2),
            Text(status),
            if (model.status == GemmaModelStatus.ready &&
                model.installed) ...[
              SizedBox(height: tokens.sectionSpacing / 2),
              Divider(color: Theme.of(context).colorScheme.outlineVariant),
              Text(
                strings.gemmaInferenceTitle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              SizedBox(height: tokens.sectionSpacing / 3),
              Row(
                children: [
                  Icon(
                    switch (model.inferenceStatus) {
                      GemmaInferenceStatus.notTested => Icons.help_outline_rounded,
                      GemmaInferenceStatus.testing => Icons.hourglass_top_rounded,
                      GemmaInferenceStatus.succeeded => Icons.check_circle_outline_rounded,
                      GemmaInferenceStatus.failed => Icons.error_outline_rounded,
                    },
                    color: switch (model.inferenceStatus) {
                      GemmaInferenceStatus.succeeded =>
                        Theme.of(context).colorScheme.primary,
                      GemmaInferenceStatus.failed =>
                        Theme.of(context).colorScheme.error,
                      _ => Theme.of(context).colorScheme.onSurfaceVariant,
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      switch (model.inferenceStatus) {
                        GemmaInferenceStatus.notTested =>
                          strings.gemmaInferenceNotTested,
                        GemmaInferenceStatus.testing =>
                          strings.gemmaInferenceTesting,
                        GemmaInferenceStatus.succeeded =>
                          strings.gemmaInferenceSucceeded,
                        GemmaInferenceStatus.failed =>
                          strings.gemmaInferenceFailed,
                      },
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
              if (model.inferenceMessage != null) ...[
                SizedBox(height: tokens.sectionSpacing / 3),
                Text(model.inferenceMessage!),
              ],
              if (model.inferenceAt != null) ...[
                SizedBox(height: tokens.sectionSpacing / 4),
                Text(
                  '${MaterialLocalizations.of(context).formatMediumDate(model.inferenceAt!)} · '
                  '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(model.inferenceAt!))}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
              SizedBox(height: tokens.sectionSpacing / 2),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: model.inferenceStatus == GemmaInferenceStatus.testing
                      ? null
                      : () => manager.testInference(),
                  icon: model.inferenceStatus == GemmaInferenceStatus.testing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_circle_outline_rounded),
                  label: Text(strings.gemmaInferenceRunTest),
                ),
              ),
              Text(
                strings.gemmaInferenceExplanation,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (model.status == GemmaModelStatus.downloading) ...[
              SizedBox(height: tokens.sectionSpacing / 2),
              LinearProgressIndicator(value: model.progress / 100),
              Text('${model.progress.toStringAsFixed(0)}%'),
              Text(
                '~${GemmaModelManager.estimatedDownloadedMegabytes(model.progress)} MB'
                ' / ${GemmaModelManager.expectedDownloadMegabytes} MB',
              ),
            ],
            if (model.error != null) Text(model.error!),
            SizedBox(height: tokens.sectionSpacing / 2),
            Wrap(
              spacing: tokens.pageHorizontalPadding / 2,
              runSpacing: tokens.pageVerticalPadding / 2,
              children: [
                if (model.status == GemmaModelStatus.downloading)
                  OutlinedButton(
                    onPressed: manager.cancelDownload,
                    child: Text(strings.gemmaCancelDownload),
                  )
                else if (model.status == GemmaModelStatus.ready)
                  OutlinedButton(
                    onPressed: () => _confirmDelete(context, ref, strings),
                    child: Text(strings.gemmaDeleteModel),
                  )
                else if (model.status == GemmaModelStatus.error &&
                    model.installed)
                  OutlinedButton(
                    onPressed: manager.refresh,
                    child: Text(strings.gemmaRecheckModel),
                  )
                else
                  FilledButton(
                    onPressed: () => _confirmDownload(context, ref, strings),
                    child: Text(strings.gemmaDownloadModel),
                  ),
              ],
            ),
            SizedBox(height: tokens.sectionSpacing / 3),
            Text(
              strings.gemmaDownloadResumeNote,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
