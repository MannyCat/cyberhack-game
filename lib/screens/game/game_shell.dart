import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/game_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/resource_bar.dart';

// ─── GameShell — PC Desktop Layout ───────────────────────────────────────────
// Left sidebar (240px, always visible) + Top resource bar + Main content area
// All text in Russian. Neon cyberpunk theme on Color(0xFF0a0e17).
// Uses go_router for navigation, Provider for state.

class GameShell extends StatefulWidget {
  final Widget child;

  const GameShell({super.key, required this.child});

  @override
  State<GameShell> createState() => _GameShellState();
}

class _GameShellState extends State<GameShell> {
  int _selectedIndex = 0;
  int _totalPlayers = 0;
  bool _fetchedPlayers = false;

  // ── Navigation definition ──────────────────────────────────────────────
  static const List<_SidebarSection> _sections = [
    _SidebarSection(
      label: 'НАВИГАЦИЯ',
      items: [
        _NavItem(icon: Icons.home_rounded, label: 'Главная', path: '/game/home', color: Color(0xFF00FF41)),
        _NavItem(icon: Icons.public_rounded, label: 'Карта мира', path: '/game/map', color: Color(0xFF00e5ff)),
        _NavItem(icon: Icons.dns_rounded, label: 'Сеть', path: '/game/network', color: Color(0xFF00e5ff)),
        _NavItem(icon: Icons.gps_fixed_rounded, label: 'Атака', path: '/game/attack', color: Color(0xFFFF0040)),
        _NavItem(icon: Icons.storefront_rounded, label: 'Магазин', path: '/game/market', color: Color(0xFFff9800)),
      ],
    ),
    _SidebarSection(
      label: 'СОЦИАЛЬНОЕ',
      items: [
        _NavItem(icon: Icons.groups_rounded, label: 'Клан', path: '/game/clan', color: Color(0xFFa855f7)),
        _NavItem(icon: Icons.chat_bubble_rounded, label: 'Чат', path: '/game/chat', color: Color(0xFF00e5ff)),
        _NavItem(icon: Icons.leaderboard_rounded, label: 'Рейтинг', path: '/game/leaderboard', color: Color(0xFFe91e63)),
      ],
    ),
    _SidebarSection(
      label: 'ПРОГРЕСС',
      items: [
        _NavItem(icon: Icons.card_giftcard_rounded, label: 'Ежедневное', path: '/game/daily-reward', color: Color(0xFFFFD700)),
        _NavItem(icon: Icons.military_tech_rounded, label: 'Кампания', path: '/game/campaign', color: Color(0xFFFFD700)),
        _NavItem(icon: Icons.event_rounded, label: 'События', path: '/game/events', color: Color(0xFF00e5ff)),
      ],
    ),
  ];

  /// Flat list of all nav items for index resolution.
  static List<_NavItem> get _allItems => _sections.expand((s) => s.items).toList();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchTotalPlayers();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final location = GoRouterState.of(context).matchedLocation;
    final index = _allItems.indexWhere((t) => location.startsWith(t.path));
    if (index != -1 && index != _selectedIndex) {
      setState(() => _selectedIndex = index);
    }
  }

  Future<void> _fetchTotalPlayers() async {
    try {
      final result = await Supabase.instance.client.from('profiles').select('id');
      if (mounted) {
        setState(() {
          _totalPlayers = result.length;
          _fetchedPlayers = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _fetchedPlayers = true);
    }
  }

  int get _incomingAttackCount {
    try {
      final auth = context.read<AuthProvider>();
      final game = context.read<GameProvider>();
      return game.attackHistory
          .where((a) => a.defenderId == auth.userId && a.status == 'pending')
          .length;
    } catch (_) {
      return 0;
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0e17),
      body: Row(
        children: [
          // ── LEFT SIDEBAR (always visible, 240 px) ──
          _buildSidebar(),
          // ── MAIN COLUMN: top bar + content ──
          Expanded(
            child: Column(
              children: [
                _buildTopBar(),
                // Content with max-width constraint for readability
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: widget.child,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // SIDEBAR
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildSidebar() {
    final badgeCount = _incomingAttackCount;

    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: Color(0xFF0d1220),
        border: Border(right: BorderSide(color: Color(0xFF1e2a3a), width: 1)),
        boxShadow: [
          BoxShadow(color: Color(0x20000000), blurRadius: 20, offset: Offset(4, 0)),
        ],
      ),
      child: Column(
        children: [
          // ── Logo header ──
          _buildSidebarHeader(),
          // ── Scrollable navigation sections ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final section in _sections) ...[
                    _buildSectionHeader(section.label),
                    for (int i = 0; i < section.items.length; i++) _buildNavItem(
                          item: section.items[i],
                          globalIndex: _allItems.indexOf(section.items[i]),
                          isSelected: _allItems.indexOf(section.items[i]) == _selectedIndex,
                          showBadge: section.items[i].path == '/game/attack' && badgeCount > 0,
                          badgeCount: badgeCount,
                        ),
                    const SizedBox(height: 6),
                  ],
                ],
              ),
            ),
          ),
          // ── Bottom actions ──
          _buildSidebarFooter(),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF1e2a3a))),
      ),
      child: Row(
        children: [
          // Cyber icon with neon ring
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF00F0FF).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF00F0FF).withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(color: const Color(0xFF00F0FF).withValues(alpha: 0.15), blurRadius: 8),
              ],
            ),
            child: const Icon(Icons.bolt_rounded, color: Color(0xFF00F0FF), size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'CYBERHACK',
              style: TextStyle(
                color: Color(0xFF00F0FF),
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 3.5,
                fontFamily: 'monospace',
                shadows: [Shadow(color: Color(0x8000F0FF), blurRadius: 12)],
              ),
            ),
          ),
          // Online player count pill
          if (_fetchedPlayers && _totalPlayers > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF39FF14).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF39FF14).withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: const Color(0xFF39FF14),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF39FF14).withValues(alpha: 0.6), blurRadius: 6),
                      ],
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '$_totalPlayers',
                    style: const TextStyle(
                      color: Color(0xFF39FF14),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 16, top: 12, bottom: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF3a4555),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required _NavItem item,
    required int globalIndex,
    required bool isSelected,
    bool showBadge = false,
    int badgeCount = 0,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            // Neon glow for active item
            color: isSelected
                ? item.color.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border(left: BorderSide(color: item.color, width: 3))
                : null,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: item.color.withValues(alpha: 0.25),
                      blurRadius: 12,
                      spreadRadius: -2,
                      offset: const Offset(-2, 0),
                    ),
                  ]
                : [],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() => _selectedIndex = globalIndex);
                context.go(item.path);
              },
              borderRadius: BorderRadius.circular(8),
              hoverColor: isSelected
                  ? item.color.withValues(alpha: 0.18)
                  : const Color(0xFF1e2a3a).withValues(alpha: 0.5),
              splashColor: item.color.withValues(alpha: 0.08),
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    // Icon with optional badge
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? item.color.withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            item.icon,
                            size: 18,
                            color: isSelected ? item.color : const Color(0xFF5a6578),
                          ),
                        ),
                        if (showBadge)
                          Positioned(
                            right: -6,
                            top: -4,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF0040),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF0040).withValues(alpha: 0.6),
                                    blurRadius: 6,
                                  ),
                                ],
                                border: Border.all(
                                  color: const Color(0xFF0d1220),
                                  width: 2,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                badgeCount > 9 ? '9+' : '$badgeCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 7,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    // Label
                    Expanded(
                      child: Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? item.color : const Color(0xFF6a7080),
                          letterSpacing: 0.3,
                          shadows: isSelected
                              ? [Shadow(color: item.color.withValues(alpha: 0.4), blurRadius: 8)]
                              : [],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Active indicator dot
                    if (isSelected)
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: item.color,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: item.color.withValues(alpha: 0.6),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarFooter() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF1e2a3a))),
      ),
      child: Column(
        children: [
          _buildFooterTile(
            icon: Icons.person_rounded,
            label: 'Профиль',
            color: const Color(0xFF78909c),
            path: '/profile',
          ),
          _buildFooterTile(
            icon: Icons.settings_rounded,
            label: 'Настройки',
            color: const Color(0xFF4a5568),
            path: '/settings',
          ),
          _buildFooterTile(
            icon: Icons.logout_rounded,
            label: 'Выход',
            color: const Color(0xFFFF1744),
            path: '', // special handling
            isLogout: true,
          ),
        ],
      ),
    );
  }

  Widget _buildFooterTile({
    required IconData icon,
    required String label,
    required Color color,
    required String path,
    bool isLogout = false,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (isLogout) {
              Supabase.instance.client.auth.signOut();
            } else {
              context.go(path);
            }
          },
          hoverColor: const Color(0xFF1e2a3a).withValues(alpha: 0.5),
          splashColor: color.withValues(alpha: 0.08),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // TOP BAR
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildTopBar() {
    return Builder(builder: (context) {
      final game = context.watch<GameProvider>();
      final auth = context.watch<AuthProvider>();
      final notificationProvider = context.watch<NotificationProvider>();

      final playerName = auth.username ?? 'Хакер';
      final playerLevel = game.level;

      return Container(
        height: 56,
        decoration: const BoxDecoration(
          color: Color(0xFF0d1220),
          border: Border(bottom: BorderSide(color: Color(0xFF1e2a3a))),
          boxShadow: [
            BoxShadow(color: Color(0x15000000), blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            // ── Player avatar + name + level ──
            Container(
              padding: const EdgeInsets.only(right: 16),
              decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: Color(0xFF1e2a3a))),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Avatar circle
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF00F0FF).withValues(alpha: 0.3),
                          const Color(0xFFa855f7).withValues(alpha: 0.3),
                        ],
                      ),
                      border: Border.all(
                        color: const Color(0xFF00F0FF).withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00F0FF).withValues(alpha: 0.15),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      playerName.isNotEmpty ? playerName[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Color(0xFF00F0FF),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Name & Level
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playerName,
                        style: const TextStyle(
                          color: Color(0xFFe0e6ed),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD700).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(0xFFFFD700).withValues(alpha: 0.25),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded, size: 9, color: Color(0xFFFFD700)),
                                const SizedBox(width: 2),
                                Text(
                                  'Ур. $playerLevel',
                                  style: const TextStyle(
                                    color: Color(0xFFFFD700),
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 16),

            // ── Resource bar ──
            Expanded(
              child: ResourceBar(
                credits: game.credits,
                cpu: game.cpu,
                bandwidth: game.bandwidth,
                mode: ResourceBarMode.compact,
                height: 44,
              ),
            ),

            // ── Action buttons ──
            _TopBarButton(
              icon: Icons.notifications_outlined,
              tooltip: 'Уведомления',
              badgeCount: notificationProvider.hasUnread ? notificationProvider.unreadCount : 0,
              badgeColor: const Color(0xFFFF1744),
              onTap: () => context.go('/game/notifications'),
            ),
            _TopBarButton(
              icon: Icons.settings_rounded,
              tooltip: 'Настройки',
              onTap: () => context.go('/settings'),
            ),
            _TopBarButton(
              icon: Icons.person_rounded,
              tooltip: 'Профиль',
              onTap: () => context.go('/profile'),
            ),
          ],
        ),
      );
    });
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Helper: Top bar icon button with optional badge
// ════════════════════════════════════════════════════════════════════════════

class _TopBarButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final int badgeCount;
  final Color badgeColor;
  final VoidCallback onTap;

  const _TopBarButton({
    required this.icon,
    required this.tooltip,
    this.badgeCount = 0,
    this.badgeColor = const Color(0xFFFF1744),
    required this.onTap,
  });

  @override
  State<_TopBarButton> createState() => _TopBarButtonState();
}

class _TopBarButtonState extends State<_TopBarButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: widget.tooltip,
        preferBelow: true,
        verticalOffset: 40,
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 44,
            height: 44,
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            decoration: BoxDecoration(
              color: _isHovered
                  ? const Color(0xFF00F0FF).withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: _isHovered
                  ? Border.all(color: const Color(0xFF00F0FF).withValues(alpha: 0.2))
                  : null,
            ),
            alignment: Alignment.center,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  widget.icon,
                  size: 20,
                  color: _isHovered ? const Color(0xFF00F0FF) : const Color(0xFF6a7080),
                ),
                if (widget.badgeCount > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: widget.badgeColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: widget.badgeColor.withValues(alpha: 0.5),
                            blurRadius: 6,
                          ),
                        ],
                        border: Border.all(color: const Color(0xFF0d1220), width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        widget.badgeCount > 9 ? '9+' : '${widget.badgeCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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

// ════════════════════════════════════════════════════════════════════════════
// Data models
// ════════════════════════════════════════════════════════════════════════════

class _SidebarSection {
  final String label;
  final List<_NavItem> items;

  const _SidebarSection({
    required this.label,
    required this.items,
  });
}

class _NavItem {
  final IconData icon;
  final String label;
  final String path;
  final Color color;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.path,
    required this.color,
  });
}
