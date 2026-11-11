import 'package:material_ui/material_ui.dart';
import 'package:expense_app/l10n/generated/app_localizations.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;
  Locale _locale = const Locale('ar');

  void _setDarkMode(bool enabled) {
    setState(() {
      _themeMode = enabled ? ThemeMode.dark : ThemeMode.light;
    });
  }

  void _setLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appName,
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF536B91),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF536B91),
          brightness: Brightness.dark,
        ),
      ),
      locale: _locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: HomeShell(
        themeMode: _themeMode,
        locale: _locale,
        onThemeChanged: _setDarkMode,
        onLocaleChanged: _setLocale,
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({
    required this.themeMode,
    required this.locale,
    required this.onThemeChanged,
    required this.onLocaleChanged,
    super.key,
  });

  final ThemeMode themeMode;
  final Locale locale;
  final ValueChanged<bool> onThemeChanged;
  final ValueChanged<Locale> onLocaleChanged;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  static const _icons = <IconData>[
    Icons.dashboard_outlined,
    Icons.work_outline,
    Icons.home_outlined,
    Icons.account_balance_wallet_outlined,
    Icons.auto_awesome_outlined,
  ];

  String _titleFor(AppLocalizations strings, int index) {
    return [
      strings.dashboard,
      strings.work,
      strings.homeSection,
      strings.debts,
      strings.ai,
    ][index];
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final title = _titleFor(strings, _selectedIndex);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            key: const Key('open-settings'),
            tooltip: strings.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SettingsScreen(
                    themeMode: widget.themeMode,
                    locale: widget.locale,
                    onThemeChanged: widget.onThemeChanged,
                    onLocaleChanged: widget.onLocaleChanged,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final offset = Tween<Offset>(
            begin: const Offset(0.035, 0),
            end: Offset.zero,
          ).animate(animation);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: offset, child: child),
          );
        },
        child: SectionPlaceholder(
          key: ValueKey<int>(_selectedIndex),
          icon: _icons[_selectedIndex],
          title: title,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: [
          NavigationDestination(
            icon: Icon(_icons[0]),
            label: strings.dashboard,
          ),
          NavigationDestination(icon: Icon(_icons[1]), label: strings.work),
          NavigationDestination(
            icon: Icon(_icons[2]),
            label: strings.homeSection,
          ),
          NavigationDestination(icon: Icon(_icons[3]), label: strings.debts),
          NavigationDestination(icon: Icon(_icons[4]), label: strings.ai),
        ],
      ),
    );
  }
}

class SectionPlaceholder extends StatelessWidget {
  const SectionPlaceholder({
    required this.icon,
    required this.title,
    super.key,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    required this.themeMode,
    required this.locale,
    required this.onThemeChanged,
    required this.onLocaleChanged,
    super.key,
  });

  final ThemeMode themeMode;
  final Locale locale;
  final ValueChanged<bool> onThemeChanged;
  final ValueChanged<Locale> onLocaleChanged;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(strings.settings)),
      body: ListView(
        children: [
          SwitchListTile(
            key: const Key('dark-mode-switch'),
            title: Text(strings.darkTheme),
            secondary: const Icon(Icons.dark_mode_outlined),
            value: themeMode == ThemeMode.dark,
            onChanged: onThemeChanged,
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.language_outlined),
            title: Text(strings.language),
            trailing: DropdownButton<Locale>(
              key: const Key('language-selector'),
              value: locale,
              underline: const SizedBox.shrink(),
              items: [
                DropdownMenuItem(
                  value: const Locale('ar'),
                  child: Text(strings.arabic),
                ),
                DropdownMenuItem(
                  value: const Locale('en'),
                  child: Text(strings.english),
                ),
              ],
              onChanged: (value) {
                if (value != null) onLocaleChanged(value);
              },
            ),
          ),
        ],
      ),
    );
  }
}
