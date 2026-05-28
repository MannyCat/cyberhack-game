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
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Color(0xFF00F0FF),
              width: 0.5,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTap,
          type: BottomNavigationBarType.fixed,
          backgroundColor: const Color(0xFF1a1f2e),
          selectedItemColor: const Color(0xFF00ff41),
          unselectedItemColor: const Color(0xFF4a5568),
          selectedFontSize: 11,
          unselectedFontSize: 10,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
          unselectedLabelStyle: const TextStyle(letterSpacing: 0.5),
          elevation: 0,
          items: _screens
              .map((s) => BottomNavigationBarItem(
                    icon: Icon(s.icon, size: 22),
                    label: s.label,
                  ))
              .toList(),
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
