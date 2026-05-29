import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../widgets/resource_bar.dart';

// ─── Game Shell — Оболочка с навигацией и ресурсами ─────────────────────────

class GameShell extends StatefulWidget {
  final Widget child;

  const GameShell({super.key, required this.child});

  @override
  State<GameShell> createState() => _GameShellState();
}

class _GameShellState extends State<GameShell> {
  int _currentIndex = 0;

  final _tabs = const [
    _Tab(icon: Icons.home, label: 'Главная', path: '/game/home'),
    _Tab(icon: Icons.dns, label: 'База', path: '/game/network'),
    _Tab(icon: Icons.gps_fixed, label: 'Атака', path: '/game/attack'),
    _Tab(icon: Icons.storefront, label: 'Магазин', path: '/game/market'),
    _Tab(icon: Icons.more_horiz, label: 'Ещё', path: '/game/more'),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final location = GoRouterState.of(context).matchedLocation;
    final index = _tabs.indexWhere((t) => location.startsWith(t.path));
    if (index != -1 && index != _currentIndex) {
      setState(() => _currentIndex = index);
    }
  }

  void _onTap(int index) {
    if (index == 4) {
      // "Ещё" — показываем bottom sheet
      _showMoreSheet();
      return;
    }
    setState(() => _currentIndex = index);
    context.go(_tabs[index].path);
  }

  void _showMoreSheet() {
    final primary = Theme.of(context).colorScheme.primary;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ручка
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3a4060),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Опции
              _moreTile(Icons.chat_bubble, 'Чат', 'Общение с игроками', primary, () {
                Navigator.pop(context);
                context.go('/game/chat');
              }),
              _moreTile(Icons.groups, 'Банда', 'Создай или вступи', const Color(0xFFa855f7), () {
                Navigator.pop(context);
                context.go('/game/clan');
              }),
              _moreTile(Icons.leaderboard, 'Рейтинг', 'Лучшие хакеры', const Color(0xFFe91e63), () {
                Navigator.pop(context);
                context.go('/game/leaderboard');
              }),
              _moreTile(Icons.military_tech, 'Миссии', 'PvE кампания', const Color(0xFFFFD700), () {
                Navigator.pop(context);
                context.go('/game/campaign');
              }),
              _moreTile(Icons.person, 'Профиль', 'Статистика и настройки', const Color(0xFF78909c), () {
                Navigator.pop(context);
                context.go('/profile');
              }),
              _moreTile(Icons.settings, 'Настройки', 'Оформление и аккаунт', const Color(0xFF4a5568), () {
                Navigator.pop(context);
                context.go('/settings');
              }),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _moreTile(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: Color(0xFF4a5568), fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF3a4060), size: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: Column(
        children: [
          // ── Resource Bar вверху ──
          Builder(builder: (context) {
            final game = context.watch<GameProvider>();
            return ResourceBar(
              credits: game.credits,
              cpu: game.cpu,
              bandwidth: game.bandwidth,
              mode: ResourceBarMode.compact,
              height: 44,
            );
          }),
          // ── Контент ──
          Expanded(child: widget.child),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0d1220),
          border: Border(
            top: BorderSide(
              color: primary.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: List.generate(_tabs.length, (index) {
              final tab = _tabs[index];
              final isSelected = index == _currentIndex && index != 4;

              return Expanded(
                child: GestureDetector(
                  onTap: () => _onTap(index),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          tab.icon,
                          size: 24,
                          color: isSelected ? primary : const Color(0xFF3a4060),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tab.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isSelected ? primary : const Color(0xFF3a4060),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _Tab {
  final IconData icon;
  final String label;
  final String path;

  const _Tab({
    required this.icon,
    required this.label,
    required this.path,
  });
}
