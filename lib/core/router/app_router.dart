import 'package:expense_app/features/ai/presentation/ai_screen.dart';
import 'package:expense_app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:expense_app/features/debts/presentation/debts_screen.dart';
import 'package:expense_app/features/home/presentation/home_screen.dart';
import 'package:expense_app/features/settings/presentation/settings_screen.dart';
import 'package:expense_app/features/shell/presentation/app_shell.dart';
import 'package:expense_app/features/work/presentation/work_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = createAppRouter();
  ref.onDispose(router.dispose);
  return router;
});

CustomTransitionPage<void> _sectionPage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    // Tab destinations are kept alive by StatefulShellRoute.indexedStack.
    // Zero-duration branch transitions avoid an inactive fade/ignore-pointer
    // snapshot intercepting taps on the newly selected destination.
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        child,
  );
}

GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: '/dashboard',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(
          location: state.uri.path,
          navigationShell: navigationShell,
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                pageBuilder: (context, state) =>
                    _sectionPage(state: state, child: const DashboardScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/work',
                pageBuilder: (context, state) => _sectionPage(
                  state: state,
                  child: WorkScreen(openManualEntry: state.extra == true),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                pageBuilder: (context, state) => _sectionPage(
                  state: state,
                  child: HomeScreen(openManualEntry: state.extra == true),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/debts',
                pageBuilder: (context, state) => _sectionPage(
                  state: state,
                  child: DebtsScreen(openManualEntry: state.extra == true),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/ai',
                pageBuilder: (context, state) =>
                    _sectionPage(state: state, child: const AiScreen()),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
}
