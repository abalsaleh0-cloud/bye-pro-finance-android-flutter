import 'package:expense_app/core/database/database_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  bool _saving = false;

  Future<void> _continue() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(appDatabaseProvider).writeSetting('welcome_seen', 'true');
    } catch (_) {
      // Navigation remains available even if the welcome flag cannot be saved.
    }
    if (mounted) context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isEnglish = Localizations.localeOf(context).languageCode == 'en';

    // This route is now reached only after the router confirms a first launch.
    // Returning users are routed directly to the dashboard before this widget
    // is ever built.
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 24),
                    Container(
                      width: 116,
                      height: 116,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.primaryContainer,
                        border: Border.all(color: scheme.secondary, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: scheme.primary.withValues(alpha: .16),
                            blurRadius: 32,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 54,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(height: 34),
                    Text(
                      'BYE PRO',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.2,
                            color: scheme.onSurface,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isEnglish ? 'Welcome to your financial space' : 'مرحباً بك في مساحتك المالية',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                          ),
                    ),
                    const SizedBox(height: 14),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 340),
                      child: Text(
                        isEnglish
                            ? 'A clearer view of your income, expenses and financial commitments — all in one place.'
                            : 'رؤية أوضح لدخلك ومصروفاتك والتزاماتك المالية، وكل تفاصيلك في مكان واحد.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              height: 1.8,
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                    const SizedBox(height: 42),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton(
                        onPressed: _saving ? null : _continue,
                        child: _saving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                isEnglish ? 'Get started' : 'ابدأ الآن',
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      isEnglish ? 'Your money. Your clarity.' : 'أموالك… بوضوح واطمئنان',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            letterSpacing: .4,
                          ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
