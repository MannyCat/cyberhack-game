import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers/auth_provider.dart';
import 'providers/game_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/main_menu_screen.dart';
import 'screens/game/game_shell.dart';
import 'screens/game/map_screen.dart';
import 'screens/game/network_screen.dart';
import 'screens/game/attack_screen.dart';
import 'screens/game/market_screen.dart';
import 'screens/game/chat_screen.dart';
import 'screens/game/clan_screen.dart';
import 'screens/game/leaderboard_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/profile_screen.dart';

class CyberHackApp extends StatefulWidget {
  const CyberHackApp({super.key});

  @override
  State<CyberHackApp> createState() => _CyberHackAppState();
}

class _CyberHackAppState extends State<CyberHackApp> {
  final _router = GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isLoggedIn = session != null;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/main_menu';
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
      GoRoute(
        path: '/main_menu',
        builder: (context, state) => const MainMenuScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => GameShell(child: child),
        routes: [
          GoRoute(
            path: '/game/map',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: GameMapScreen(),
            ),
          ),
          GoRoute(
            path: '/game/network',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: NetworkOverviewScreen(),
            ),
          ),
          GoRoute(
            path: '/game/attack',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AttackScreen(),
            ),
          ),
          GoRoute(
            path: '/game/market',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: MarketScreen(),
            ),
          ),
          GoRoute(
            path: '/game/chat',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ChatScreen(),
            ),
          ),
          GoRoute(
            path: '/game/clan',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ClanScreen(),
            ),
          ),
          GoRoute(
            path: '/game/leaderboard',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: LeaderboardScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => ProfileScreen(
          profile: PlayerProfileData(id: '', handle: 'Unknown'),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => GameProvider()),
      ],
      child: MaterialApp.router(
        title: 'CyberHack',
        debugShowCheckedModeBanner: false,
        routerConfig: _router,
        theme: _buildCyberpunkTheme(),
        darkTheme: _buildCyberpunkTheme(),
        themeMode: ThemeMode.dark,
      ),
    );
  }

  ThemeData _buildCyberpunkTheme() {
    const colorScheme = ColorScheme.dark(
      brightness: Brightness.dark,
      primary: Color(0xFF00F0FF),       // Neon cyan
      onPrimary: Color(0xFF001519),
      primaryContainer: Color(0xFF003940),
      onPrimaryContainer: Color(0xFF00F0FF),
      secondary: Color(0xFFFF00E5),     // Neon pink/magenta
      onSecondary: Color(0xFF1A0014),
      secondaryContainer: Color(0xFF5C004F),
      onSecondaryContainer: Color(0xFFFF80F0),
      tertiary: Color(0xFF39FF14),      // Neon green
      onTertiary: Color(0xFF001A00),
      tertiaryContainer: Color(0xFF003300),
      onTertiaryContainer: Color(0xFF39FF14),
      error: Color(0xFFFF1744),
      onError: Color(0xFFFFFFFF),
      errorContainer: Color(0xFF5C0011),
      onErrorContainer: Color(0xFFFFB3BA),
      surface: Color(0xFF0A0E17),       // Deep dark blue-black
      onSurface: Color(0xFFE0E6F0),
      surfaceContainerHighest: Color(0xFF1A2030),
      outline: Color(0xFF3A4060),
      outlineVariant: Color(0xFF2A3050),
      shadow: Color(0xFF000000),
      inverseSurface: Color(0xFFE0E6F0),
      inversePrimary: Color(0xFF006874),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF0A0E17),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0D1220),
        foregroundColor: Color(0xFF00F0FF),
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Color(0xFF00F0FF),
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF111827),
        elevation: 4,
        shadowColor: const Color(0xFF00F0FF).withValues(alpha: 0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: const Color(0xFF00F0FF).withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00F0FF),
          foregroundColor: const Color(0xFF0A0E17),
          elevation: 4,
          shadowColor: const Color(0xFF00F0FF).withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF00F0FF),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF00F0FF),
          side: const BorderSide(color: Color(0xFF00F0FF), width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF111827),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF2A3050)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: const Color(0xFF00F0FF).withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: Color(0xFF00F0FF),
            width: 2,
          ),
        ),
        hintStyle: TextStyle(
          color: const Color(0xFF3A4060),
          fontSize: 14,
        ),
        labelStyle: const TextStyle(
          color: Color(0xFF00F0FF),
          fontSize: 14,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF0D1220),
        selectedItemColor: Color(0xFF00F0FF),
        unselectedItemColor: Color(0xFF3A4060),
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
        unselectedLabelStyle: TextStyle(fontSize: 11),
        elevation: 8,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: Color(0xFF00F0FF),
          fontSize: 32,
          fontWeight: FontWeight.bold,
          letterSpacing: 3,
        ),
        headlineMedium: TextStyle(
          color: Color(0xFF00F0FF),
          fontSize: 24,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
        headlineSmall: TextStyle(
          color: Color(0xFFE0E6F0),
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
        titleLarge: TextStyle(
          color: Color(0xFFE0E6F0),
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
        titleMedium: TextStyle(
          color: Color(0xFFE0E6F0),
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(
          color: Color(0xFFC0C8D8),
          fontSize: 16,
        ),
        bodyMedium: TextStyle(
          color: Color(0xFFA0A8B8),
          fontSize: 14,
        ),
        bodySmall: TextStyle(
          color: Color(0xFF8090A0),
          fontSize: 12,
        ),
        labelLarge: TextStyle(
          color: Color(0xFF00F0FF),
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
        labelMedium: TextStyle(
          color: Color(0xFF8090A0),
          fontSize: 12,
        ),
      ),
      iconTheme: const IconThemeData(
        color: Color(0xFF00F0FF),
        size: 24,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF1A2030),
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF111827),
        contentTextStyle: const TextStyle(color: Color(0xFFE0E6F0)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: const Color(0xFF00F0FF).withValues(alpha: 0.3),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF111827),
        titleTextStyle: const TextStyle(
          color: Color(0xFF00F0FF),
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
        contentTextStyle: const TextStyle(
          color: Color(0xFFC0C8D8),
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: const Color(0xFF00F0FF).withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }
}
