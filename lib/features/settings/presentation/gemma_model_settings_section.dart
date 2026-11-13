import 'package:expense_app/features/ai/data/gemma_model_manager.dart';
import 'package:expense_app/l10n/generated/app_localizations.dart';
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
      await ref.read(gemmaModelManagerProvider.notifier).download();
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
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppLocalizations.of(context)!;
    final model = ref.watch(gemmaModelManagerProvider);
    final manager = ref.read(gemmaModelManagerProvider.notifier);
    final status = switch (model.status) {
      GemmaModelStatus.notDownloaded => strings.gemmaNotDownloaded,
      GemmaModelStatus.downloading => strings.gemmaDownloading,
      GemmaModelStatus.ready => strings.gemmaReady,
      GemmaModelStatus.error => strings.gemmaError,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.gemmaModelManagement,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(strings.gemmaModelDetails),
            const SizedBox(height: 8),
            Text(status),
            if (model.status == GemmaModelStatus.downloading) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: model.progress / 100),
              Text('${model.progress.toStringAsFixed(0)}%'),
            ],
            if (model.error != null) Text(model.error!),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
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
                else ...[
                  FilledButton(
                    onPressed: () => _confirmDownload(context, ref, strings),
                    child: Text(
                      model.cancelled || model.status == GemmaModelStatus.error
                          ? strings.gemmaResumeDownload
                          : strings.gemmaDownloadModel,
                    ),
                  ),
                  if (model.status == GemmaModelStatus.error)
                    OutlinedButton(
                      onPressed: () => _confirmDelete(context, ref, strings),
                      child: Text(strings.gemmaDeleteModel),
                    ),
                ],
              ],
            ),
            const SizedBox(height: 4),
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
