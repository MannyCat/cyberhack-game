import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/game_provider.dart';

// ─── Network Visualization Node ───────────────────────────────────────────

class _NetNode {
  final Offset position;
  final double radius;
  final Color color;
  double pulsePhase;
  final List<int> connections;

  _NetNode({
    required this.position,
    required this.radius,
    required this.color,
    required this.pulsePhase,
    required this.connections,
  });
}

// ─── Network Visualization Painter ────────────────────────────────────────

class _NetworkPainter extends CustomPainter {
  final List<_NetNode> nodes;
  final double animationValue;

  _NetworkPainter({required this.nodes, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    // Background grid
    final gridPaint = Paint()
      ..color = const Color(0xFF00ff41).withValues(alpha: 0.04)
      ..strokeWidth = 0.5;

    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Draw connections
    for (int i = 0; i < nodes.length; i++) {
      for (final j in nodes[i].connections) {
        if (j < nodes.length) {
          final from = nodes[i].position;
          final to = nodes[j].position;

          final linePaint = Paint()
            ..color = const Color(0xFF00e5ff).withValues(alpha: 0.15)
            ..strokeWidth = 1
            ..style = PaintingStyle.stroke;

          canvas.drawLine(from, to, linePaint);

          // Traveling data packet
          final t = (animationValue + i * 0.1) % 1.0;
          final packetPos = Offset.lerp(from, to, t)!;

          final packetPaint = Paint()
            ..color = const Color(0xFF00ff41)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
          canvas.drawCircle(packetPos, 3, packetPaint);
        }
      }
    }

    // Draw nodes
    for (final node in nodes) {
      final pulse = sin(animationValue * 2 * pi + node.pulsePhase) * 0.3 + 0.7;

      // Outer glow
      final glowPaint = Paint()
        ..color = node.color.withValues(alpha: 0.15 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
      canvas.drawCircle(node.position, node.radius * 2.5, glowPaint);

      // Node body
      final bodyPaint = Paint()
        ..color = node.color.withValues(alpha: 0.6 * pulse)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(node.position, node.radius, bodyPaint);

      // Node border
      final borderPaint = Paint()
        ..color = node.color
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(node.position, node.radius, borderPaint);

      // Inner dot
      final innerPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.8 * pulse);
      canvas.drawCircle(node.position, node.radius * 0.3, innerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _NetworkPainter oldDelegate) => true;
}

// ─── Resource Bar Widget ─────────────────────────────────────────────────

class _ResourceBar extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String unit;

  const _ResourceBar({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.unit = '',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1f2e),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(
              color: Color(0xFF4a5568),
              fontSize: 11,
              letterSpacing: 1,
              fontFamily: 'monospace',
            ),
          ),
          Text(
            '$value$unit',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Menu Button Widget ──────────────────────────────────────────────────

class _MenuButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final String subtitle;
  final VoidCallback onTap;
  final Color accentColor;

  const _MenuButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.subtitle = '',
    this.accentColor = const Color(0xFF00ff41),
  });

  @override
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton>
    with TickerProviderStateMixin {
  late AnimationController _hoverController;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  void _onEnter(bool entering) {
    setState(() => _isHovered = entering);
    if (entering) {
      _hoverController.forward();
    } else {
      _hoverController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _hoverController,
      builder: (context, _) {
        final t = _hoverController.value;
        return GestureDetector(
          onTap: widget.onTap,
          child: MouseRegion(
            onEnter: (_) => _onEnter(true),
            onExit: (_) => _onEnter(false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: _isHovered
                    ? widget.accentColor.withValues(alpha: 0.08 + t * 0.07)
                    : const Color(0xFF1a1f2e).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _isHovered
                      ? widget.accentColor.withValues(alpha: 0.4 + t * 0.4)
                      : const Color(0xFF1a1f2e),
                  width: 1,
                ),
                boxShadow: _isHovered
                    ? [
                        BoxShadow(
                          color: widget.accentColor.withValues(alpha: 0.15 * t),
                          blurRadius: 15,
                          spreadRadius: 1,
                        ),
                      ]
                    : [],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: widget.accentColor.withValues(alpha: 0.1 + t * 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: widget.accentColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.accentColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.label,
                          style: TextStyle(
                            color: _isHovered
                                ? widget.accentColor
                                : const Color(0xFFc0c8d8),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            fontFamily: 'monospace',
                          ),
                        ),
                        if (widget.subtitle.isNotEmpty)
                          Text(
                            widget.subtitle,
                            style: TextStyle(
                              color: const Color(0xFF4a5568).withValues(alpha: 0.8),
                              fontSize: 10,
                              letterSpacing: 1,
                              fontFamily: 'monospace',
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: widget.accentColor.withValues(alpha: 0.3 + t * 0.5),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Main Menu Screen ─────────────────────────────────────────────────────

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen>
    with TickerProviderStateMixin {
  late AnimationController _netController;
  late AnimationController _borderGlowController;
  late List<_NetNode> _nodes;
  final _random = Random(42);

  @override
  void initState() {
    super.initState();
    _netController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _borderGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _generateNetwork();

    // Инициализируем GameProvider с userId
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.userId != null) {
        context.read<GameProvider>().init(auth.userId!);
      }
    });
  }

  void _generateNetwork() {
    const nodeCount = 15;
    _nodes = List.generate(nodeCount, (i) {
      final angle = (2 * pi * i) / nodeCount + _random.nextDouble() * 0.5;
      final dist = 60 + _random.nextDouble() * 80;
      return _NetNode(
        position: Offset(
          cos(angle) * dist,
          sin(angle) * dist,
        ),
        radius: 4 + _random.nextDouble() * 6,
        color: _random.nextBool()
            ? const Color(0xFF00ff41)
            : const Color(0xFF00e5ff),
        pulsePhase: _random.nextDouble() * 2 * pi,
        connections: List.generate(
          1 + _random.nextInt(3),
          (_) => _random.nextInt(nodeCount),
        ),
      );
    });
  }

  @override
  void dispose() {
    _netController.dispose();
    _borderGlowController.dispose();
    super.dispose();
  }

  String _rankTitle(int level) {
    if (level >= 50) return 'ЛЕГЕНДА';
    if (level >= 40) return 'ЭЛИТНЫЙ ОПЕРАТОР';
    if (level >= 30) return 'ВЕТЕРАН';
    if (level >= 20) return 'ОПЕРАТОР';
    if (level >= 10) return 'НОВИЧОК+';
    return 'НОВИЧОК';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final game = context.watch<GameProvider>();

    final username = auth.displayName;
    final level = game.level;
    final credits = game.credits;
    final cpu = game.cpu;
    final bandwidth = game.bandwidth;
    final xp = game.xp;
    final xpNeeded = level * 1000; // простая формула
    final xpPercent = xpNeeded > 0 ? (xp / xpNeeded).clamp(0.0, 1.0) : 0.0;
    final onlineNodes = game.networkNodes.where((n) => n.isOnline).length;

    return Scaffold(
      backgroundColor: const Color(0xFF0a0e17),
      body: Column(
        children: [
          // ── Top Bar ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1a1f2e),
              border: Border(
                bottom: BorderSide(
                  color: const Color(0xFF00ff41).withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00ff41), Color(0xFF00e5ff)],
                    ),
                    border: Border.all(
                      color: const Color(0xFF00ff41).withValues(alpha: 0.5),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00ff41).withValues(alpha: 0.3),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Text(
                    username.isNotEmpty ? username.substring(0, 1).toUpperCase() : '?',
                    style: const TextStyle(
                      color: Color(0xFF0a0e17),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Player info — РЕАЛЬНЫЕ ДАННЫЕ
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF00ff41),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Text(
                      'LVL $level // ${_rankTitle(level)}',
                      style: const TextStyle(
                        color: Color(0xFF00e5ff),
                        fontSize: 10,
                        letterSpacing: 1,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // XP bar — РЕАЛЬНЫЙ ПРОГРЕСС
                Container(
                  width: 150,
                  height: 6,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0d1117),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: xpPercent,
                      backgroundColor: Colors.transparent,
                      color: const Color(0xFF00ff41),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(xpPercent * 100).toInt()}%',
                  style: const TextStyle(
                    color: Color(0xFF00ff41),
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(width: 16),
                // Notification bell
                _buildTopIcon(Icons.notifications_outlined, 0),
                const SizedBox(width: 12),
                _buildTopIcon(Icons.mail_outline, 0),
              ],
            ),
          ),

          // ── Resource Bar — РЕАЛЬНЫЕ РЕСУРСЫ ──────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF111520),
              border: Border(
                bottom: BorderSide(
                  color: const Color(0xFF00e5ff).withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                _ResourceBar(
                  label: 'КРЕДИТЫ',
                  value: credits.toString(),
                  icon: Icons.payments_outlined,
                  color: const Color(0xFF00ff41),
                ),
                const SizedBox(width: 12),
                _ResourceBar(
                  label: 'ЦПУ',
                  value: '$cpu',
                  unit: ' THz',
                  icon: Icons.memory,
                  color: const Color(0xFF00e5ff),
                ),
                const SizedBox(width: 12),
                _ResourceBar(
                  label: 'КАНАЛ',
                  value: '$bandwidth',
                  unit: ' MB/s',
                  icon: Icons.wifi_tethering,
                  color: const Color(0xFFff9800),
                ),
                const Spacer(),
                Text(
                  'УЗЛОВ: $onlineNodes ОНЛАЙН',
                  style: const TextStyle(
                    color: Color(0xFF4a5568),
                    fontSize: 10,
                    letterSpacing: 1,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),

          // ── Main Content Area ────────────────────────────────────
          Expanded(
            child: Row(
              children: [
                // Left: Network Visualization
                Expanded(
                  flex: 5,
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _borderGlowController,
                      builder: (context, _) {
                        final glow = _borderGlowController.value;
                        return Container(
                          margin: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF00ff41)
                                  .withValues(alpha: 0.2 + glow * 0.3),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00ff41)
                                    .withValues(alpha: 0.05 + glow * 0.08),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              children: [
                                Container(color: const Color(0xFF0d1117)),
                                AnimatedBuilder(
                                  animation: _netController,
                                  builder: (context, _) {
                                    return CustomPaint(
                                      painter: _NetworkPainter(
                                        nodes: _nodes,
                                        animationValue: _netController.value,
                                      ),
                                      size: Size.infinite,
                                    );
                                  },
                                ),
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0a0e17)
                                          .withValues(alpha: 0.85),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: const Color(0xFF00ff41)
                                            .withValues(alpha: 0.2),
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'СТАТУС СЕТИ',
                                          style: TextStyle(
                                            color: const Color(0xFF00ff41),
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 3,
                                            fontFamily: 'monospace',
                                            shadows: const [
                                              Shadow(
                                                color: Color(0xFF00ff41),
                                                blurRadius: 15,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '$onlineNodes УЗЛОВ ОНЛАЙН // 0 ТРЕВОГ',
                                          style: const TextStyle(
                                            color: Color(0xFF00e5ff),
                                            fontSize: 11,
                                            letterSpacing: 1,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Right: Menu Buttons
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(left: 4, bottom: 12),
                          child: Text(
                            '// МЕНЮ МАЙНФРЕЙМА',
                            style: TextStyle(
                              color: Color(0xFF4a5568),
                              fontSize: 11,
                              letterSpacing: 2,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        _MenuButton(
                          label: 'ВОЙТИ В СЕТЬ',
                          icon: Icons.language,
                          subtitle: 'Игровая карта и операции',
                          accentColor: const Color(0xFF00ff41),
                          onTap: () => context.go('/game/map'),
                        ),
                        const SizedBox(height: 8),
                        _MenuButton(
                          label: 'ТЕРМИНАЛ',
                          icon: Icons.terminal,
                          subtitle: 'Зашифрованные коммуникации',
                          accentColor: const Color(0xFF00e5ff),
                          onTap: () => context.go('/game/chat'),
                        ),
                        const SizedBox(height: 8),
                        _MenuButton(
                          label: 'БАНДА',
                          icon: Icons.groups,
                          subtitle: 'Ваша хакерская группировка',
                          accentColor: const Color(0xFFa855f7),
                          onTap: () => context.go('/game/clan'),
                        ),
                        const SizedBox(height: 8),
                        _MenuButton(
                          label: 'ЧЁРНЫЙ РЫНОК',
                          icon: Icons.storefront,
                          subtitle: 'Покупка инструментов и эксплойтов',
                          accentColor: const Color(0xFFff9800),
                          onTap: () => context.go('/game/market'),
                        ),
                        const SizedBox(height: 8),
                        _MenuButton(
                          label: 'РЕЙТИНГ',
                          icon: Icons.leaderboard,
                          subtitle: 'Мировой рейтинг',
                          accentColor: const Color(0xFFe91e63),
                          onTap: () => context.go('/game/leaderboard'),
                        ),
                        const SizedBox(height: 8),
                        _MenuButton(
                          label: 'ПРОФИЛЬ',
                          icon: Icons.person,
                          subtitle: 'Статистика и достижения',
                          accentColor: const Color(0xFF00e5ff),
                          onTap: () => context.go('/profile'),
                        ),
                        const SizedBox(height: 8),
                        _MenuButton(
                          label: 'НАСТРОЙКИ',
                          icon: Icons.settings_outlined,
                          subtitle: 'Конфигурация системы',
                          accentColor: const Color(0xFF78909c),
                          onTap: () => context.go('/settings'),
                        ),
                        const SizedBox(height: 12),
                        const Divider(
                          color: Color(0xFF1a1f2e),
                          thickness: 1,
                        ),
                        const SizedBox(height: 8),
                        _MenuButton(
                          label: 'ОТКЛЮЧИТЬСЯ',
                          icon: Icons.power_settings_new,
                          subtitle: 'Завершить сессию',
                          accentColor: const Color(0xFFff4444),
                          onTap: () async {
                            final authProvider = context.read<AuthProvider>();
                            await authProvider.logout();
                          },
                        ),
                      ],
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

  Widget _buildTopIcon(IconData icon, int badgeCount) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF0d1117),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: const Color(0xFF00e5ff).withValues(alpha: 0.2),
            ),
          ),
          child: Icon(icon, color: const Color(0xFF00e5ff), size: 18),
        ),
        if (badgeCount > 0)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: Color(0xFFff4444),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Color(0xFFff4444), blurRadius: 6),
                ],
              ),
              child: Center(
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
