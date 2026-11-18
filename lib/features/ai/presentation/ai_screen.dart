// ignore_for_file: curly_braces_in_flow_control_structures, prefer_interpolation_to_compose_strings

import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:flutter/services.dart';
import 'package:expense_app/features/ai/data/android_assistant_voice_service.dart';

import 'package:expense_app/features/ai/domain/wav_audio_validator.dart';

import 'package:expense_app/core/database/database_providers.dart';
import 'package:expense_app/core/providers/app_settings_provider.dart';
import 'package:expense_app/core/theme/app_design_tokens.dart';
import 'package:expense_app/core/time/selected_month_provider.dart';
import 'package:expense_app/features/ai/data/gemma_model_manager.dart';
import 'package:expense_app/features/ai/domain/action_registry.dart';
import 'package:expense_app/features/ai/domain/assistant_confirmation.dart';
import 'package:expense_app/features/ai/domain/assistant_engine.dart';
import 'package:expense_app/features/ai/domain/gemma_assistant_engine.dart';
import 'package:expense_app/features/ai/presentation/ai_chat_state.dart';
import 'package:expense_app/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

enum _AssistantAttachmentChoice { camera, gallery, files }

final assistantEngineProvider = Provider<AssistantEngine>((ref) {
  final settings = ref.watch(appSettingsProvider);
  final modelState = ref.watch(gemmaModelManagerProvider);
  final manager = ref.watch(gemmaModelManagerProvider.notifier);
  const fallback = FakeAssistantEngine();
  if (settings.useGemma && modelState.status == GemmaModelStatus.ready) {
    return FallbackAssistantEngine(
      primary: GemmaAssistantEngine(manager),
      fallback: fallback,
    );
  }
  return fallback;
});

class AiScreen extends ConsumerStatefulWidget {
  const AiScreen({super.key});
  @override
  ConsumerState<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends ConsumerState<AiScreen> {
  late final GemmaModelManager _gemmaModelManager;
  final _input = TextEditingController();
  final AssistantConfirmation _confirmation = AssistantConfirmation();
  UndoOperation? _undo;
  bool _busy = false;
  final AudioRecorder _recorder = AudioRecorder();
  final ImagePicker _imagePicker = ImagePicker();
  final AndroidAssistantVoiceService _voiceService = const AndroidAssistantVoiceService();
  bool _recognizing = false;
  bool _speakReplies = false;
  Uint8List? _attachmentBytes;
  bool _attachmentIsImage = false;
  String? _attachmentName;
  bool _recording = false;

  @override
  void initState() {
    super.initState();
    _gemmaModelManager = ref.read(gemmaModelManagerProvider.notifier);
  }

  @override
  void dispose() {
    _input.dispose();
    if (_recognizing) {
      unawaited(_voiceService.cancelArabicSpeechRecognition());
    }
    if (_speakReplies) unawaited(_voiceService.stopSpeaking());
    if (_recording) unawaited(_recorder.stop());
    unawaited(_recorder.dispose());
    unawaited(_gemmaModelManager.releaseModel());
    super.dispose();
  }

  ActionRegistry _registry() => ActionRegistry(
    work: ref.read(workRepositoryProvider),
    home: ref.read(homeExpenseRepositoryProvider),
    bills: ref.read(homeBillRepositoryProvider),
    debts: ref.read(debtRepositoryProvider),
    selectedMonth: ref.read(selectedMonthProvider),
  );

  Future<void> _chooseAttachment() async {
    if (_busy || _recording || _recognizing) return;
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
    if (_busy || _recording) return;
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

  void _addAssistantMessage(
    String text, {
    bool includeInModelContext = false,
  }) {
    ref.read(aiChatMessagesProvider.notifier).add(
      AiChatMessage(text, includeInModelContext: includeInModelContext),
    );
    if (_speakReplies) unawaited(_speakAssistantReply(text));
  }

  Future<void> _copyMessage(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.aiCopied)),
    );
  }

  Future<void> _speakAssistantReply(String text) async {
    if (text.trim().isEmpty) return;
    try {
      await _voiceService.speakArabic(text);
    } on PlatformException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.aiArabicTtsUnavailable),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.aiArabicTtsUnavailable),
        ),
      );
    }
  }

  Future<void> _toggleSpokenReplies() async {
    if (_busy || _recognizing || _recording) return;
    if (_speakReplies) {
      setState(() => _speakReplies = false);
      try {
        await _voiceService.stopSpeaking();
      } catch (_) {}
      return;
    }

    final strings = AppLocalizations.of(context)!;
    try {
      final available = await _voiceService.hasOfflineArabicTts();
      if (!mounted) return;
      if (!available) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.aiArabicTtsUnavailable)),
        );
        return;
      }
      setState(() => _speakReplies = true);
    } on PlatformException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.aiArabicTtsUnavailable)),
      );
    }
  }

  Future<void> _showVoiceOptions() async {
    if (_busy || _recognizing || _recording) return;
    final strings = AppLocalizations.of(context)!;
    final option = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.mic_none_rounded),
              title: Text(strings.aiVoiceInput),
              onTap: () => Navigator.pop(context, 'dictate'),
            ),
            ListTile(
              leading: const Icon(Icons.graphic_eq_rounded),
              title: Text(strings.aiRecordAudio),
              onTap: () => Navigator.pop(context, 'record'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || option == null) return;
    if (option == 'dictate') {
      await _recognizeArabicSpeech();
    } else if (option == 'record') {
      await _toggleRecording();
    }
  }

  Future<void> _recognizeArabicSpeech() async {
    if (_busy || _recording || _recognizing) return;
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
      await _send();
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



  Future<void> _toggleRecording() async {
    final strings = AppLocalizations.of(context)!;
    if (_busy) return;
    try {
      if (!_recording) {
        if (!await _recorder.hasPermission()) {
          throw StateError(strings.aiMicrophonePermission);
        }
        final directory = await Directory.systemTemp.createTemp('bye-pro-audio-');
        final path = '${directory.path}/voice.wav';
        await _recorder.start(
          const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1),
          path: path,
        );
        if (mounted) setState(() { _recording = true; });
      } else {
        final path = await _recorder.stop();
        if (path == null) throw StateError(strings.aiRecordingSaveFailed);
        final recordingFile = File(path);
        final bytes = await recordingFile.readAsBytes();
        await recordingFile.delete();
        try { await recordingFile.parent.delete(); } catch (_) {}
        if (!_isValidWav(bytes)) throw StateError(strings.aiInvalidRecording);
        if (bytes.length > 20 * 1024 * 1024) throw StateError(strings.aiAudioTooLarge);
        if (mounted) setState(() {
          _recording = false;
          _attachmentBytes = bytes;
          _attachmentIsImage = false;
          _attachmentName = 'voice.wav';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() { _recording = false; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))));
      }
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
    if ((text.isEmpty && mediaBytes == null) || _busy || _recording) return;
    final media = mediaBytes == null
        ? null
        : AssistantMedia(
            imageBytes: image ? mediaBytes : null,
            audioBytes: image ? null : mediaBytes,
          );
    if (media != null) {
      final settings = ref.read(appSettingsProvider);
      final modelState = ref.read(gemmaModelManagerProvider);
      if (!settings.useGemma || modelState.status != GemmaModelStatus.ready) {
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
      ref.read(aiChatMessagesProvider),
    );

    setState(() {
      _busy = true;
      ref.read(aiChatMessagesProvider.notifier).add(
        AiChatMessage(displayedText, fromUser: true),
      );
      _input.clear();
      _attachmentBytes = null;
      _attachmentName = null;
      _confirmation.cancel();
      _undo = null;
    });

    final registry = _registry();
    try {
      final result = await ref.read(assistantEngineProvider).interpret(
        text,
        registry.actionNames,
        media: media,
        conversationContext: conversationContext,
      );
      if (!mounted) return;

      if (result.kind == AssistantResultKind.clarification ||
          result.kind == AssistantResultKind.answer) {
        _addAssistantMessage(
          result.message ?? strings.assistantClarificationFallback,
          includeInModelContext: true,
        );
      } else if (result.kind == AssistantResultKind.notUnderstood ||
          result.command == null) {
        _addAssistantMessage(strings.assistantNotUnderstood);
        await _openManual();
      } else {
        final command = result.command!;
        final error = registry.validate(command.name, command.parameters);
        if (error != null) {
          _addAssistantMessage(strings.assistantNotUnderstood);
          await _openManual();
        } else if (command.name == 'navigate_to_section') {
          final section = command.parameters['section']! as String;
          final route = _sectionRoute(section);
          if (route == null) {
            _addAssistantMessage(strings.assistantNotUnderstood);
            await _openManual();
          } else {
            _addAssistantMessage(
              '${strings.aiSectionOpened}: ${_sectionLabel(section, strings)}',
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
            _addAssistantMessage(
              summary == null
                  ? execution.message
                  : _dashboardSummaryMessage(summary, strings),
            );
          }
        } else {
          setState(() => _confirmation.request(command));
          _addAssistantMessage(strings.assistantReview);
        }
      }
    } catch (_) {
      if (mounted) {
        _addAssistantMessage(strings.assistantNotUnderstood);
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
      final execution = await _confirmation.approve(
        (command) => _registry().execute(command.name, command.parameters),
      );
      if (execution == null || !mounted) return;
      setState(() => _undo = execution.undo);
      _addAssistantMessage(execution.message);
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

  String _sectionName(String action, AppLocalizations s) {
    if (action.contains('work')) return s.work;
    if (action.contains('home') || action.contains('transfer')) return s.homeSection;
    if (action.contains('debt')) return s.debts;
    return s.ai;
  }

  String _operationName(String action, AppLocalizations s) {
    if (action.startsWith('read_')) return s.assistantRead;
    if (action.startsWith('delete_')) return s.deleteRecord;
    if (action == 'record_debt_payment') return s.recordDebtPayment;
    if (action == 'record_home_bill_payment') return s.addBillPayment;
    return s.save;
  }

  String? _displayMonth(AssistantCommand command) {
    final year = command.parameters['year'];
    final month = command.parameters['month'];
    if (year is int && month is int) {
      return year.toString() + '-' + month.toString().padLeft(2, '0');
    }
    return null;
  }

  String? _displayDate(Object? rawDate) {
    if (rawDate is! String) return null;
    final date = DateTime.tryParse(rawDate);
    if (date == null) return null;
    return MaterialLocalizations.of(context).formatMediumDate(date);
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
      'other' => strings.homeCategoryOther,
      _ => null,
    };
  }

  Widget _confirmationDetailRow(
    String label,
    String value,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _confirmationDetails(
    AssistantCommand command,
    AppLocalizations strings,
  ) {
    final parameters = command.parameters;
    final details = <Widget>[
      _confirmationDetailRow(
        strings.assistantSection,
        _sectionName(command.name, strings),
        Icons.folder_outlined,
      ),
      _confirmationDetailRow(
        strings.assistantOperation,
        _operationName(command.name, strings),
        Icons.playlist_add_check_circle_outlined,
      ),
    ];

    final amount = parameters['amountMinorUnits'];
    if (amount is int) {
      details.add(
        _confirmationDetailRow(
          strings.assistantAmount,
          amount.toString(),
          Icons.payments_outlined,
        ),
      );
    }

    final kind = _kindName(parameters['kind'], strings);
    if (kind != null) {
      details.add(_confirmationDetailRow(strings.entryType, kind, Icons.category_outlined));
    }

    final direction = parameters['direction'];
    if (direction == 'creditor' || direction == 'debtor') {
      details.add(
        _confirmationDetailRow(
          strings.debtDirection,
          direction == 'creditor' ? strings.creditor : strings.debtor,
          Icons.swap_horiz_rounded,
        ),
      );
    }

    final title = parameters['title'];
    if (title is String && title.trim().isNotEmpty) {
      details.add(_confirmationDetailRow(strings.billName, title, Icons.receipt_long_outlined));
    }

    final counterparty = parameters['counterparty'];
    if (counterparty is String && counterparty.trim().isNotEmpty) {
      details.add(
        _confirmationDetailRow(
          strings.counterparty,
          counterparty,
          Icons.person_outline_rounded,
        ),
      );
    }

    final category = _categoryName(parameters['categoryId'], strings);
    if (category != null) {
      details.add(_confirmationDetailRow(strings.category, category, Icons.sell_outlined));
    }

    final note = parameters['note'];
    if (note is String && note.trim().isNotEmpty) {
      details.add(_confirmationDetailRow(strings.note, note, Icons.notes_rounded));
    }

    final month = _displayMonth(command);
    if (month != null) {
      details.add(
        _confirmationDetailRow(
          strings.assistantMonth,
          month,
          Icons.calendar_month_outlined,
        ),
      );
    }

    final date = _displayDate(parameters['date']);
    if (date != null) {
      details.add(
        _confirmationDetailRow(
          strings.assistantDate,
          date,
          Icons.event_outlined,
        ),
      );
    }
    return details;
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final pending = _confirmation.pending;
    final messages = ref.watch(aiChatMessagesProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = AppDesignTokens.of(context);
    final maxBubbleWidth = MediaQuery.sizeOf(context).width * 0.84;

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: ListView(
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
                          crossAxisAlignment: message.fromUser
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            AnimatedSize(
                              duration: tokens.motionDuration,
                              curve: Curves.easeOut,
                              child: Card(
                                margin: EdgeInsets.zero,
                                color: message.fromUser
                                    ? scheme.secondaryContainer
                                    : scheme.surfaceContainerHigh,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(tokens.cardRadius),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: tokens.cardPadding + 1,
                                    vertical: tokens.cardPadding - 2,
                                  ),
                                  child: Text(
                                    message.text,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: message.fromUser
                                          ? scheme.onSecondaryContainer
                                          : scheme.onSurface,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
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
                                  TextButton.icon(
                                    onPressed: _busy
                                        ? null
                                        : () => _speakAssistantReply(message.text),
                                    icon: const Icon(
                                      Icons.volume_up_outlined,
                                      size: 16,
                                    ),
                                    label: Text(strings.aiListen),
                                  ),
                                ],
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
                            ..._confirmationDetails(pending, strings),
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
          if (_attachmentName != null || _recording || _recognizing)
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
                        (_recording || _recognizing)
                            ? Icons.mic
                            : (_attachmentIsImage
                                  ? Icons.image_outlined
                                  : Icons.audio_file_outlined),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _recognizing ? strings.aiVoiceListening : (_recording ? strings.aiRecording : _attachmentName!),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!_recording && !_recognizing && _attachmentName != null)
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
              padding: EdgeInsetsDirectional.fromSTEB(
                tokens.pageHorizontalPadding / 2,
                tokens.pageVerticalPadding / 2,
                tokens.pageHorizontalPadding / 2,
                tokens.pageVerticalPadding,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 52),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLow,
                        border: Border.all(color: scheme.outlineVariant),
                        borderRadius: BorderRadius.circular(tokens.controlRadius),
                      ),
                      padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 4, 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          IconButton.filledTonal(
                            key: const Key('ai-attach-button'),
                            onPressed: _busy || _recording || _recognizing
                                ? null
                                : _chooseAttachment,
                            icon: const Icon(Icons.attach_file_rounded),
                            tooltip: strings.aiFiles,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: TextField(
                              key: const Key('ai-message-input'),
                              controller: _input,
                              minLines: 1,
                              maxLines: 4,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _send(),
                              decoration: InputDecoration(
                                hintText: strings.assistantHint,
                                filled: false,
                                isDense: true,
                                contentPadding: const EdgeInsetsDirectional.fromSTEB(
                                  4, 12, 4, 12,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                              ),
                            ),
                          ),
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _input,
                            builder: (context, value, child) {
                              final hasText = value.text.trim().isNotEmpty;
                              final canInteract =
                                  !_busy && !_recording && !_recognizing;
                              return IconButton.filled(
                                key: const Key('ai-contextual-input-action'),
                                onPressed: !canInteract
                                    ? (_recording ? _toggleRecording : null)
                                    : hasText
                                        ? _send
                                        : _showVoiceOptions,
                                tooltip: _recording
                                    ? strings.aiStopRecording
                                    : hasText
                                        ? strings.assistantSend
                                        : strings.aiVoiceOptions,
                                icon: _busy
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Icon(
                                        _recording
                                            ? Icons.stop_rounded
                                            : hasText
                                                ? Icons.send_rounded
                                                : Icons.mic_none_rounded,
                                      ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  IconButton.filledTonal(
                    key: const Key('ai-spoken-replies-toggle'),
                    onPressed: _busy || _recording || _recognizing
                        ? null
                        : _toggleSpokenReplies,
                    icon: Icon(
                      _speakReplies
                          ? Icons.volume_up_rounded
                          : Icons.volume_off_outlined,
                    ),
                    tooltip: _speakReplies
                        ? strings.aiVoiceRepliesOn
                        : strings.aiVoiceRepliesOff,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
