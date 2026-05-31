import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/game_provider.dart';
import '../../widgets/resource_bar.dart';

// ── Color Constants ──────────────────────────────────────────────────────

const _bgDark = Color(0xFF0a0e17);
const _surface = Color(0xFF111827);
const _surfaceVariant = Color(0xFF1a2332);
const _greenPrimary = Color(0xFF00ff88);
const _cyanSecondary = Color(0xFF00d4ff);
const _dangerRed = Color(0xFFff4444);

class GameShell extends ConsumerStatefulWidget {
  final Widget child;
  const GameShell({super.key, required this.child});

  @override
  ConsumerState<GameShell> createState() => _GameShellState();
}

class _GameShellState extends ConsumerState<GameShell> {
  // Navigation items grouped by category
  static const _mainItems = [
    {'icon': Icons.dashboard, 'label': 'Дашборд', 'route': '/game/dashboard'},
    {'icon': Icons.dns_outlined, 'label': 'Серверы', 'route': '/game/servers'},
    {'icon': Icons.explore, 'label': 'Операции', 'route': '/game/operations'},
    {'icon': Icons.people, 'label': 'Агенты', 'route': '/game/agents'},
    {'icon': Icons.science, 'label': 'Исследования', 'route': '/game/research'},
    {'icon': Icons.my_location, 'label': 'Цели', 'route': '/game/targets'},
  ];

  static const _socialItems = [
    {'icon': Icons.store, 'label': 'Рынок', 'route': '/game/market'},
    {'icon': Icons.group, 'label': 'Картель', 'route': '/game/cartel'},
    {'icon': Icons.chat, 'label': 'Чат', 'route': '/game/chat'},
  ];

  static const _otherItems = [
    {'icon': Icons.emoji_events, 'label': 'Рейтинг', 'route': '/game/leaderboard'},
    {'icon': Icons.person, 'label': 'Профиль', 'route': '/game/profile'},
    {'icon': Icons.settings, 'label': 'Настройки', 'route': '/game/settings'},
  ];

  String _currentRoute = '/game/dashboard';

  @override
  void initState() {
    super.initState();
    // Detect initial route after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _detectCurrentRoute();
    });
  }

  /// Detects the current route from GoRouter and updates the sidebar highlight.
  void _detectCurrentRoute() {
    final router = GoRouterState.of(context);
    final fullMatch = router.fullPath;
    if (fullMatch != null) {
      setState(() {
        _currentRoute = fullMatch;
      });
    } else {
      final uri = router.uri.toString();
      if (uri.isNotEmpty) {
        setState(() {
          _currentRoute = uri;
        });
      }
    }
  }

  /// Checks if a route matches the current location.
  bool _isSelected(String route) {
    return _currentRoute.startsWith(route);
  }

  /// Finds the index of the currently selected item across all groups.
  int _getSelectedIndex() {
    final allRoutes = [
      ..._mainItems.map((e) => e['route'] as String),
      ..._socialItems.map((e) => e['route'] as String),
      ..._otherItems.map((e) => e['route'] as String),
    ];
    for (int i = 0; i < allRoutes.length; i++) {
      if (_isSelected(allRoutes[i])) return i;
    }
    return 0;
  }

  /// Navigates to the given route and refreshes game data.
  void _onNavigate(String route) {
    if (_currentRoute == route) return;
    context.go(route);
    setState(() {
      _currentRoute = route;
    });
    // Refresh game data on tab switch
    ref.read(gameProvider.notifier).loadAllData();
  }

  /// Handles logout.
  void _onLogout() {
    ref.read(authProvider.notifier).logout();
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(gameProvider);
    final profile = game.profile;
    final username = profile?['username'] as String? ?? 'Хакер';

    return Scaffold(
      body: Container(
        color: _bgDark,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Left Sidebar ────────────────────────────────────────────
            _buildSidebar(username),
            // ── Right Content Area ──────────────────────────────────────
            Expanded(
              child: Column(
                children: [
                  // Top resource bar
                  const ResourceBar(),
                  // Main content
                  Expanded(
                    child: Container(
                      color: _bgDark,
                      child: widget.child,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sidebar Widget ─────────────────────────────────────────────────────

  Widget _buildSidebar(String username) {
    return Container(
      width: 240,
      color: _surface,
      child: Column(
        children: [
          // Logo area
          _buildLogoArea(username),
          const SizedBox(height: 8),
          // Scrollable navigation area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main navigation group
                  _buildSectionLabel('НАВИГАЦИЯ'),
                  ..._mainItems.map((item) => _buildNavItem(
                        icon: item['icon'] as IconData,
                        label: item['label'] as String,
                        route: item['route'] as String,
                      )),
                  const Divider(color: _surfaceVariant, height: 24),
                  // Social group
                  _buildSectionLabel('СОЦИАЛЬНОЕ'),
                  ..._socialItems.map((item) => _buildNavItem(
                        icon: item['icon'] as IconData,
                        label: item['label'] as String,
                        route: item['route'] as String,
                      )),
                  const Divider(color: _surfaceVariant, height: 24),
                  // Other group
                  _buildSectionLabel('ПРОЧЕЕ'),
                  ..._otherItems.map((item) => _buildNavItem(
                        icon: item['icon'] as IconData,
                        label: item['label'] as String,
                        route: item['route'] as String,
                      )),
                ],
              ),
            ),
          ),
          // Logout button at the bottom
          _buildLogoutButton(),
        ],
      ),
    );
  }

  // ── Logo / Title Area ─────────────────────────────────────────────────

  Widget _buildLogoArea(String username) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _surfaceVariant, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _greenPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _greenPrimary.withValues(alpha: 0.3)),
                ),
                child: const Icon(
                  Icons.security,
                  color: _greenPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'CYBERHACK',
                style: TextStyle(
                  color: _greenPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.person_outline,
                color: Colors.grey.shade500,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                username,
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Section Label ─────────────────────────────────────────────────────

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  // ── Navigation Item ───────────────────────────────────────────────────

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required String route,
  }) {
    final selected = _isSelected(route);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => _onNavigate(route),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: selected
                  ? _greenPrimary.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: selected
                    ? _greenPrimary.withValues(alpha: 0.3)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Green left border indicator when selected
                Container(
                  width: 3,
                  height: 32,
                  decoration: BoxDecoration(
                    color: selected ? _greenPrimary : Colors.transparent,
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  icon,
                  color: selected ? _greenPrimary : Colors.grey.shade500,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected ? _greenPrimary : Colors.grey.shade400,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Logout Button ─────────────────────────────────────────────────────

  Widget _buildLogoutButton() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: _surfaceVariant, width: 1),
        ),
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: _onLogout,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.logout, color: _dangerRed, size: 18),
                SizedBox(width: 8),
                Text(
                  'ВЫХОД',
                  style: TextStyle(
                    color: _dangerRed,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
