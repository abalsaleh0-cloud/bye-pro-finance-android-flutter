import 'package:expense_app/features/shared/presentation/section_placeholder.dart';
import 'package:expense_app/l10n/generated/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return SectionPlaceholder(
      icon: Icons.home_outlined,
      title: strings.homeSection,
    );
  }
}
