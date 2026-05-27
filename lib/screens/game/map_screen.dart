import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ─── Game Map Node Model ──────────────────────────────────────────────────

enum NodeType { server, firewall, database, router, terminal, target }

class GameNode {
  String id;
  String name;
  Offset position;
  double radius;
  double health;
  double maxHealth;
  NodeType type;
  bool isOnline;
  bool isSelected;
  bool isPlayerOwned;
  int firewallStrength;
  int attackPower;
  final List<String> connections;

  GameNode({
    required this.id,
    required this.name,
    required this.position,
    required this.type,
    this.radius = 24,
    this.health = 100,
    this.maxHealth = 100,
    this.isOnline = true,
    this.isSelected = false,
    this.isPlayerOwned = false,
    this.firewallStrength = 3,
    this.attackPower = 5,
    required this.connections,
  });
}

// ─── Grid Background Painter ─────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  final double scrollOffset;

  _GridPainter({this.scrollOffset = 0});

  @override
  void paint(Canvas canvas, Size size) {
    // Base background
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0a0e17),
    );

    // Grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFF00ff41).withOpacity(0.04)
      ..strokeWidth = 0.5;

    const gridSize = 50.0;
    final offsetX = scrollOffset % gridSize;

    for (double x = -gridSize + offsetX; x < size.width + gridSize; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Radial gradient overlay at center
    final center = Offset(size.width / 2, size.height / 2);
    final radialGradient = RadialGradient(
      colors: [
        const Color(0xFF00ff41).withOpacity(0.03),
        const Color(0xFF0a0e17).withOpacity(0),
      ],
      radius: 0.6,
    );
    final radialPaint = Paint()..shader = radialGradient.createShader(Rect.fromCircle(center: center, radius: size.width * 0.6));
    canvas.drawRect(Offset.zero & size, radialPaint);
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      scrollOffset != oldDelegate.scrollOffset;
}

// ─── Network Map Painter ─────────────────────────────────────────────────

class _NetworkMapPainter extends CustomPainter {
  final List<GameNode> nodes;
  final double animationValue;
  final GameNode? selectedNode;

  _NetworkMapPainter({
    required this.nodes,
    required this.animationValue,
    this.selectedNode,
  });

  Color _nodeColor(GameNode node) {
    if (!node.isOnline) return const Color(0xFF333333);
    switch (node.type) {
      case NodeType.server:
        return node.isPlayerOwned
            ? const Color(0xFF00ff41)
            : const Color(0xFFff4444);
      case NodeType.firewall:
        return node.isPlayerOwned
            ? const Color(0xFF00e5ff)
            : const Color(0xFFff6600);
      case NodeType.database:
        return node.isPlayerOwned
            ? const Color(0xFFa855f7)
            : const Color(0xFFff9800);
      case NodeType.router:
        return node.isPlayerOwned
            ? const Color(0xFF00cc88)
            : const Color(0xFFcc3300);
      case NodeType.terminal:
        return const Color(0xFF00e5ff);
      case NodeType.target:
        return const Color(0xFFff4444);
    }
  }

  IconData _nodeIcon(GameNode node) {
    switch (node.type) {
      case NodeType.server:
        return Icons.dns;
      case NodeType.firewall:
        return Icons.shield;
      case NodeType.database:
        return Icons.storage;
      case NodeType.router:
        return Icons.router;
      case NodeType.terminal:
        return Icons.computer;
      case NodeType.target:
        return Icons.flag;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Draw connections first
    for (final node in nodes) {
      for (final connId in node.connections) {
        final other = nodes.where((n) => n.id == connId).firstOrNull;
        if (other == null) continue;

        final isSelectedConnection =
            selectedNode != null &&
            (selectedNode!.id == node.id || selectedNode!.id == other.id);

        final connColor = isSelectedConnection
            ? const Color(0xFF00ff41).withOpacity(0.5)
            : node.isPlayerOwned
                ? const Color(0xFF00ff41).withOpacity(0.15)
                : const Color(0xFFff4444).withOpacity(0.12);

        final connPaint = Paint()
          ..color = connColor
          ..strokeWidth = isSelectedConnection ? 2 : 1;

        canvas.drawLine(node.position, other.position, connPaint);

        // Data flow particles along connection
        if (node.isOnline && other.isOnline) {
          final t1 = (animationValue * 2 + node.position.dx * 0.01) % 1.0;
          final t2 = (animationValue * 2 + other.position.dx * 0.01 + 0.5) % 1.0;

          for (final t in [t1, t2]) {
            final pos = Offset.lerp(node.position, other.position, t)!;
            final particlePaint = Paint()
              ..color = isSelectedConnection
                  ? const Color(0xFF00ff41)
                  : const Color(0xFF00e5ff).withOpacity(0.5);
            canvas.drawCircle(pos, 2, particlePaint);
          }
        }
      }
    }

    // Draw nodes
    for (final node in nodes) {
      final color = _nodeColor(node);
      final isSelected = selectedNode?.id == node.id;
      final pulse = sin(animationValue * 2 * pi + node.position.dx * 0.1) * 0.2 + 0.8;

      // Selection ring
      if (isSelected) {
        final selPaint = Paint()
          ..color = color.withOpacity(0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawCircle(node.position, node.radius + 8, selPaint);

        // Rotating selection dashes
        final dashAngle = animationValue * 2 * pi;
        for (int i = 0; i < 8; i++) {
          final angle = dashAngle + (i * pi / 4);
          final startR = node.radius + 12;
          final endR = node.radius + 18;
          canvas.drawLine(
            Offset(
              node.position.dx + cos(angle) * startR,
              node.position.dy + sin(angle) * startR,
            ),
            Offset(
              node.position.dx + cos(angle) * endR,
              node.position.dy + sin(angle) * endR,
            ),
            Paint()
              ..color = color
              ..strokeWidth = 2
              ..strokeCap = StrokeCap.round,
          );
        }
      }

      // Outer glow
      if (node.isOnline) {
        final glowPaint = Paint()
          ..color = color.withOpacity(0.12 * pulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
        canvas.drawCircle(node.position, node.radius * 2, glowPaint);
      }

      // Node background circle
      final bgPaint = Paint()
        ..color = const Color(0xFF1a1f2e)
        ..strokeWidth = 2;
      if (isSelected) {
        bgPaint
          ..color = const Color(0xFF0d1117)
          ..style = PaintingStyle.fill;
      } else {
        bgPaint.style = PaintingStyle.fill;
      }
      canvas.drawCircle(node.position, node.radius, bgPaint);

      // Node border
      final borderPaint = Paint()
        ..color = node.isOnline ? color.withOpacity(0.8) : const Color(0xFF333333)
        ..strokeWidth = isSelected ? 2.5 : 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(node.position, node.radius, borderPaint);

      // Health bar (below node)
      if (node.health < node.maxHealth) {
        final barWidth = node.radius * 2;
        final barHeight = 4.0;
        final barY = node.position.dy + node.radius + 6;
        final barX = node.position.dx - barWidth / 2;
        final healthPercent = node.health / node.maxHealth;

        // Background
        canvas.drawRect(
          Rect.fromLTWH(barX, barY, barWidth, barHeight),
          Paint()..color = const Color(0xFF333333),
        );

        // Health fill
        final healthColor = healthPercent > 0.5
            ? const Color(0xFF00ff41)
            : healthPercent > 0.25
                ? const Color(0xFFffaa00)
                : const Color(0xFFff4444);
        canvas.drawRect(
          Rect.fromLTWH(barX, barY, barWidth * healthPercent, barHeight.toDouble()),
          Paint()..color = healthColor,
        );
      }

      // Online status indicator
      if (node.isOnline) {
        final indicatorPos = Offset(
          node.position.dx + node.radius * 0.7,
          node.position.dy - node.radius * 0.7,
        );
        final indicatorPaint = Paint()
          ..color = const Color(0xFF00ff41)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
        canvas.drawCircle(indicatorPos, 4, indicatorPaint);
        canvas.drawCircle(indicatorPos, 3, Paint()..color = const Color(0xFF00ff41));
      } else {
        final indicatorPos = Offset(
          node.position.dx + node.radius * 0.7,
          node.position.dy - node.radius * 0.7,
        );
        canvas.drawCircle(
            indicatorPos, 3, Paint()..color = const Color(0xFFff4444));
      }

      // Node label
      final textSpan = TextSpan(
        text: node.name,
        style: TextStyle(
          color: isSelected
              ? color
              : node.isOnline
                  ? const Color(0xFFc0c8d8)
                  : const Color(0xFF555555),
          fontSize: 10,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          letterSpacing: 1,
          fontFamily: 'monospace',
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          node.position.dx - textPainter.width / 2,
          node.position.dy + node.radius + (node.health < node.maxHealth ? 14 : 8),
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _NetworkMapPainter oldDelegate) => true;
}

// ─── Action Panel (Attack / Defend) ──────────────────────────────────────

class _ActionPanel extends StatelessWidget {
  final GameNode node;
  final VoidCallback onAttack;
  final VoidCallback onDefend;
  final VoidCallback onScan;
  final VoidCallback onClose;

  const _ActionPanel({
    required this.node,
    required this.onAttack,
    required this.onDefend,
    required this.onScan,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1f2e).withOpacity(0.95),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: node.isPlayerOwned
              ? const Color(0xFF00ff41).withOpacity(0.4)
              : const Color(0xFFff4444).withOpacity(0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: node.isPlayerOwned
                ? const Color(0xFF00ff41).withOpacity(0.1)
                : const Color(0xFFff4444).withOpacity(0.1),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                node.isPlayerOwned ? Icons.shield_outlined : Icons.warning_amber,
                color: node.isPlayerOwned
                    ? const Color(0xFF00ff41)
                    : const Color(0xFFff4444),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                node.name.toUpperCase(),
                style: TextStyle(
                  color: node.isPlayerOwned
                      ? const Color(0xFF00ff41)
                      : const Color(0xFFff4444),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  fontFamily: 'monospace',
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onClose,
                child: const Icon(
                  Icons.close,
                  color: Color(0xFF4a5568),
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFF1a1f2e), height: 1),
          const SizedBox(height: 12),

          // Node stats
          _buildStat('ТИП', node.type.name.toUpperCase(), const Color(0xFF00e5ff)),
          const SizedBox(height: 6),
          _buildStat('ЗДОРОВЬЕ', '${node.health.toInt()}/${node.maxHealth.toInt()}',
              node.health > 50 ? const Color(0xFF00ff41) : const Color(0xFFff4444)),
          const SizedBox(height: 6),
          _buildStat('ФАЙРВОЛ', '${node.firewallStrength}/10',
              const Color(0xFFff9800)),
          const SizedBox(height: 6),
          _buildStat('СТАТУС', node.isOnline ? 'ОНЛАЙН' : 'ОФФЛАЙН',
              node.isOnline ? const Color(0xFF00ff41) : const Color(0xFFff4444)),
          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              if (!node.isPlayerOwned) ...[
                Expanded(
                  child: _ActionBtn(
                    label: '⚔ АТАКА',
                    color: const Color(0xFFff4444),
                    onTap: onAttack,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (node.isPlayerOwned) ...[
                Expanded(
                  child: _ActionBtn(
                    label: '🛡 ЗАЩИТА',
                    color: const Color(0xFF00ff41),
                    onTap: onDefend,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: _ActionBtn(
                  label: '📡 СКАН',
                  color: const Color(0xFF00e5ff),
                  onTap: onScan,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF4a5568),
            fontSize: 10,
            letterSpacing: 1.5,
            fontFamily: 'monospace',
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}

class _ActionBtn extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({required this.label, required this.color, required this.onTap});

  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: _pressed
              ? widget.color.withOpacity(0.3)
              : widget.color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: widget.color.withOpacity(_pressed ? 0.8 : 0.4),
          ),
          boxShadow: _pressed
              ? [
                  BoxShadow(
                    color: widget.color.withOpacity(0.2),
                    blurRadius: 10,
                  ),
                ]
              : [],
        ),
        child: Center(
          child: Text(
            widget.label,
            style: TextStyle(
              color: widget.color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Game Map Screen ──────────────────────────────────────────────────────

class GameMapScreen extends StatefulWidget {
  const GameMapScreen({super.key});

  @override
  State<GameMapScreen> createState() => _GameMapScreenState();
}

class _GameMapScreenState extends State<GameMapScreen>
    with TickerProviderStateMixin {
  late AnimationController _mapAnimController;
  late AnimationController _gridScrollController;
  late List<GameNode> _nodes;
  final _random = Random(1337);

  GameNode? _selectedNode;
  bool _showScanEffect = false;
  Offset _dragOffset = Offset.zero;
  GameNode? _draggingNode;

  @override
  void initState() {
    super.initState();
    _mapAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _gridScrollController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _initNodes();
  }

  void _initNodes() {
    // Player's network (left side)
    _nodes = [
      // Player core
      GameNode(
        id: 'p1',
        name: 'NEXUS-CORE',
        position: const Offset(150, 300),
        type: NodeType.server,
        isPlayerOwned: true,
        health: 100,
        firewallStrength: 8,
        attackPower: 10,
        connections: ['p2', 'p3', 'p4', 'p5'],
      ),
      GameNode(
        id: 'p2',
        name: 'FIREWALL-01',
        position: const Offset(80, 180),
        type: NodeType.firewall,
        isPlayerOwned: true,
        health: 95,
        firewallStrength: 9,
        connections: ['p1'],
      ),
      GameNode(
        id: 'p3',
        name: 'DB-VAULT',
        position: const Offset(80, 420),
        type: NodeType.database,
        isPlayerOwned: true,
        health: 88,
        firewallStrength: 7,
        connections: ['p1'],
      ),
      GameNode(
        id: 'p4',
        name: 'ROUTER-PRIME',
        position: const Offset(150, 160),
        type: NodeType.router,
        isPlayerOwned: true,
        health: 100,
        firewallStrength: 5,
        connections: ['p1'],
      ),
      GameNode(
        id: 'p5',
        name: 'TERM-ALPHA',
        position: const Offset(150, 440),
        type: NodeType.terminal,
        isPlayerOwned: true,
        health: 100,
        firewallStrength: 4,
        connections: ['p1'],
      ),

      // ── Enemy / Target Networks (right side) ──
      GameNode(
        id: 'e1',
        name: 'CORP-SRV-01',
        position: const Offset(600, 200),
        type: NodeType.server,
        isPlayerOwned: false,
        health: 75,
        firewallStrength: 6,
        connections: ['e2', 'e3'],
      ),
      GameNode(
        id: 'e2',
        name: 'CORP-FW-Main',
        position: const Offset(500, 150),
        type: NodeType.firewall,
        isPlayerOwned: false,
        health: 90,
        firewallStrength: 8,
        connections: ['e1'],
      ),
      GameNode(
        id: 'e3',
        name: 'CORP-DB-01',
        position: const Offset(700, 250),
        type: NodeType.database,
        isPlayerOwned: false,
        health: 60,
        firewallStrength: 4,
        connections: ['e1'],
      ),
      GameNode(
        id: 'e4',
        name: 'BANK-CORE',
        position: const Offset(650, 400),
        type: NodeType.target,
        isPlayerOwned: false,
        health: 85,
        firewallStrength: 10,
        connections: ['e5', 'e6'],
      ),
      GameNode(
        id: 'e5',
        name: 'BANK-FW',
        position: const Offset(550, 370),
        type: NodeType.firewall,
        isPlayerOwned: false,
        health: 95,
        firewallStrength: 9,
        connections: ['e4'],
      ),
      GameNode(
        id: 'e6',
        name: 'BANK-DB',
        position: const Offset(750, 430),
        type: NodeType.database,
        isPlayerOwned: false,
        health: 50,
        firewallStrength: 3,
        connections: ['e4'],
      ),
      // Neutral / unclaimed
      GameNode(
        id: 'n1',
        name: 'RELAY-NODE',
        position: const Offset(370, 280),
        type: NodeType.router,
        isPlayerOwned: false,
        health: 100,
        firewallStrength: 2,
        connections: ['p1', 'e1'],
      ),
    ];
  }

  void _onCanvasTap(TapUpDetails details) {
    final tapPos = details.localPosition;
    GameNode? tapped;

    for (final node in _nodes) {
      final dist = (tapPos - node.position).distance;
      if (dist <= node.radius + 10) {
        tapped = node;
        break;
      }
    }

    setState(() {
      if (tapped != null) {
        for (final n in _nodes) {
          n.isSelected = false;
        }
        tapped.isSelected = true;
        _selectedNode = tapped;
      } else {
        for (final n in _nodes) {
          n.isSelected = false;
        }
        _selectedNode = null;
      }
    });
  }

  void _onCanvasPanStart(DragStartDetails details) {
    final pos = details.localPosition;
    for (final node in _nodes) {
      if ((pos - node.position).distance <= node.radius + 5 && node.isPlayerOwned) {
        setState(() => _draggingNode = node);
        return;
      }
    }
  }

  void _onCanvasPanUpdate(DragUpdateDetails details) {
    if (_draggingNode != null) {
      setState(() {
        _draggingNode!.position += details.delta;
      });
    }
  }

  void _onCanvasPanEnd(DragEndDetails details) {
    setState(() => _draggingNode = null);
  }

  void _scanNetwork() {
    setState(() => _showScanEffect = true);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _showScanEffect = false);
    });
  }

  void _attackNode() {
    if (_selectedNode != null && !_selectedNode!.isPlayerOwned) {
      setState(() {
        _selectedNode!.health = max(
            0, _selectedNode!.health - _random.nextInt(15) - 5);
        if (_selectedNode!.health <= 0) {
          _selectedNode!.isOnline = false;
        }
      });
    }
  }

  void _defendNode() {
    if (_selectedNode != null && _selectedNode!.isPlayerOwned) {
      setState(() {
        _selectedNode!.health =
            min(_selectedNode!.maxHealth, _selectedNode!.health + 10);
        _selectedNode!.isOnline = true;
      });
    }
  }

  @override
  void dispose() {
    _mapAnimController.dispose();
    _gridScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0e17),
      body: Column(
        children: [
          // ── Top Resource Bar ────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1a1f2e),
              border: Border(
                bottom: BorderSide(
                  color: const Color(0xFF00ff41).withOpacity(0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                // Back button
                GestureDetector(
                  onTap: () => context.go('/main-menu'),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0d1117),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: const Color(0xFF00e5ff).withOpacity(0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Color(0xFF00e5ff),
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Map title
                const Text(
                  '◆ ТОПОЛОГИЯ СЕТИ',
                  style: TextStyle(
                    color: Color(0xFF00ff41),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00ff41).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: const Color(0xFF00ff41).withOpacity(0.3),
                    ),
                  ),
                  child: const Text(
                    'SECTOR 7-G',
                    style: TextStyle(
                      color: Color(0xFF00ff41),
                      fontSize: 10,
                      letterSpacing: 1,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const Spacer(),

                // Mini resources
                _MiniResource(
                    icon: Icons.payments_outlined,
                    value: '247K',
                    color: const Color(0xFF00ff41)),
                const SizedBox(width: 16),
                _MiniResource(
                    icon: Icons.memory,
                    value: '8.4 THz',
                    color: const Color(0xFF00e5ff)),
                const SizedBox(width: 16),
                _MiniResource(
                    icon: Icons.wifi_tethering,
                    value: '2.1 Gbps',
                    color: const Color(0xFFff9800)),
                const SizedBox(width: 16),

                // Scan button
                GestureDetector(
                  onTap: _scanNetwork,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF00e5ff).withOpacity(0.8),
                          const Color(0xFF009eb8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00e5ff).withOpacity(0.3),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.radar, color: Color(0xFF0a0e17), size: 16),
                        SizedBox(width: 6),
                        Text(
                          'СКАНИРОВАТЬ СЕТЬ',
                          style: TextStyle(
                            color: Color(0xFF0a0e17),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
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

          // ── Map Area ────────────────────────────────────────────
          Expanded(
            child: Stack(
              children: [
                // Grid background
                AnimatedBuilder(
                  animation: _gridScrollController,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _GridPainter(
                        scrollOffset: _gridScrollController.value * 50,
                      ),
                      size: Size.infinite,
                    );
                  },
                ),

                // Network map
                GestureDetector(
                  onTapUp: _onCanvasTap,
                  onPanStart: _onCanvasPanStart,
                  onPanUpdate: _onCanvasPanUpdate,
                  onPanEnd: _onCanvasPanEnd,
                  child: AnimatedBuilder(
                    animation: _mapAnimController,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: _NetworkMapPainter(
                          nodes: _nodes,
                          animationValue: _mapAnimController.value,
                          selectedNode: _selectedNode,
                        ),
                        size: Size.infinite,
                      );
                    },
                  ),
                ),

                // Scan effect overlay
                if (_showScanEffect)
                  _ScanEffectOverlay(
                    animation: _mapAnimController,
                  ),

                // Side labels
                Positioned(
                  left: 16,
                  top: 60,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1a1f2e).withOpacity(0.9),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: const Color(0xFF00ff41).withOpacity(0.3),
                      ),
                    ),
                    child: const Text(
                      '▸ ВАША СЕТЬ',
                      style: TextStyle(
                        color: Color(0xFF00ff41),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 16,
                  top: 60,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1a1f2e).withOpacity(0.9),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: const Color(0xFFff4444).withOpacity(0.3),
                      ),
                    ),
                    child: const Text(
                      'ВРАЖДЕБНАЯ ЗОНА ◂',
                      style: TextStyle(
                        color: Color(0xFFff4444),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),

                // ── Action Panel (bottom-right) ────────────────
                if (_selectedNode != null)
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: SizedBox(
                      width: 280,
                      child: _ActionPanel(
                        node: _selectedNode!,
                        onAttack: _attackNode,
                        onDefend: _defendNode,
                        onScan: _scanNetwork,
                        onClose: () {
                          setState(() {
                            _selectedNode!.isSelected = false;
                            _selectedNode = null;
                          });
                        },
                      ),
                    ),
                  ),

                // ── Legend (bottom-left) ───────────────────────
                Positioned(
                  left: 16,
                  bottom: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1a1f2e).withOpacity(0.9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFF1a1f2e),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'ЛЕГЕНДА',
                          style: TextStyle(
                            color: Color(0xFF4a5568),
                            fontSize: 9,
                            letterSpacing: 2,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 6),
                        _legendItem(const Color(0xFF00ff41), 'Ваши узлы'),
                        _legendItem(const Color(0xFFff4444), 'Чужие узлы'),
                        _legendItem(const Color(0xFFff9800), 'Цель'),
                        _legendItem(const Color(0xFF00e5ff), 'Роутер'),
                        _legendItem(const Color(0xFFa855f7), 'База данных'),
                        const SizedBox(height: 4),
                        const Text(
                          'Перетащите свои узлы для перемещения',
                          style: TextStyle(
                            color: Color(0xFF4a5568),
                            fontSize: 8,
                            letterSpacing: 0.5,
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
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: color, width: 1.5),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFc0c8d8),
              fontSize: 9,
              letterSpacing: 0.5,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Scan Effect Overlay ─────────────────────────────────────────────────

class _ScanEffectOverlay extends StatelessWidget {
  final Animation<double> animation;

  const _ScanEffectOverlay({required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final scanProgress = (animation.value * 3) % 1.0;
        final scanRadius = scanProgress * 600;

        return CustomPaint(
          painter: _ScanRingPainter(radius: scanRadius),
          size: Size.infinite,
        );
      },
    );
  }
}

class _ScanRingPainter extends CustomPainter {
  final double radius;

  _ScanRingPainter({required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final ringPaint = Paint()
      ..color = const Color(0xFF00e5ff).withOpacity(0.3 * (1 - radius / 600))
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawCircle(center, radius, ringPaint);

    // Inner fill
    final fillPaint = Paint()
      ..color = const Color(0xFF00e5ff).withOpacity(0.03 * (1 - radius / 600));
    canvas.drawCircle(center, radius, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _ScanRingPainter oldDelegate) =>
      radius != oldDelegate.radius;
}

// ─── Mini Resource Widget ─────────────────────────────────────────────────

class _MiniResource extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;

  const _MiniResource({
    required this.icon,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}
