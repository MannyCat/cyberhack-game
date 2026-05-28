import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class GameShell extends StatefulWidget {
  final Widget child;

  const GameShell({super.key, required this.child});

  @override
  State<GameShell> createState() => _GameShellState();
}

class _GameShellState extends State<GameShell> {
  int _currentIndex = 0;

  final _screens = const [
    _GameTab(label: 'Карта', icon: Icons.public, path: '/game/map'),
    _GameTab(label: 'Сеть', icon: Icons.account_tree, path: '/game/network'),
    _GameTab(label: 'Атака', icon: Icons.gps_fixed, path: '/game/attack'),
    _GameTab(label: 'Рынок', icon: Icons.storefront, path: '/game/market'),
    _GameTab(label: 'Клан', icon: Icons.groups, path: '/game/clan'),
    _GameTab(label: 'Связь', icon: Icons.chat_bubble, path: '/game/chat'),
    _GameTab(label: 'Топ', icon: Icons.leaderboard, path: '/game/leaderboard'),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final location = GoRouterState.of(context).matchedLocation;
    final index = _screens.indexWhere((s) => s.path == location);
    if (index != -1 && index != _currentIndex) {
      setState(() => _currentIndex = index);
    }
  }

  void _onTap(int index) {
    setState(() => _currentIndex = index);
    context.go(_screens[index].path);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0d1220),
          border: Border(
            top: BorderSide(
              color: accentColor.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.08),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _screens.asMap().entries.map((entry) {
                final index = entry.key;
                final screen = entry.value;
                final isSelected = index == _currentIndex;

                return Expanded(
                  child: GestureDetector(
                    onTap: () => _onTap(index),
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? accentColor.withValues(alpha: 0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(
                                color: accentColor.withValues(alpha: 0.2),
                                width: 0.5,
                              )
                            : null,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Icon with glow
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(4),
                            decoration: isSelected
                                ? BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: accentColor.withValues(alpha: 0.3),
                                        blurRadius: 10,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  )
                                : null,
                            child: Icon(
                              screen.icon,
                              size: isSelected ? 24 : 22,
                              color: isSelected
                                  ? accentColor
                                  : const Color(0xFF4a5568),
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Label
                          Text(
                            screen.label,
                            style: TextStyle(
                              fontSize: isSelected ? 11 : 10,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              letterSpacing: isSelected ? 0.8 : 0.3,
                              color: isSelected
                                  ? accentColor
                                  : const Color(0xFF4a5568),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _GameTab {
  final String label;
  final IconData icon;
  final String path;

  const _GameTab({
    required this.label,
    required this.icon,
    required this.path,
  });
}
