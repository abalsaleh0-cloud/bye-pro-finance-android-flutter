import 'package:expense_app/features/ai/presentation/ai_screen.dart';
import 'package:expense_app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:expense_app/features/debts/presentation/debts_screen.dart';
import 'package:expense_app/features/home/presentation/home_screen.dart';
import 'package:expense_app/features/settings/presentation/settings_screen.dart';
import 'package:expense_app/features/shell/presentation/app_shell.dart';
import 'package:expense_app/features/work/presentation/work_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = createAppRouter();
  ref.onDispose(router.dispose);
  return router;
});

GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: '/dashboard',
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(
          location: state.uri.path,
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/work',
            builder: (context, state) => const WorkScreen(),
          ),
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/debts',
            builder: (context, state) => const DebtsScreen(),
          ),
          GoRoute(
            path: '/ai',
            builder: (context, state) => const AiScreen(),
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
