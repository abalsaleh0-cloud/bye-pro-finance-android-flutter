// ignore_for_file: curly_braces_in_flow_control_structures, prefer_interpolation_to_compose_strings

import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:flutter/services.dart';
import 'package:expense_app/features/ai/data/android_assistant_voice_service.dart';

import 'package:expense_app/features/ai/domain/wav_audio_validator.dart';

import 'package:expense_app/core/database/database_providers.dart';
import 'package:expense_app/core/providers/app_settings_provider.dart';
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

final assistantEngineProvider = Provider<AssistantEngine>((ref) {
  final settings = ref.watch(appSettingsProvider);
  final modelState = ref.watch(gemmaModelManagerProvider);
  final manager = ref.watch(gemmaModelManagerProvider.notifier);
  if (settings.useGemma && modelState.status == GemmaModelStatus.ready) {
    return GemmaAssistantEngine(manager);
  }
  return const FakeAssistantEngine();
});

class AiScreen extends ConsumerStatefulWidget {
  const AiScreen({super.key});
  @override
  ConsumerState<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends ConsumerState<AiScreen> {
  final _input = TextEditingController();
  final AssistantConfirmation _confirmation = AssistantConfirmation();
  UndoOperation? _undo;
  bool _busy = false;
  final AudioRecorder _recorder = AudioRecorder();
  final AndroidAssistantVoiceService _voiceService = const AndroidAssistantVoiceService();
  bool _recognizing = false;
  bool _speakReplies = false;
  Uint8List? _attachmentBytes;
  bool _attachmentIsImage = false;
  String? _attachmentName;
  bool _recording = false;

  @override
  void dispose() {
    _input.dispose();
    if (_recognizing) {
      unawaited(_voiceService.cancelArabicSpeechRecognition());
    }
    if (_speakReplies) {
      unawaited(_voiceService.stopSpeaking());
    }
    if (_recording) unawaited(_recorder.stop());
    unawaited(_recorder.dispose());
    unawaited(ref.read(gemmaModelManagerProvider.notifier).releaseModel());
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
    final strings = AppLocalizations.of(context)!;
    final image = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.image_outlined), title: Text(strings.aiAttachImage), onTap: () => Navigator.pop(context, true)),
        ListTile(leading: const Icon(Icons.audio_file_outlined), title: Text(strings.aiAttachWav), onTap: () => Navigator.pop(context, false)),
      ])),
    );
    if (image != null && mounted) await _pickAttachment(image: image);
  }

  Future<void> _pickAttachment({required bool image}) async {
    final strings = AppLocalizations.of(context)!;
    if (_busy || _recording) return;
    try {
      final file = await FilePicker.pickFile(
        type: image ? FileType.image : FileType.custom,
        allowedExtensions: image ? null : ['wav'],
      );
      if (file == null) return;
      final limit = image ? 12 * 1024 * 1024 : 20 * 1024 * 1024;
      final length = file.lengthSync() ?? await file.length();
      if (length == null || length <= 0) {
        throw StateError(strings.aiReadFileFailed);
      }
      if (length > limit) {
        throw StateError(image
            ? strings.aiImageTooLarge
            : strings.aiAudioTooLarge);
      }
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) throw StateError(strings.aiReadFileFailed);
      if (!image && !_isValidWav(bytes)) throw StateError(strings.aiInvalidWav);
      if (!mounted) return;
      setState(() {
        _attachmentBytes = bytes;
        _attachmentIsImage = image;
        _attachmentName = file.name;
      });
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))));
    }
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

  Future<void> _speakAssistantReply(String text) async {
    if (!_speakReplies || text.trim().isEmpty) return;
    try {
      await _voiceService.speakArabic(text);
    } on PlatformException {
      if (!mounted) return;
      setState(() => _speakReplies = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.aiArabicTtsUnavailable),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _speakReplies = false);
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
    final maxBubbleWidth = MediaQuery.sizeOf(context).width * 0.84;

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                if (messages.isEmpty)
                  Card(
                    color: scheme.surfaceContainerLow,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: scheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(14),
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
                for (var i = 0; i < messages.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Align(
                      alignment: messages[i].fromUser
                          ? AlignmentDirectional.centerEnd
                          : AlignmentDirectional.centerStart,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                        child: AnimatedSize(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                          child: Card(
                            margin: EdgeInsets.zero,
                            color: messages[i].fromUser
                                ? scheme.secondaryContainer
                                : scheme.surfaceContainerHigh,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 15,
                                vertical: 12,
                              ),
                              child: Text(
                                messages[i].text,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: messages[i].fromUser
                                      ? scheme.onSecondaryContainer
                                      : scheme.onSurface,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ),
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
                    duration: const Duration(milliseconds: 250),
                    child: Card(
                      key: ValueKey(
                        pending.name + pending.parameters.toString(),
                      ),
                      color: scheme.secondaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
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
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _busy || _recording || _recognizing ? null : _chooseAttachment,
                        icon: const Icon(Icons.attach_file_rounded),
                        tooltip: strings.aiAttachImage,
                      ),
                      IconButton(
                        onPressed: _busy || _recognizing
                            ? null
                            : (_recording ? _toggleRecording : _showVoiceOptions),
                        icon: Icon(
                          _recording
                              ? Icons.stop_circle_outlined
                              : Icons.mic_none_rounded,
                        ),
                        tooltip: _recording
                            ? strings.aiStopRecording
                            : strings.aiVoiceOptions,
                      ),
                      IconButton(
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
                      Expanded(
                        child: TextField(
                          controller: _input,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: InputDecoration(
                            hintText: strings.assistantHint,
                            isDense: true,
                            constraints: const BoxConstraints(
                              minHeight: 48,
                              maxHeight: 48,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton.filled(
                        onPressed: _busy || _recording || _recognizing ? null : _send,
                        tooltip: strings.assistantSend,
                        icon: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
