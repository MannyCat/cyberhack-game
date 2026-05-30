import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/game_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/resource_bar.dart';

// ─── Game Shell — PC Layout: Top resource bar + Left sidebar + Main content ──

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      _fetchTotalPlayers();
    });
  }

  Future<void> _fetchTotalPlayers() async {
    try {
      final result = await Supabase.instance.client
          .from('profiles')
          .select('id');
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

  // ── Sidebar navigation items ──
  static const List<_NavItem> _navItems = [
    _NavItem(icon: Icons.public, label: 'Карта мира', path: '/game/map', color: Color(0xFF00e5ff)),
    _NavItem(icon: Icons.home, label: 'Главная', path: '/game/home', color: Color(0xFF00ff41)),
    _NavItem(icon: Icons.dns, label: 'База', path: '/game/network', color: Color(0xFF00e5ff)),
    _NavItem(icon: Icons.gps_fixed, label: 'Атака', path: '/game/attack', color: Color(0xFFFF0040)),
    _NavItem(icon: Icons.storefront, label: 'Магазин', path: '/game/market', color: Color(0xFFff9800)),
    _NavItem(icon: Icons.chat_bubble, label: 'Чат', path: '/game/chat', color: Color(0xFF00e5ff)),
    _NavItem(icon: Icons.groups, label: 'Банда', path: '/game/clan', color: Color(0xFFa855f7)),
    _NavItem(icon: Icons.leaderboard, label: 'Рейтинг', path: '/game/leaderboard', color: Color(0xFFe91e63)),
    _NavItem(icon: Icons.military_tech, label: 'Миссии', path: '/game/campaign', color: Color(0xFFFFD700)),
    _NavItem(icon: Icons.event, label: 'События', path: '/game/events', color: Color(0xFF00e5ff)),
    _NavItem(icon: Icons.card_giftcard, label: 'Награды', path: '/game/daily-reward', color: Color(0xFFFFD700)),
    _NavItem(icon: Icons.emoji_events, label: 'Достижения', path: '/game/achievements', color: Color(0xFFa855f7)),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final location = GoRouterState.of(context).matchedLocation;
    final index = _navItems.indexWhere((t) => location.startsWith(t.path));
    if (index != -1 && index != _selectedIndex) {
      setState(() => _selectedIndex = index);
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

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final badgeCount = _incomingAttackCount;

    return Scaffold(
      backgroundColor: const Color(0xFF0a0e17),
      body: Row(
        children: [
          // ── LEFT SIDEBAR ──
          _buildSidebar(badgeCount),

          // ── RIGHT AREA: Top bar + Content ──
          Expanded(
            child: Column(
              children: [
                // ── TOP RESOURCE BAR ──
                _buildTopBar(primary),
                // ── MAIN CONTENT ──
                Expanded(child: widget.child),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Sidebar Widget ──
  Widget _buildSidebar(int badgeCount) {
    return Container(
      width: 220,
      decoration: const BoxDecoration(
        color: Color(0xFF0d1220),
        border: Border(
          right: BorderSide(color: Color(0xFF1a2030), width: 1),
        ),
      ),
      child: Column(
        children: [
          // ── Logo / App Title ──
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF1a2030), width: 1)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00F0FF).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF00F0FF).withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.bolt, color: Color(0xFF00F0FF), size: 18),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'CYBERHACK',
                    style: TextStyle(
                      color: Color(0xFF00F0FF),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                // Online counter
                if (_fetchedPlayers && _totalPlayers > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF39FF14).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF39FF14).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: const Color(0xFF39FF14),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: const Color(0xFF39FF14).withValues(alpha: 0.5), blurRadius: 4),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$_totalPlayers',
                          style: const TextStyle(color: Color(0xFF39FF14), fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // ── Navigation Items ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: List.generate(_navItems.length, (index) {
                  final item = _navItems[index];
                  final isSelected = index == _selectedIndex;
                  final showBadge = index == 3 && badgeCount > 0; // Attack badge

                  return _buildNavTile(
                    icon: item.icon,
                    label: item.label,
                    color: item.color,
                    isSelected: isSelected,
                    showBadge: showBadge,
                    badgeCount: badgeCount,
                    onTap: () {
                      setState(() => _selectedIndex = index);
                      context.go(item.path);
                    },
                  );
                }),
              ),
            ),
          ),

          // ── Bottom: Settings, Profile, Logout ──
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFF1a2030), width: 1)),
            ),
            child: Column(
              children: [
                _buildBottomTile(Icons.person, 'Профиль', const Color(0xFF78909c), () => context.go('/profile')),
                _buildBottomTile(Icons.settings, 'Настройки', const Color(0xFF4a5568), () => context.go('/settings')),
                _buildBottomTile(Icons.logout, 'Выход', const Color(0xFFFF1744), () {
                  Supabase.instance.client.auth.signOut();
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavTile({
    required IconData icon,
    required String label,
    required Color color,
    required bool isSelected,
    bool showBadge = false,
    int badgeCount = 0,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border(left: BorderSide(color: color, width: 3))
                : null,
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: isSelected ? color : const Color(0xFF4a5568),
                  ),
                  if (showBadge)
                    Positioned(
                      right: -8,
                      top: -6,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF0040),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          badgeCount > 9 ? '9+' : '$badgeCount',
                          style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? color : const Color(0xFF6a7080),
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isSelected)
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4)],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomTile(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top Resource Bar ──
  Widget _buildTopBar(Color primary) {
    return Builder(builder: (context) {
      final game = context.watch<GameProvider>();
      final notificationProvider = context.watch<NotificationProvider>();
      return Container(
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFF0d1220),
          border: Border(
            bottom: BorderSide(
              color: primary.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            // Resource bar
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ResourceBar(
                  credits: game.credits,
                  cpu: game.cpu,
                  bandwidth: game.bandwidth,
                  mode: ResourceBarMode.compact,
                  height: 44,
                ),
              ),
            ),
            // Notification bell
            GestureDetector(
              onTap: () => context.go('/game/notifications'),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications_outlined, color: Color(0xFF00F0FF), size: 22),
                    if (notificationProvider.hasUnread)
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF1744),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF0d1220), width: 2),
                            boxShadow: [
                              BoxShadow(color: const Color(0xFFFF1744).withValues(alpha: 0.5), blurRadius: 4),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            notificationProvider.unreadCount > 9
                                ? '9+'
                                : '${notificationProvider.unreadCount}',
                            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
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

