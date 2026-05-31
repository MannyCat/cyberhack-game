import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/game/game_shell.dart';
import 'screens/game/dashboard_screen.dart';
import 'screens/game/servers_screen.dart';
import 'screens/game/operations_screen.dart';
import 'screens/game/agents_screen.dart';
import 'screens/game/research_screen.dart';
import 'screens/game/targets_screen.dart';
import 'screens/game/market_screen.dart';
import 'screens/game/cartel_screen.dart';
import 'screens/game/chat_screen.dart';
import 'screens/game/leaderboard_screen.dart';
import 'screens/game/profile_screen.dart';
import 'screens/game/settings_screen.dart';

final _routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);
  final isLoggedIn = authState.valueOrNull != null;

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/game/dashboard';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => GameShell(child: child),
        routes: [
          GoRoute(
            path: '/game',
            redirect: (context, state) => '/game/dashboard',
          ),
          GoRoute(
            path: '/game/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/game/servers',
            builder: (context, state) => const ServersScreen(),
          ),
          GoRoute(
            path: '/game/operations',
            builder: (context, state) => const OperationsScreen(),
          ),
          GoRoute(
            path: '/game/agents',
            builder: (context, state) => const AgentsScreen(),
          ),
          GoRoute(
            path: '/game/research',
            builder: (context, state) => const ResearchScreen(),
          ),
          GoRoute(
            path: '/game/targets',
            builder: (context, state) => const TargetsScreen(),
          ),
          GoRoute(
            path: '/game/market',
            builder: (context, state) => const MarketScreen(),
          ),
          GoRoute(
            path: '/game/cartel',
            builder: (context, state) => const CartelScreen(),
          ),
          GoRoute(
            path: '/game/chat',
            builder: (context, state) => const ChatScreen(),
          ),
          GoRoute(
            path: '/game/leaderboard',
            builder: (context, state) => const LeaderboardScreen(),
          ),
          GoRoute(
            path: '/game/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/game/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});

class CyberHackApp extends ConsumerWidget {
  const CyberHackApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'CyberHack Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0a0e17),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00ff88),
          secondary: Color(0xFF00d4ff),
          surface: Color(0xFF111827),
          onPrimary: Color(0xFF000000),
          onSecondary: Color(0xFF000000),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFFe0e0e0)),
          bodyMedium: TextStyle(color: Color(0xFFb0b0b0)),
          titleLarge: TextStyle(
            color: Color(0xFF00ff88),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      routerConfig: ref.read(_routerProvider),
    );
  }
}
