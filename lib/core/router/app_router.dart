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
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final offset = Tween<Offset>(
        begin: const Offset(0.025, 0),
        end: Offset.zero,
      ).animate(animation);
      return FadeTransition(
        opacity: animation,
        child: SlideTransition(position: offset, child: child),
      );
    },
  );
}

GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: '/dashboard',
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            pageBuilder: (context, state) =>
                _sectionPage(state: state, child: const DashboardScreen()),
          ),
          GoRoute(
            path: '/work',
            pageBuilder: (context, state) =>
                _sectionPage(state: state, child: const WorkScreen()),
          ),
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) =>
                _sectionPage(state: state, child: const HomeScreen()),
          ),
          GoRoute(
            path: '/debts',
            pageBuilder: (context, state) =>
                _sectionPage(state: state, child: const DebtsScreen()),
          ),
          GoRoute(
            path: '/ai',
            pageBuilder: (context, state) =>
                _sectionPage(state: state, child: const AiScreen()),
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
