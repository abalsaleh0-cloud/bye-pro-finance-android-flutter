// ignore_for_file: curly_braces_in_flow_control_structures, prefer_interpolation_to_compose_strings

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';

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
  Uint8List? _attachmentBytes;
  bool _attachmentIsImage = false;
  String? _attachmentName;
  bool _recording = false;

  @override
  void dispose() {
    _input.dispose();
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

  Future<void> _send() async {
    final strings = AppLocalizations.of(context)!;
    final mediaBytes = _attachmentBytes;
    final image = _attachmentIsImage;
    final text = _input.text.trim().isEmpty && mediaBytes != null
        ? (image ? 'حلّل الصورة المرفقة.' : 'استمع إلى التسجيل الصوتي المرفق ونفّذ المطلوب إن أمكن.')
        : _input.text.trim();
    if ((text.isEmpty && mediaBytes == null) || _busy || _recording) return;
    final media = mediaBytes == null ? null : AssistantMedia(
      imageBytes: image ? mediaBytes : null,
      audioBytes: image ? null : mediaBytes,
    );
    if (media != null) {
      final settings = ref.read(appSettingsProvider);
      final modelState = ref.read(gemmaModelManagerProvider);
      if (!settings.useGemma || modelState.status != GemmaModelStatus.ready) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(strings.aiGemmaRequired)));
        return;
      }
    }
    final displayedText = media == null ? text : '$text\n[${image ? 'صورة' : 'تسجيل صوتي'}: ${_attachmentName ?? 'مرفق'}]';
    setState(() { _busy = true; ref.read(aiChatMessagesProvider.notifier).add(AiChatMessage(displayedText, fromUser: true)); _input.clear(); _attachmentBytes = null; _attachmentName = null; _confirmation.cancel(); _undo = null; });
    final registry = _registry();
    try {
      final result = await ref.read(assistantEngineProvider).interpret(text, registry.actionNames, media: media);
      if (!mounted) return;
      if (result.kind == AssistantResultKind.clarification || result.kind == AssistantResultKind.answer) {
        setState(() => ref.read(aiChatMessagesProvider.notifier).add(AiChatMessage(result.message ?? 'يرجى التوضيح.')));
      } else if (result.kind == AssistantResultKind.notUnderstood || result.command == null) {
        setState(() => ref.read(aiChatMessagesProvider.notifier).add(AiChatMessage(strings.assistantNotUnderstood)));
        await _openManual();
      } else {
        final command = result.command!;
        final error = registry.validate(command.name, command.parameters);
        if (error != null) {
          setState(() => ref.read(aiChatMessagesProvider.notifier).add(AiChatMessage(strings.assistantNotUnderstood)));
          await _openManual();
        } else if (registry.descriptor(command.name)!.readOnly) {
          final execution = await registry.execute(command.name, command.parameters);
          if (mounted) setState(() => ref.read(aiChatMessagesProvider.notifier).add(AiChatMessage(execution.message)));
        } else {
          setState(() { _confirmation.request(command); ref.read(aiChatMessagesProvider.notifier).add(AiChatMessage(strings.assistantReview)); });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => ref.read(aiChatMessagesProvider.notifier).add(AiChatMessage(strings.assistantNotUnderstood)));
        await _openManual();
      }
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _confirm() async {
    if (!_confirmation.hasPending || _busy) return;
    final strings = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    try {
      final execution = await _confirmation.approve(
        (command) => _registry().execute(command.name, command.parameters),
      );
      if (execution == null) return;
      if (!mounted) return;
      setState(() { _undo = execution.undo; ref.read(aiChatMessagesProvider.notifier).add(AiChatMessage(execution.message)); });
    } catch (_) {
      if (mounted) setState(() { _confirmation.cancel(); ref.read(aiChatMessagesProvider.notifier).add(AiChatMessage(strings.assistantNotUnderstood)); });
      await _openManual();
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _undoLast() async {
    final undo = _undo;
    if (undo == null || _busy) return;
    setState(() => _busy = true);
    try { await undo(); if (mounted) setState(() { _undo = null; ref.read(aiChatMessagesProvider.notifier).add(AiChatMessage(AppLocalizations.of(context)!.assistantUndone)); }); }
    catch (_) { if (mounted) setState(() => ref.read(aiChatMessagesProvider.notifier).add(AiChatMessage(AppLocalizations.of(context)!.assistantUndoFailed))); }
    finally { if (mounted) setState(() => _busy = false); }
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

  String _displayAmount(AssistantCommand command) =>
      (command.parameters['amountMinorUnits'] ?? '—').toString();

  String _displayMonth(AssistantCommand command) {
    final year = command.parameters['year']; final month = command.parameters['month'];
    if (year is int && month is int) return year.toString() + '-' + month.toString().padLeft(2, '0');
    final now = DateTime.now();
    return now.year.toString() + '-' + now.month.toString().padLeft(2, '0');
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final pending = _confirmation.pending;
    final messages = ref.watch(aiChatMessagesProvider);
    return Scaffold(
      body: Column(children: [
        Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [
          for (var i = 0; i < messages.length; i++)
            Align(alignment: messages[i].fromUser ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
              child: AnimatedSize(duration: const Duration(milliseconds: 220), curve: Curves.easeOut, child: Card(
                color: messages[i].fromUser ? Theme.of(context).colorScheme.secondaryContainer : null,
                child: Padding(padding: const EdgeInsets.all(12), child: Text(messages[i].text)),
              )),
            ),
          if (pending != null) AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: Card(
            key: ValueKey(pending.name + pending.parameters.toString()),
            child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(strings.assistantConfirm, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(strings.assistantSection + ': ' + _sectionName(pending.name, strings)),
              Text(strings.assistantOperation + ': ' + _operationName(pending.name, strings)),
              Text(strings.assistantAmount + ': ' + _displayAmount(pending)),
              if (pending.parameters['id'] is String)
                Text(pending.parameters['id']! as String),
              if (pending.parameters['title'] is String)
                Text(pending.parameters['title']! as String),
              if (pending.parameters['counterparty'] is String)
                Text(pending.parameters['counterparty']! as String),
              if (pending.parameters['categoryId'] is String)
                Text(pending.parameters['categoryId']! as String),
              if (pending.parameters['kind'] is String)
                Text(pending.parameters['kind']! as String),
              if (pending.parameters['direction'] is String)
                Text(pending.parameters['direction']! as String),
              if (pending.parameters['billId'] is String)
                Text(pending.parameters['billId']! as String),
              if (pending.parameters['debtId'] is String)
                Text(pending.parameters['debtId']! as String),
              Text(strings.assistantMonth + ': ' + _displayMonth(pending)),
              Text(strings.assistantDate + ': ' + (pending.parameters['date']?.toString() ?? DateTime.now().toIso8601String().split('T').first)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, children: [
                FilledButton(onPressed: _busy ? null : _confirm, child: Text(strings.assistantApprove)),
                TextButton(onPressed: _busy ? null : () => setState(_confirmation.cancel), child: Text(strings.cancel)),
              ]),
            ])),
          )),
          if (_undo != null) Align(alignment: AlignmentDirectional.centerStart, child: TextButton.icon(onPressed: _busy ? null : _undoLast, icon: const Icon(Icons.undo), label: Text(strings.assistantUndo))),
        ])),
        if (_attachmentName != null || _recording)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(children: [
              Icon(_recording ? Icons.mic : (_attachmentIsImage ? Icons.image : Icons.audio_file)),
              const SizedBox(width: 8),
              Expanded(child: Text(_recording ? strings.aiRecording : _attachmentName!)),
              if (!_recording) IconButton(onPressed: _busy ? null : _removeAttachment, icon: const Icon(Icons.close), tooltip: strings.aiRemoveAttachment),
            ]),
          ),
        SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(8, 8, 8, 12), child: Row(children: [
          IconButton(onPressed: _busy || _recording ? null : _chooseAttachment, icon: const Icon(Icons.attach_file), tooltip: strings.aiAttachImage),
          IconButton(onPressed: _busy ? null : _toggleRecording, icon: Icon(_recording ? Icons.stop_circle_outlined : Icons.mic_none), tooltip: _recording ? strings.aiStopRecording : strings.aiRecordAudio),
          Expanded(child: TextField(controller: _input, textInputAction: TextInputAction.send, onSubmitted: (_) => _send(), decoration: InputDecoration(
            hintText: strings.assistantHint,
            isDense: true,
            constraints: const BoxConstraints(minHeight: 48, maxHeight: 48),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(28)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28)),
          ))),
          const SizedBox(width: 4),
          IconButton.filled(onPressed: _busy || _recording ? null : _send, tooltip: strings.assistantSend, icon: _busy ? const SizedBox(width: 18,height: 18,child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send)),
        ]))),
      ]),
    );
  }
}
