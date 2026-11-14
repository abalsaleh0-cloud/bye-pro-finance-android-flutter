import 'package:material_ui/material_ui.dart';

/// Shared shell for add/edit forms across the work and home sections.
class EntryFormDialog extends StatelessWidget {
  const EntryFormDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
  });

  final Widget title;
  final Widget content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      actionsAlignment: MainAxisAlignment.end,
      title: title,
      content: content,
      actions: actions,
    );
  }
}
