// ignore_for_file: curly_braces_in_flow_control_structures, prefer_interpolation_to_compose_strings

import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:expense_app/features/ai/data/android_assistant_voice_service.dart';

import 'package:expense_app/features/ai/domain/wav_audio_validator.dart';

import 'package:expense_app/core/database/database_providers.dart';
import 'package:expense_app/core/providers/app_settings_provider.dart';
import 'package:expense_app/core/theme/app_design_tokens.dart';
import 'package:expense_app/core/widgets/chat_message_bubble.dart';
import 'package:expense_app/core/time/selected_month_provider.dart';
import 'package:expense_app/core/time/calendar_date.dart';
import 'package:expense_app/core/widgets/financial_record_card.dart';
import 'package:expense_app/features/ai/domain/action_registry.dart';
import 'package:expense_app/features/ai/domain/assistant_confirmation.dart';
import 'package:expense_app/features/ai/domain/assistant_engine.dart';
import 'package:expense_app/features/ai/domain/assistant_engine_selector.dart';
import 'package:expense_app/features/ai/domain/gemma_assistant_engine.dart';
import 'package:expense_app/features/ai/data/gemma_model_manager.dart';
import 'package:expense_app/features/ai/presentation/ai_chat_state.dart';
import 'package:expense_app/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

enum _AssistantAttachmentChoice { camera, gallery, files }

final assistantEngineProvider = Provider<AssistantEngine>((ref) {
  final settings = ref.watch(appSettingsProvider);
  const localEngine = LocalRuleAssistantEngine();

  // Keep Gemma fully opt-in. The local engine remains active if disabled
  // or if the verified model is not ready.
  if (!settings.useGemma) return localEngine;

  final modelState = ref.watch(gemmaModelManagerProvider);
  final manager = ref.read(gemmaModelManagerProvider.notifier);
  return selectAssistantEngine(
    gemmaEnabled: true,
    gemmaReady: modelState.status == GemmaModelStatus.ready,
    gemmaEngine: GemmaAssistantEngine(manager),
    localEngine: localEngine,
  );
});

class AiScreen extends ConsumerStatefulWidget {
  const AiScreen({super.key});
  @override
  ConsumerState<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends ConsumerState<AiScreen> {
  final _input = TextEditingController();
  final _scrollController = ScrollController();
  final AssistantConfirmation _confirmation = AssistantConfirmation();
  UndoOperation? _undo;
  String? _lastUndoAction;
  bool _busy = false;
  bool _preparing = false;
  final ImagePicker _imagePicker = ImagePicker();
  final AndroidAssistantVoiceService _voiceService = const AndroidAssistantVoiceService();
  bool _recognizing = false;
  Uint8List? _attachmentBytes;
  bool _attachmentIsImage = false;
  String? _attachmentName;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _input.dispose();
    _scrollController.dispose();
    if (_recognizing) {
      unawaited(_voiceService.cancelArabicSpeechRecognition());
    }
    super.dispose();
  }

  ActionRegistry _registry() => ActionRegistry(
    work: ref.read(workRepositoryProvider),
    home: ref.read(homeExpenseRepositoryProvider),
    bills: ref.read(homeBillRepositoryProvider),
    debts: ref.read(debtRepositoryProvider),
    categories: ref.read(homeExpenseCategoryRepositoryProvider),
    selectedMonth: ref.read(selectedMonthProvider),
  );

  void _refreshAfterAssistantAction(String? actionName) {
    if (actionName == null) return;
    if (actionName == 'save_home_category' ||
        actionName == 'delete_home_category') {
      ref.invalidate(homeExpenseCategoriesProvider);
    }
    if (actionName == 'save_home_bill' ||
        actionName == 'delete_home_bill' ||
        actionName == 'record_home_bill_payment') {
      // These are FutureProviders, not database streams. Refresh every
      // bill-related projection after an assistant write so users see it
      // immediately without leaving or restarting the app.
      ref.invalidate(homeBillsProvider);
      ref.invalidate(homeBillPaymentsForMonthProvider);
      ref.invalidate(homeBillOutstandingAsOfMonthProvider);
      ref.invalidate(allHomeBillPaymentsProvider);
    }
  }

  Future<void> _chooseAttachment() async {
    if (_busy || _recognizing || _preparing) return;
    final strings = AppLocalizations.of(context)!;
    final choice = await showModalBottomSheet<_AssistantAttachmentChoice>(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDesignTokens.of(context).dialogRadius),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(strings.aiCamera),
              onTap: () => Navigator.pop(
                sheetContext,
                _AssistantAttachmentChoice.camera,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(strings.aiGallery),
              onTap: () => Navigator.pop(
                sheetContext,
                _AssistantAttachmentChoice.gallery,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(strings.aiFiles),
              onTap: () => Navigator.pop(
                sheetContext,
                _AssistantAttachmentChoice.files,
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case _AssistantAttachmentChoice.camera:
        await _pickImage(ImageSource.camera);
        break;
      case _AssistantAttachmentChoice.gallery:
        await _pickImage(ImageSource.gallery);
        break;
      case _AssistantAttachmentChoice.files:
        await _pickDocumentOrMedia();
        break;
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (file == null || !mounted) return;
      await _storeAttachment(
        bytes: await file.readAsBytes(),
        name: file.name,
        image: true,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Bad state: ', '')),
          ),
        );
      }
    }
  }

  Future<void> _pickDocumentOrMedia() async {
    final strings = AppLocalizations.of(context)!;
    if (_busy || _recognizing || _preparing) return;
    try {
      final file = await FilePicker.pickFile(type: FileType.any);
      if (file == null) return;
      final extension = file.name.split('.').last.toLowerCase();
      const imageExtensions = {
        'jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'heic', 'heif',
      };
      final image = imageExtensions.contains(extension);
      if (!image && extension != 'wav') {
        throw StateError(strings.aiUnsupportedAttachment);
      }
      final length = file.lengthSync() ?? await file.length();
      final limit = image ? 12 * 1024 * 1024 : 20 * 1024 * 1024;
      if (length == null || length <= 0) {
        throw StateError(strings.aiReadFileFailed);
      }
      if (length > limit) {
        throw StateError(
          image ? strings.aiImageTooLarge : strings.aiAudioTooLarge,
        );
      }
      await _storeAttachment(
        bytes: await file.readAsBytes(),
        name: file.name,
        image: image,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Bad state: ', '')),
          ),
        );
      }
    }
  }

  Future<void> _storeAttachment({
    required Uint8List bytes,
    required String name,
    required bool image,
  }) async {
    final strings = AppLocalizations.of(context)!;
    final limit = image ? 12 * 1024 * 1024 : 20 * 1024 * 1024;
    if (bytes.isEmpty) throw StateError(strings.aiReadFileFailed);
    if (bytes.length > limit) {
      throw StateError(
        image ? strings.aiImageTooLarge : strings.aiAudioTooLarge,
      );
    }
    if (!image && !_isValidWav(bytes)) {
      throw StateError(strings.aiInvalidWav);
    }
    if (!mounted) return;
    setState(() {
      _attachmentBytes = bytes;
      _attachmentIsImage = image;
      _attachmentName = name;
    });
  }

  bool _isValidWav(Uint8List bytes) => isValidGemmaWavAudio(bytes);

  void _scheduleScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final position = _scrollController.position;
      if (!position.hasContentDimensions) return;
      _scrollController
          .animateTo(
            position.maxScrollExtent,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
          )
          .catchError((Object _) {});
    });
  }

  void _addAssistantMessage(
    String text, {
    bool includeInModelContext = false,
    String? assistantSource,
  }) {
    ref.read(aiChatWorkspaceProvider.notifier).add(
      AiChatMessage(
        text,
        includeInModelContext: includeInModelContext,
        assistantSource: assistantSource,
      ),
    );
    _scheduleScrollToBottom();
  }

  void _startNewConversation() {
    if (_busy || _recognizing) return;
    ref.read(aiChatWorkspaceProvider.notifier).newConversation();
    setState(() {
      _confirmation.cancel();
      _undo = null;
      _attachmentBytes = null;
      _attachmentName = null;
      _input.clear();
    });
    _scheduleScrollToBottom();
  }

  Future<void> _showConversationHistory() async {
    if (_busy) return;
    final strings = AppLocalizations.of(context)!;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.72,
        child: Consumer(
          builder: (context, sheetRef, _) {
            final workspace = sheetRef.watch(aiChatWorkspaceProvider);
            final conversations = workspace.conversations;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            strings.aiConversationHistory,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          tooltip: strings.cancel,
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (conversations.isEmpty)
                      Expanded(
                        child: Center(
                          child: Text(
                            strings.aiNoConversations,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.separated(
                          itemCount: conversations.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final conversation = conversations[index];
                            final isActive =
                                conversation.id == workspace.activeConversationId;
                            final date = toAsciiDigits(
                              MaterialLocalizations.of(context)
                                  .formatMediumDate(conversation.updatedAt),
                            );
                            return ListTile(
                              selected: isActive,
                              leading: Icon(
                                isActive
                                    ? Icons.chat_bubble_rounded
                                    : Icons.chat_bubble_outline_rounded,
                              ),
                              title: Text(
                                conversation.title.isEmpty
                                    ? strings.aiNewConversation
                                    : conversation.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '$date · ${conversation.messages.length} ${strings.aiMessagesCount}',
                              ),
                              trailing: IconButton(
                                tooltip: strings.aiDeleteConversation,
                                onPressed: () async {
                                  final accepted = await showDialog<bool>(
                                    context: context,
                                    builder: (dialogContext) => AlertDialog(
                                      title: Text(strings.aiDeleteConversation),
                                      content: Text(
                                        strings.aiDeleteConversationWarning,
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(
                                            dialogContext,
                                            false,
                                          ),
                                          child: Text(strings.cancel),
                                        ),
                                        FilledButton(
                                          onPressed: () => Navigator.pop(
                                            dialogContext,
                                            true,
                                          ),
                                          child: Text(strings.delete),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (accepted == true) {
                                    final wasActive = isActive;
                                    sheetRef
                                        .read(aiChatWorkspaceProvider.notifier)
                                        .deleteConversation(conversation.id);
                                    if (wasActive && mounted) {
                                      setState(() {
                                        _confirmation.cancel();
                                        _undo = null;
                                        _attachmentBytes = null;
                                        _attachmentName = null;
                                        _input.clear();
                                      });
                                      _scheduleScrollToBottom();
                                    }
                                  }
                                },
                                icon: const Icon(Icons.delete_outline_rounded),
                              ),
                              onTap: () {
                                sheetRef
                                    .read(aiChatWorkspaceProvider.notifier)
                                    .selectConversation(conversation.id);
                                Navigator.pop(sheetContext);
                                if (mounted) {
                                  setState(() {
                                    _confirmation.cancel();
                                    _undo = null;
                                    _attachmentBytes = null;
                                    _attachmentName = null;
                                    _input.clear();
                                  });
                                  _scheduleScrollToBottom();
                                }
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _conversationToolbar(
    AiChatWorkspaceState workspace,
    AppLocalizations strings,
    AppDesignTokens tokens,
  ) {
    final active = workspace.activeConversation;
    final title = active == null || active.title.isEmpty
        ? strings.aiNewConversation
        : active.title;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        tokens.pageHorizontalPadding,
        6,
        tokens.pageHorizontalPadding,
        8,
      ),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 6, 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(tokens.cardRadius),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            const Icon(Icons.forum_outlined),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${active?.messages.length ?? 0} ${strings.aiMessagesCount}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: strings.aiConversationHistory,
              onPressed: _busy ? null : _showConversationHistory,
              icon: const Icon(Icons.history_rounded),
            ),
            IconButton(
              tooltip: strings.aiNewConversation,
              onPressed: _busy ? null : _startNewConversation,
              icon: const Icon(Icons.add_comment_outlined),
            ),
          ],
        ),
      ),
    );
  }

  Widget _assistantSourceBadge(
    String source,
    AppLocalizations strings,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isGemma = source == 'gemma';
    final label = switch (source) {
      'gemma' => strings.aiSourceGemma,
      'localAfterGemma' => strings.aiSourceLocalFallback,
      _ => strings.aiSourceLocal,
    };

    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4, top: 6, bottom: 2),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isGemma
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isGemma ? Icons.memory_rounded : Icons.smart_toy_outlined,
                size: 14,
                color: isGemma
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isGemma
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copyMessage(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.aiCopied)),
    );
  }

  Future<void> _recognizeArabicSpeech() async {
    if (_busy || _recognizing || _preparing) return;
    setState(() => _recognizing = true);
    final strings = AppLocalizations.of(context)!;
    try {
      final transcript = await _voiceService.recognizeArabicSpeech();
      if (!mounted) return;
      if (transcript.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.aiSpeechNoMatch)),
        );
        return;
      }
      _input.value = TextEditingValue(
        text: transcript,
        selection: TextSelection.collapsed(offset: transcript.length),
      );
    } on PlatformException catch (error) {
      if (!mounted || error.code == 'speech_cancelled') return;
      final message = switch (error.code) {
        'offline_speech_unavailable' => strings.aiVoiceOfflineUnavailable,
        'arabic_language_unavailable' => strings.aiArabicLanguageUnavailable,
        'permission_denied' => strings.aiMicrophonePermission,
        'speech_no_match' => strings.aiSpeechNoMatch,
        _ => strings.aiSpeechFailed,
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.aiSpeechFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _recognizing = false);
    }
  }



  void _removeAttachment() {
    setState(() {
      _attachmentBytes = null;
      _attachmentName = null;
    });
  }

  String _dashboardSummaryMessage(
    AssistantDashboardSummary summary,
    AppLocalizations strings,
  ) {
    final overview = summary.overview;
    return [
      '${strings.assistantMonth}: ${summary.month}',
      strings.amountMinorUnits,
      '',
      strings.work,
      '${strings.salaryTotal}: ${overview.salary.minorUnits}',
      '${strings.advancesTotal}: ${overview.advances.minorUnits}',
      '${strings.paymentsTotal}: ${overview.payments.minorUnits}',
      '${strings.currentSalaryOutstanding}: ${overview.currentSalaryOutstandingMinorUnits}',
      '${strings.salaryPaymentsApplied}: ${overview.salaryPaymentsApplied.minorUnits}',
      '${strings.workRemaining}: ${overview.workRemainingMinorUnits}',
      '${strings.totalWorkOutstanding}: ${overview.totalWorkOutstandingMinorUnits}',
      '',
      strings.homeSection,
      '${strings.homeExpensesTotal}: ${overview.homeExpenses.minorUnits}',
      '${strings.transfersTotal}: ${overview.transfers.minorUnits}',
      '${strings.billPaid}: ${summary.homeBillPaymentsMinorUnits}',
      '${strings.totalBillsOutstanding}: ${summary.outstandingBillsAtMonthEndMinorUnits}',
      '${strings.homeAvailableBalance}: ${summary.homeBalanceMinorUnits}',
      '',
      strings.debts,
      strings.debtBalancesCurrentNote,
      '${strings.creditorBalance}: ${overview.creditorBalance.minorUnits}',
      '${strings.debtorBalance}: ${overview.debtorBalance.minorUnits}',
    ].join('\n');
  }

  String _sectionLabel(String section, AppLocalizations strings) =>
      switch (section) {
        'dashboard' => strings.dashboard,
        'work' => strings.work,
        'home' => strings.homeSection,
        'debts' => strings.debts,
        'ai' => strings.ai,
        'settings' => strings.settings,
        _ => section,
      };

  String _assistantActionErrorMessage(String code, AppLocalizations strings) =>
      switch (code) {
        'debt_has_payments' => strings.assistantDebtDeleteHasPayments,
        'bill_has_payments' => strings.assistantBillDeleteHasPayments,
        'record_not_found' || 'bill_not_found' || 'debt_not_found' =>
          strings.assistantRecordNotFound,
        'record_ambiguous' => strings.assistantRecordAmbiguous,
        'bill_ambiguous' => strings.assistantBillAmbiguous,
        'debt_ambiguous' => strings.assistantDebtAmbiguous,
        'bill_payment_not_available' =>
          strings.assistantBillPaymentNotAvailable,
        'debt_payment_exceeds_balance' =>
          strings.assistantDebtPaymentExceedsBalance,
        'debt_amount_below_paid' => strings.assistantDebtAmountBelowPaid,
        'work_balance_insufficient' => strings.assistantWorkBalanceInsufficient,
        'home_balance_insufficient' => strings.assistantHomeBalanceInsufficient,
        'bill_commitment_not_available' => strings.assistantBillCommitmentNotAvailable,
        'home_commitment_not_covered' => strings.assistantHomeCommitmentNotCovered,
        _ => strings.assistantNotUnderstood,
      };

  String? _sectionRoute(String section) => switch (section) {
        'dashboard' => '/dashboard',
        'work' => '/work',
        'home' => '/home',
        'debts' => '/debts',
        'ai' => '/ai',
        'settings' => '/settings',
        _ => null,
      };

  Future<void> _send() async {
    final strings = AppLocalizations.of(context)!;
    final mediaBytes = _attachmentBytes;
    final image = _attachmentIsImage;
    final text = _input.text.trim().isEmpty && mediaBytes != null
        ? (image ? strings.aiDefaultImagePrompt : strings.aiDefaultAudioPrompt)
        : _input.text.trim();
    if ((text.isEmpty && mediaBytes == null) ||
        _busy ||
        _recognizing ||
        _preparing) {
      return;
    }

    // Restore the user's persisted engine selection and complete the model
    // file check before selecting an engine. Otherwise the first request after
    // startup can silently fall through to the deterministic local parser.
    setState(() => _preparing = true);
    try {
      await ref.read(appSettingsProvider.notifier).waitUntilRestored();
      final restoredSettings = ref.read(appSettingsProvider);
      if (restoredSettings.useGemma &&
          ref.read(gemmaModelManagerProvider).status !=
              GemmaModelStatus.ready) {
        await ref.read(gemmaModelManagerProvider.notifier).refresh();
      }
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
    if (!mounted) return;

    final media = mediaBytes == null
        ? null
        : AssistantMedia(
            imageBytes: image ? mediaBytes : null,
            audioBytes: image ? null : mediaBytes,
          );
    if (media != null) {
      final settings = ref.read(appSettingsProvider);
      final modelState = settings.useGemma
          ? ref.read(gemmaModelManagerProvider)
          : null;
      if (!settings.useGemma ||
          modelState?.status != GemmaModelStatus.ready) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.aiGemmaRequired)),
        );
        return;
      }
    }

    final attachmentLabel = image
        ? strings.aiImageAttachmentLabel
        : strings.aiAudioAttachmentLabel;
    final displayedText = media == null
        ? text
        : '$text\\n[$attachmentLabel: ${_attachmentName ?? strings.aiAttachmentFallback}]';
    final conversationContext = buildAiConversationContext(
      ref.read(aiChatWorkspaceProvider).messages,
      maxMessages: 5,
      maxCharacters: 480,
    );

    setState(() {
      _busy = true;
      ref.read(aiChatWorkspaceProvider.notifier).add(
        AiChatMessage(displayedText, fromUser: true),
      );
      _input.clear();
      _attachmentBytes = null;
      _attachmentName = null;
      _confirmation.cancel();
      _undo = null;
    });

    final registry = _registry();
    String? replySource;
    try {
      final categoryItems =
          await ref.read(homeExpenseCategoryRepositoryProvider).getAll();
      final availableCategories = <String, String>{
        for (final category in categoryItems)
          category.id: (_categoryName(category.id, strings) ?? category.name.trim()).isEmpty
              ? category.id
              : (_categoryName(category.id, strings) ?? category.name.trim()),
      };
      final selectedEngine = ref.read(assistantEngineProvider);
      var result = await selectedEngine.interpret(
        text,
        registry.actionNames,
        media: media,
        conversationContext: conversationContext,
        expenseCategories: availableCategories,
      );

      // Validate all model-generated tools against the same contract as the
      // deterministic engine. Retry invalid text commands locally.
      if (media == null &&
          ref.read(appSettingsProvider).useGemma &&
          result.command != null &&
          registry.validate(
                result.command!.name,
                result.command!.parameters,
              ) !=
              null) {
        final localResult = await const LocalRuleAssistantEngine().interpret(
          text,
          registry.actionNames,
          conversationContext: conversationContext,
          expenseCategories: availableCategories,
        );
        result = localResult.command != null &&
                registry.validate(
                      localResult.command!.name,
                      localResult.command!.parameters,
                    ) ==
                    null
            ? localResult.withSource(
                AssistantResultSource.local,
                usedGemmaFallback: true,
              )
            : AssistantResult.notUnderstood().withSource(
                AssistantResultSource.local,
                usedGemmaFallback: true,
              );
      }
      replySource = result.usedGemmaFallback
          ? 'localAfterGemma'
          : result.source == AssistantResultSource.gemma
              ? 'gemma'
              : 'local';
      if (!mounted) return;

      if (result.kind == AssistantResultKind.clarification ||
          result.kind == AssistantResultKind.answer) {
        _addAssistantMessage(
          result.message ?? strings.assistantClarificationFallback,
          includeInModelContext: true,
          assistantSource: replySource,
        );
      } else if (result.kind == AssistantResultKind.notUnderstood ||
          result.command == null) {
        _addAssistantMessage(
          strings.assistantNotUnderstood,
          assistantSource: replySource,
        );
        await _openManual();
      } else {
        final originalCommand = result.command!;
        final preparedParameters = await registry.prepareUpdateParameters(
          originalCommand.name,
          originalCommand.parameters,
        );
        final command = AssistantCommand(
          name: originalCommand.name,
          parameters: preparedParameters,
        );
        final error = registry.validate(command.name, command.parameters);
        if (error != null) {
          _addAssistantMessage(
            strings.assistantNotUnderstood,
            assistantSource: replySource,
          );
          await _openManual();
        } else if (command.name == 'navigate_to_section') {
          final section = command.parameters['section']! as String;
          final route = _sectionRoute(section);
          if (route == null) {
            _addAssistantMessage(
              strings.assistantNotUnderstood,
              assistantSource: replySource,
            );
            await _openManual();
          } else {
            _addAssistantMessage(
              '${strings.aiSectionOpened}: ${_sectionLabel(section, strings)}',
              assistantSource: replySource,
            );
            if (mounted) context.go(route);
          }
        } else if (registry.descriptor(command.name)!.readOnly) {
          final execution = await registry.execute(
            command.name,
            command.parameters,
          );
          if (mounted) {
            final summary = execution.dashboardSummary;
            final message = command.name == 'read_home_categories'
                ? '${strings.category}: ${availableCategories.values.join('، ')}'
                : summary == null
                    ? execution.message
                    : _dashboardSummaryMessage(summary, strings);
            _addAssistantMessage(
              message,
              assistantSource: replySource,
            );
          }
        } else {
          setState(() => _confirmation.request(command));
          _addAssistantMessage(
            strings.assistantReview,
            assistantSource: replySource,
          );
        }
      }
    } on AssistantActionException catch (error) {
      if (mounted) {
        _addAssistantMessage(
          _assistantActionErrorMessage(error.code, strings),
          assistantSource: replySource,
        );
      }
    } catch (_) {
      if (mounted) {
        _addAssistantMessage(
          strings.assistantNotUnderstood,
          assistantSource: replySource,
        );
        await _openManual();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    if (!_confirmation.hasPending || _busy) return;
    final strings = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    try {
      final pendingCommand = _confirmation.pending;
      final execution = await _confirmation.approve(
        (command) => _registry().execute(command.name, command.parameters),
      );
      if (execution == null || !mounted) return;
      _refreshAfterAssistantAction(pendingCommand?.name);
      _lastUndoAction = execution.undo == null ? null : pendingCommand?.name;
      setState(() => _undo = execution.undo);
      _addAssistantMessage(execution.message);
    } on AssistantActionException catch (error) {
      if (mounted) {
        setState(_confirmation.cancel);
        final message = _assistantActionErrorMessage(error.code, strings);
        _addAssistantMessage(message);
        if (message == strings.assistantNotUnderstood) {
          await _openManual();
        }
      }
    } catch (_) {
      if (mounted) {
        setState(_confirmation.cancel);
        _addAssistantMessage(strings.assistantNotUnderstood);
      }
      await _openManual();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _undoLast() async {
    final undo = _undo;
    if (undo == null || _busy) return;
    setState(() => _busy = true);
    try {
      await undo();
      if (mounted) {
        _refreshAfterAssistantAction(_lastUndoAction);
        _lastUndoAction = null;
        setState(() => _undo = null);
        _addAssistantMessage(
          AppLocalizations.of(context)!.assistantUndone,
        );
      }
    } catch (_) {
      if (mounted) {
        _addAssistantMessage(
          AppLocalizations.of(context)!.assistantUndoFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openManual() async {
    if (!mounted) return;
    final strings = AppLocalizations.of(context)!;
    final section = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.work_outline), title: Text(strings.work), onTap: () => Navigator.pop(context, '/work')),
        ListTile(leading: const Icon(Icons.home_outlined), title: Text(strings.homeSection), onTap: () => Navigator.pop(context, '/home')),
        ListTile(leading: const Icon(Icons.account_balance_wallet_outlined), title: Text(strings.debts), onTap: () => Navigator.pop(context, '/debts')),
      ])),
    );
    if (section != null && mounted) context.go(section, extra: true);
  }

  String? _kindName(Object? rawKind, AppLocalizations strings) {
    if (rawKind is! String) return null;
    return switch (rawKind) {
      'salary' => strings.salary,
      'advance' => strings.advance,
      'payment' || 'salaryPayment' => strings.payment,
      'monthly' => strings.monthlyBills,
      'rent' => strings.rent,
      _ => null,
    };
  }

  String? _categoryName(Object? rawCategory, AppLocalizations strings) {
    if (rawCategory is! String) return null;
    return switch (rawCategory) {
      'groceries' => strings.homeCategoryGroceries,
      'utilities' => strings.homeCategoryUtilities,
      'housing' => strings.homeCategoryHousing,
      'cleaning' => strings.homeCategoryCleaning,
      'maintenance' => strings.homeCategoryMaintenance,
      'transport' => strings.homeCategoryTransport,
      'personal' => strings.homeCategoryPersonal,
      'health' => strings.homeCategoryHealth,
      'children' => strings.homeCategoryChildren,
      'education' => strings.homeCategoryEducation,
      'entertainment' => strings.homeCategoryEntertainment,
      'communication' => strings.homeCategoryCommunication,
      'subscriptions' => strings.homeCategorySubscriptions,
      'gifts' => strings.homeCategoryGifts,
      'other' => strings.homeCategoryOther,
      _ => null,
    };
  }

  Widget _confirmationRecordCard(
    AssistantCommand command,
    AppLocalizations strings,
  ) {
    final parameters = command.parameters;
    final kind = parameters['kind'];
    final categoryId = parameters['categoryId'];
    final categoryName = parameters['categoryName'] is String
        ? (parameters['categoryName']! as String).trim()
        : _categoryName(categoryId, strings);
    final note = parameters['note'] is String
        ? (parameters['note']! as String).trim()
        : '';
    final rawDate = parameters['date'];
    final parsedDate = rawDate is String ? DateTime.tryParse(rawDate) : null;
    final formattedDate = parsedDate == null
        ? null
        : toAsciiDigits(
            MaterialLocalizations.of(context).formatFullDate(parsedDate),
          );
    final rawAmount = parameters['amountMinorUnits'];
    final amount = rawAmount is int ? rawAmount.toString() : '—';
    final billPaid = parameters['paidMinorUnits'] is int
        ? parameters['paidMinorUnits']! as int
        : 0;
    final billRemaining = parameters['remainingMinorUnits'] is int
        ? (parameters['remainingMinorUnits']! as int).toString()
        : amount;
    final isDebt = command.name == 'save_debt';
    final isCreditor = parameters['direction'] == 'creditor';
    final isDebtor = parameters['direction'] == 'debtor';
    final debtDirectionLabel = isCreditor
        ? strings.creditor
        : isDebtor
            ? strings.debtor
            : null;

    final details = <String>[
      if (command.name == 'record_home_bill_payment' &&
          parameters['billTitle'] is String)
        parameters['billTitle']! as String,
      ?formattedDate,
      if (command.name == 'delete_home_expense' &&
          parameters['year'] is int && parameters['month'] is int)
        '${strings.assistantMonth}: ${(parameters['month']! as int).toString().padLeft(2, '0')}/${parameters['year']}',
      if ((command.name == 'delete_work_entry' ||
              command.name == 'delete_work_home_transfer') &&
          parameters['year'] is int && parameters['month'] is int)
        '${strings.assistantMonth}: ${(parameters['month']! as int).toString().padLeft(2, '0')}/${parameters['year']}',
      if (kind is String && _kindName(kind, strings) != null)
        _kindName(kind, strings)!,
      if (isDebt) '${strings.originalAmount}: $amount',
      if (debtDirectionLabel != null && !isDebt) debtDirectionLabel,
      if (parameters['id'] is String) 'ID: ${parameters['id']}',
      if (note.isNotEmpty) note,
    ];

    final title = switch (command.name) {
      'save_work_entry' || 'delete_work_entry' =>
        _kindName(kind, strings) ?? strings.work,
      'delete_work_home_transfer' => strings.transferredToHome,
      'save_work_home_transfer' => strings.transferredToHome,
      'save_home_expense' || 'delete_home_expense' =>
        categoryName ?? strings.homeSection,
      'save_home_bill' =>
        (parameters['title'] as String?) ?? strings.monthlyBills,
      'record_home_bill_payment' => strings.addBillPayment,
      'save_debt' || 'record_debt_payment' =>
        (parameters['counterparty'] as String?) ?? strings.debts,
      'save_home_category' || 'delete_home_category' =>
        (parameters['name'] as String?) ?? strings.category,
      'delete_home_bill' =>
        (parameters['billTitle'] as String?) ?? strings.monthlyBills,
      'delete_debt' =>
        (parameters['counterparty'] as String?) ?? strings.debts,
      _ => strings.assistantOperation,
    };

    final icon = switch (command.name) {
      'save_work_entry' || 'delete_work_entry' => kind == 'advance'
          ? Icons.request_quote_outlined
          : kind == 'payment'
              ? Icons.receipt_long_outlined
              : Icons.payments_outlined,
      'save_work_home_transfer' || 'delete_work_home_transfer' => Icons.swap_horiz,
      'save_home_expense' || 'delete_home_expense' =>
        _categoryIconForAssistant(categoryId),
      'save_home_bill' || 'delete_home_bill' =>
        kind == 'rent' ? Icons.home_outlined : Icons.receipt_long_outlined,
      'record_home_bill_payment' => Icons.payments_outlined,
      'save_debt' || 'record_debt_payment' || 'delete_debt' =>
        isCreditor
            ? Icons.call_received_outlined
            : Icons.call_made_outlined,
      'save_home_category' || 'delete_home_category' => Icons.sell_outlined,
      _ => Icons.receipt_long_outlined,
    };

    if (command.name == 'save_home_bill') {
      return FinancialRecordCard(
        icon: kind == 'rent'
            ? Icons.home_outlined
            : Icons.receipt_long_outlined,
        title: title,
        amount: amount,
        details: [
          ?formattedDate,
          '${strings.billPaid}: $billPaid / $amount',
          '${strings.billRemaining}: $billRemaining',
          if (note.isNotEmpty) note,
        ],
      );
    }

    Widget? badge;
    Widget? footer;
    if (isDebt) {
      final scheme = Theme.of(context).colorScheme;
      final tokens = AppDesignTokens.of(context);
      badge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isCreditor ? scheme.tertiaryContainer : scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(tokens.controlRadius),
        ),
        child: Text(
          debtDirectionLabel ?? '',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: isCreditor
                    ? scheme.onTertiaryContainer
                    : scheme.onSecondaryContainer,
              ),
        ),
      );
      footer = ClipRRect(
        borderRadius: BorderRadius.circular(tokens.controlRadius),
        child: LinearProgressIndicator(
          value: 0,
          minHeight: 7,
          backgroundColor: scheme.surfaceContainerHighest,
          color: scheme.tertiary,
        ),
      );
    }

    return FinancialRecordCard(
      icon: icon,
      title: title,
      amount: amount,
      amountLabel: isDebt
          ? strings.outstandingAmount
          : command.name == 'record_debt_payment'
              ? strings.recordDebtPayment
              : null,
      details: details,
      badge: badge,
      footer: footer,
    );
  }

  IconData _categoryIconForAssistant(Object? id) => switch (id) {
    'groceries' => Icons.shopping_basket_outlined,
    'utilities' => Icons.electrical_services_outlined,
    'housing' => Icons.home_outlined,
    'cleaning' => Icons.cleaning_services_outlined,
    'maintenance' => Icons.build_outlined,
    'transport' => Icons.directions_car_outlined,
    'personal' => Icons.person_outline,
    'health' => Icons.health_and_safety_outlined,
    'children' => Icons.child_care_outlined,
    'education' => Icons.school_outlined,
    'entertainment' => Icons.movie_outlined,
    'communication' => Icons.phone_outlined,
    'subscriptions' => Icons.subscriptions_outlined,
    'gifts' => Icons.card_giftcard_outlined,
    _ => Icons.shopping_cart_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final pending = _confirmation.pending;
    final workspace = ref.watch(aiChatWorkspaceProvider);
    final messages = workspace.messages;
    ref.listen<AiChatWorkspaceState>(
      aiChatWorkspaceProvider,
      (previous, next) => _scheduleScrollToBottom(),
    );
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = AppDesignTokens.of(context);
    final maxBubbleWidth = MediaQuery.sizeOf(context).width * 0.84;

    return Scaffold(
      body: Column(
        children: [
          _conversationToolbar(workspace, strings, tokens),
          Expanded(
            child: ListView(
              controller: _scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: tokens.pageInsets(bottom: tokens.pageVerticalPadding * 2),
              children: [
                if (messages.isEmpty)
                  Card(
                    color: scheme.surfaceContainerLow,
                    child: Padding(
                      padding: EdgeInsets.all(tokens.cardPadding + 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: scheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(tokens.controlRadius),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.auto_awesome_rounded,
                              color: scheme.onSecondaryContainer,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              strings.assistantWelcome,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                for (final message in messages)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Align(
                      alignment: message.fromUser
                          ? AlignmentDirectional.centerEnd
                          : AlignmentDirectional.centerStart,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AnimatedSize(
                              duration: tokens.motionDuration,
                              curve: Curves.easeOut,
                              child: ChatMessageBubble(
                                text: message.text,
                                isOutgoing: message.fromUser,
                              ),
                            ),
                            if (!message.fromUser &&
                                message.assistantSource != null)
                              _assistantSourceBadge(
                                message.assistantSource!,
                                strings,
                              ),
                            Align(
                              alignment: message.fromUser
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsetsDirectional.only(
                                  start: 4,
                                  end: 4,
                                  top: 2,
                                ),
                                child: Wrap(
                                  spacing: 4,
                                  children: [
                                  TextButton.icon(
                                    onPressed: () => _copyMessage(message.text),
                                    icon: const Icon(Icons.copy_rounded, size: 16),
                                    label: Text(strings.aiCopy),
                                  ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (_busy)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 150),
                      child: Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              const SizedBox(width: 10),
                              Flexible(child: Text(strings.loading)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (pending != null)
                  AnimatedSwitcher(
                    duration: tokens.motionDuration,
                    child: Card(
                      key: ValueKey(
                        pending.name + pending.parameters.toString(),
                      ),
                      color: scheme.secondaryContainer,
                      child: Padding(
                        padding: EdgeInsets.all(tokens.cardPadding + 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.fact_check_outlined,
                                  color: scheme.onSecondaryContainer,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    strings.assistantConfirm,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      color: scheme.onSecondaryContainer,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _confirmationRecordCard(pending, strings),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FilledButton(
                                  onPressed: _busy ? null : _confirm,
                                  child: Text(strings.assistantApprove),
                                ),
                                OutlinedButton(
                                  onPressed: _busy
                                      ? null
                                      : () => setState(_confirmation.cancel),
                                  child: Text(strings.cancel),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (_undo != null)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: _busy ? null : _undoLast,
                      icon: const Icon(Icons.undo_rounded),
                      label: Text(strings.assistantUndo),
                    ),
                  ),
              ],
            ),
          ),
          if (_attachmentName != null || _recognizing)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _recognizing
                            ? Icons.mic
                            : (_attachmentIsImage
                                  ? Icons.image_outlined
                                  : Icons.audio_file_outlined),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _recognizing ? strings.aiVoiceListening : _attachmentName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!_recognizing && _attachmentName != null)
                        IconButton(
                          onPressed: _busy ? null : _removeAttachment,
                          icon: const Icon(Icons.close),
                          tooltip: strings.aiRemoveAttachment,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: Container(
                key: const Key('ai-chat-composer'),
                constraints: const BoxConstraints(minHeight: 44),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  border: Border.all(color: scheme.outlineVariant),
                  borderRadius: BorderRadius.circular(28),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: IconButton(
                          key: const Key('ai-attachment-button'),
                          onPressed: _busy || _recognizing || _preparing
                              ? null
                              : _chooseAttachment,
                          icon: const Icon(Icons.attach_file_rounded, size: 24),
                          color: scheme.onSurfaceVariant,
                          tooltip: strings.aiFiles,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 40,
                            height: 40,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          key: const Key('ai-message-input'),
                          controller: _input,
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.start,
                          minLines: 1,
                          maxLines: 4,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: InputDecoration(
                            hintText: strings.assistantHint,
                            filled: false,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 8,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _input,
                          builder: (context, value, child) {
                            final hasText = value.text.trim().isNotEmpty;
                            final canInteract =
                                !_busy && !_recognizing && !_preparing;
                            return IconButton.filled(
                              key: const Key('ai-contextual-input-action'),
                              onPressed: !canInteract
                                  ? null
                                  : hasText
                                      ? _send
                                      : _recognizeArabicSpeech,
                              tooltip: _recognizing
                                  ? strings.aiVoiceListening
                                  : hasText
                                      ? strings.assistantSend
                                      : strings.aiVoiceInput,
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFF229ED9),
                                foregroundColor: Colors.white,
                                shape: const CircleBorder(),
                              ),
                              icon: _busy || _recognizing || _preparing
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(
                                      hasText
                                          ? Icons.send_rounded
                                          : Icons.mic_none_rounded,
                                      size: 23,
                                    ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints.tightFor(
                                width: 40,
                                height: 40,
                              ),
                              visualDensity: VisualDensity.compact,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
