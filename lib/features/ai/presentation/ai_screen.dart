// ignore_for_file: curly_braces_in_flow_control_structures, prefer_interpolation_to_compose_strings

import 'package:expense_app/core/database/database_providers.dart';
import 'package:expense_app/features/ai/domain/action_registry.dart';
import 'package:expense_app/features/ai/domain/assistant_engine.dart';
import 'package:expense_app/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

final assistantEngineProvider = Provider<AssistantEngine>((ref) => const FakeAssistantEngine());

final class _ChatMessage {
  const _ChatMessage(this.text, {this.fromUser = false});
  final String text;
  final bool fromUser;
}

class AiScreen extends ConsumerStatefulWidget {
  const AiScreen({super.key});
  @override
  ConsumerState<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends ConsumerState<AiScreen> {
  final _input = TextEditingController();
  final List<_ChatMessage> _messages = [];
  AssistantCommand? _pending;
  UndoOperation? _undo;
  bool _busy = false;

  @override
  void dispose() { _input.dispose(); super.dispose(); }

  ActionRegistry _registry() => ActionRegistry(
    work: ref.read(workRepositoryProvider),
    home: ref.read(homeExpenseRepositoryProvider),
    debts: ref.read(debtRepositoryProvider),
  );

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() { _busy = true; _messages.add(_ChatMessage(text, fromUser: true)); _input.clear(); _pending = null; _undo = null; });
    final registry = _registry();
    try {
      final result = await ref.read(assistantEngineProvider).interpret(text, registry.actionNames);
      if (!mounted) return;
      if (result.kind == AssistantResultKind.clarification) {
        setState(() => _messages.add(_ChatMessage(result.message ?? 'يرجى التوضيح.')));
      } else if (result.kind == AssistantResultKind.notUnderstood || result.command == null) {
        setState(() => _messages.add(_ChatMessage(AppLocalizations.of(context)!.assistantNotUnderstood)));
        await _openManual();
      } else {
        final command = result.command!;
        final error = registry.validate(command.name, command.parameters);
        if (error != null) {
          setState(() => _messages.add(_ChatMessage(AppLocalizations.of(context)!.assistantNotUnderstood)));
          await _openManual();
        } else if (registry.descriptor(command.name)!.readOnly) {
          final execution = await registry.execute(command.name, command.parameters);
          if (mounted) setState(() => _messages.add(_ChatMessage(execution.message)));
        } else {
          setState(() { _pending = command; _messages.add(_ChatMessage(AppLocalizations.of(context)!.assistantReview)); });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _messages.add(_ChatMessage(AppLocalizations.of(context)!.assistantNotUnderstood)));
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _confirm() async {
    final command = _pending;
    if (command == null || _busy) return;
    setState(() => _busy = true);
    try {
      final execution = await _registry().execute(command.name, command.parameters);
      if (!mounted) return;
      setState(() { _pending = null; _undo = execution.undo; _messages.add(_ChatMessage(execution.message)); });
    } catch (_) {
      if (mounted) setState(() { _pending = null; _messages.add(_ChatMessage(AppLocalizations.of(context)!.assistantNotUnderstood)); });
      await _openManual();
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _undoLast() async {
    final undo = _undo;
    if (undo == null || _busy) return;
    setState(() => _busy = true);
    try { await undo(); if (mounted) setState(() { _undo = null; _messages.add(_ChatMessage(AppLocalizations.of(context)!.assistantUndone)); }); }
    catch (_) { if (mounted) setState(() => _messages.add(_ChatMessage(AppLocalizations.of(context)!.assistantUndoFailed))); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _openManual() async {
    if (!mounted) return;
    final strings = AppLocalizations.of(context)!;
    final section = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(title: Text(strings.assistantManual), onTap: () => Navigator.pop(context, '/dashboard')),
        ListTile(leading: const Icon(Icons.work_outline), title: Text(strings.work), onTap: () => Navigator.pop(context, '/work')),
        ListTile(leading: const Icon(Icons.home_outlined), title: Text(strings.homeSection), onTap: () => Navigator.pop(context, '/home')),
        ListTile(leading: const Icon(Icons.account_balance_wallet_outlined), title: Text(strings.debts), onTap: () => Navigator.pop(context, '/debts')),
      ])),
    );
    if (section != null && mounted) context.go(section);
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
    final pending = _pending;
    return Scaffold(
      body: Column(children: [
        Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [
          if (_messages.isEmpty) Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(strings.assistantWelcome))),
          for (var i = 0; i < _messages.length; i++)
            Align(alignment: _messages[i].fromUser ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
              child: AnimatedSize(duration: const Duration(milliseconds: 220), curve: Curves.easeOut, child: Card(
                color: _messages[i].fromUser ? Theme.of(context).colorScheme.secondaryContainer : null,
                child: Padding(padding: const EdgeInsets.all(12), child: Text(_messages[i].text)),
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
              Text(strings.assistantMonth + ': ' + _displayMonth(pending)),
              Text(strings.assistantDate + ': ' + (pending.parameters['date']?.toString() ?? DateTime.now().toIso8601String().split('T').first)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, children: [
                FilledButton(onPressed: _busy ? null : _confirm, child: Text(strings.assistantApprove)),
                TextButton(onPressed: _busy ? null : () => setState(() => _pending = null), child: Text(strings.cancel)),
              ]),
            ])),
          )),
          if (_undo != null) Align(alignment: AlignmentDirectional.centerStart, child: TextButton.icon(onPressed: _busy ? null : _undoLast, icon: const Icon(Icons.undo), label: Text(strings.assistantUndo))),
        ])),
        SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 12), child: Row(children: [
          Expanded(child: TextField(controller: _input, textInputAction: TextInputAction.send, onSubmitted: (_) => _send(), decoration: InputDecoration(hintText: strings.assistantHint, border: const OutlineInputBorder()))),
          const SizedBox(width: 8),
          IconButton.filled(onPressed: _busy ? null : _send, tooltip: strings.assistantSend, icon: _busy ? const SizedBox(width: 18,height: 18,child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send)),
        ]))),
      ]),
    );
  }
}