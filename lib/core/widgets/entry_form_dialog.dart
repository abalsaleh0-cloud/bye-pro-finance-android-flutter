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
      title: title,
      content: content,
      actions: actions,
    );
  }
}
