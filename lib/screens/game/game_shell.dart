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
    _GameTab(label: 'Карта', icon: Icons.map, path: '/game/map'),
    _GameTab(label: 'Сеть', icon: Icons.account_tree, path: '/game/network'),
    _GameTab(label: 'Атака', icon: Icons.gps_fixed, path: '/game/attack'),
    _GameTab(label: 'Рынок', icon: Icons.storefront, path: '/game/market'),
    _GameTab(label: 'Связь', icon: Icons.chat, path: '/game/chat'),
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
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTap,
        items: _screens
            .map((s) => BottomNavigationBarItem(
                  icon: Icon(s.icon),
                  label: s.label,
                ))
            .toList(),
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
