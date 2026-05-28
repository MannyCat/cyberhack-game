import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ─── Game Map Node Model ──────────────────────────────────────────────────

enum NodeType { server, firewall, database, router, terminal, target }

class GameNode {
  String id;
  String name;
  String city;
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
    required this.city,
    required this.position,
    required this.type,
    this.radius = 20,
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

// ─── World Map Data: Simplified continent polygons (lat, lng) ─────────────
// Each continent is an array of [latitude, longitude] points forming an outline.
// These are highly simplified (~15-30 points per continent) for performance.

const List<List<List<double>>> _continentPolygons = [
  // ── North America ──
  [
    [70, -165], [72, -130], [70, -100], [65, -85], [60, -75], [55, -60],
    [48, -55], [45, -65], [43, -70], [40, -74], [30, -82], [25, -80],
    [25, -90], [20, -105], [15, -92], [15, -85], [10, -84], [10, -78],
    [18, -88], [20, -87], [22, -98], [28, -96], [30, -85], [30, -82],
    [35, -76], [40, -74], [42, -70], [45, -65], [48, -55], [50, -57],
    [55, -60], [58, -66], [60, -65], [62, -75], [65, -85], [70, -100],
    [72, -130], [70, -165],
  ],
  // ── South America ──
  [
    [12, -72], [10, -68], [8, -60], [5, -52], [0, -50], [-5, -35],
    [-10, -37], [-15, -39], [-22, -41], [-28, -49], [-33, -53],
    [-40, -62], [-45, -65], [-50, -70], [-55, -68], [-55, -72],
    [-52, -75], [-46, -75], [-40, -73], [-35, -72], [-30, -71],
    [-20, -70], [-15, -75], [-5, -80], [0, -78], [5, -77],
    [10, -75], [12, -72],
  ],
  // ── Europe ──
  [
    [36, -10], [38, -8], [43, -9], [44, -1], [46, 0], [48, -5],
    [51, -5], [53, 0], [55, 8], [58, 6], [60, 5], [63, 5],
    [65, 12], [70, 20], [71, 28], [68, 30], [60, 30], [56, 24],
    [54, 14], [50, 14], [48, 17], [46, 16], [44, 15], [42, 18],
    [40, 20], [38, 24], [36, 22], [36, -10],
  ],
  // ── Africa ──
  [
    [37, 10], [35, 0], [30, -10], [20, -17], [15, -17], [10, -15],
    [5, -5], [0, 10], [-5, 12], [-10, 15], [-15, 15], [-20, 18],
    [-25, 20], [-30, 25], [-34, 18], [-35, 20], [-34, 26], [-30, 32],
    [-25, 35], [-15, 42], [-10, 42], [-5, 40], [0, 42], [5, 44],
    [10, 50], [12, 51], [15, 42], [20, 40], [25, 35], [30, 32],
    [32, 32], [35, 25], [37, 10],
  ],
  // ── Asia (mainland) ──
  [
    [42, 28], [45, 40], [42, 44], [38, 42], [35, 36], [30, 35],
    [28, 34], [25, 37], [22, 39], [18, 40], [15, 42], [12, 44],
    [10, 50], [8, 77], [10, 80], [15, 80], [20, 73], [22, 72],
    [25, 68], [22, 88], [20, 96], [15, 100], [10, 106], [5, 103],
    [1, 104], [7, 117], [12, 109], [20, 110], [22, 108], [25, 120],
    [30, 122], [35, 129], [40, 130], [42, 132], [45, 142], [50, 143],
    [55, 137], [60, 140], [65, 142], [68, 140], [70, 170],
    [72, 180], [72, 130], [70, 100], [72, 80], [70, 60], [68, 50],
    [65, 40], [60, 30], [55, 28], [50, 30], [48, 35], [45, 36],
    [42, 28],
  ],
  // ── Australia ──
  [
    [-12, 132], [-14, 127], [-18, 122], [-22, 114], [-28, 114],
    [-32, 116], [-35, 118], [-35, 138], [-38, 145], [-37, 150],
    [-33, 152], [-28, 154], [-24, 152], [-18, 146], [-14, 144],
    [-12, 142], [-11, 136], [-12, 132],
  ],
];

// ─── City data: [name, lat, lng, nodeType, isPlayerOwned] ────────────────

class _CityData {
  final String name;
  final String nodeName;
  final double lat;
  final double lng;
  final NodeType nodeType;
  final bool isPlayerOwned;
  final int firewallStrength;

  const _CityData(this.name, this.nodeName, this.lat, this.lng,
      this.nodeType, this.isPlayerOwned, this.firewallStrength);
}

const List<_CityData> _worldCities = [
  // ── Player's network ──
  _CityData('Москва', 'NEXUS-CORE', 55.75, 37.62, NodeType.server, true, 8),
  _CityData('Петербург', 'ФАЙРВОЛ-01', 59.93, 30.32, NodeType.firewall, true, 9),
  _CityData('Новосибирск', 'БД-ХРАНИЛИЩЕ', 55.01, 82.93, NodeType.database, true, 7),
  _CityData('Екатеринбург', 'РОУТЕР-ПРАЙМ', 56.83, 60.60, NodeType.router, true, 5),
  _CityData('Казань', 'ТЕРМ-АЛЬФА', 55.79, 49.11, NodeType.terminal, true, 4),

  // ── European targets ──
  _CityData('Лондон', 'CORP-UK-01', 51.51, -0.13, NodeType.server, false, 6),
  _CityData('Берлин', 'CORP-DE-01', 52.52, 13.41, NodeType.server, false, 5),
  _CityData('Париж', 'CORP-FR-01', 48.86, 2.35, NodeType.firewall, false, 7),

  // ── Asian targets ──
  _CityData('Токио', 'CORP-JP-01', 35.68, 139.69, NodeType.server, false, 8),
  _CityData('Сеул', 'CORP-KR-01', 37.57, 126.98, NodeType.firewall, false, 7),
  _CityData('Пекин', 'CORP-CN-01', 39.90, 116.40, NodeType.database, false, 9),

  // ── American targets ──
  _CityData('Нью-Йорк', 'BANK-US-01', 40.71, -74.01, NodeType.target, false, 10),
  _CityData('Сан-Франциско', 'CORP-SV-01', 37.77, -122.42, NodeType.server, false, 6),

  // ── Other targets ──
  _CityData('Дубай', 'CORP-AE-01', 25.20, 55.27, NodeType.firewall, false, 8),
  _CityData('Сингапур', 'RELAY-SG', 1.35, 103.82, NodeType.router, false, 3),
  _CityData('Сидней', 'CORP-AU-01', -33.87, 151.21, NodeType.server, false, 5),
  _CityData('Мумбаи', 'CORP-IN-01', 19.08, 72.88, NodeType.database, false, 6),
  _CityData('Сан-Паулу', 'CORP-BR-01', -23.55, -46.63, NodeType.server, false, 5),
];

// Connections between cities (by index in _worldCities)
const List<List<int>> _connections = [
  // Player internal network
  [0, 1], [0, 2], [0, 3], [0, 4], [1, 4],
  // Moscow to European targets
  [0, 5], [0, 6], [1, 7],
  // Europe interconnect
  [5, 6], [6, 7],
  // Moscow to Asian targets
  [2, 8], [2, 9], [2, 10], [3, 9],
  // Asia interconnect
  [8, 9], [9, 10],
  // Moscow to Middle East
  [0, 11], [11, 14], [14, 12],
  // Singapore hub
  [12, 8], [12, 13], [12, 14],
  // Transatlantic
  [5, 15], [7, 15],
  [15, 16], [5, 17],
  // Africa/South America
  [17, 14], [16, 17],
  // Russian network to Singapore
  [2, 12],
  // Berlin hub
  [6, 11], [6, 9],
];

// ─── Coordinate projection ────────────────────────────────────────────────

Offset _project(double lat, double lng, double w, double h) {
  const double padLat = 70;  // show up to 70°N
  const double padLng = 15;
  final x = ((lng + 180) / 360) * w;
  final y = ((padLat - lat) / (padLat + 65)) * h;
  return Offset(x, y);
}

// ─── World Map Painter ────────────────────────────────────────────────────

class _WorldMapPainter extends CustomPainter {
  final double animationValue;
  final double zoom;
  final Offset pan;

  _WorldMapPainter({required this.animationValue, this.zoom = 1.0, this.pan = Offset.zero});

  @override
  void paint(Canvas canvas, Size size) {
    // Dark ocean background
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF060a12),
    );

    // Grid lines
    _drawGrid(canvas, size);

    // Continents
    _drawContinents(canvas, size);

    // Atmospheric glow around continents
    _drawAtmosphere(canvas, size);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF00ff41).withOpacity(0.03)
      ..strokeWidth = 0.5;

    const gridSpacing = 40.0;
    for (double x = 0; x < size.width; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Equator line
    final eqY = _project(0, 0, size.width, size.height).dy;
    final eqPaint = Paint()
      ..color = const Color(0xFF00e5ff).withOpacity(0.06)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, eqY), Offset(size.width, eqY), eqPaint);
  }

  void _drawContinents(Canvas canvas, Size size) {
    for (final continent in _continentPolygons) {
      final path = Path();
      for (int i = 0; i < continent.length; i++) {
        final pt = _project(continent[i][0], continent[i][1], size.width, size.height);
        if (i == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      path.close();

      // Fill with subtle dark green
      final fillPaint = Paint()
        ..color = const Color(0xFF0a1f15).withOpacity(0.8)
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, fillPaint);

      // Glow border
      final borderPaint = Paint()
        ..color = const Color(0xFF00ff41).withOpacity(0.15)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawPath(path, borderPaint);

      // Thin bright border
      final thinBorderPaint = Paint()
        ..color = const Color(0xFF00ff41).withOpacity(0.25)
        ..strokeWidth = 0.5
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, thinBorderPaint);
    }
  }

  void _drawAtmosphere(Canvas canvas, Size size) {
    // Animated scan line (subtle horizontal pulse)
    final scanY = (animationValue * 3 % 1.0) * size.height;
    final scanPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF00ff41).withOpacity(0),
          const Color(0xFF00ff41).withOpacity(0.04),
          const Color(0xFF00ff41).withOpacity(0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, scanY - 30, size.width, 60));
    canvas.drawRect(
      Rect.fromLTWH(0, scanY - 30, size.width, 60),
      scanPaint,
    );

    // Vignette
    final vignette = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: size.width * 0.7,
        colors: [
          Colors.transparent,
          const Color(0xFF060a12).withOpacity(0.5),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignette);
  }

  @override
  bool shouldRepaint(covariant _WorldMapPainter oldDelegate) => true;
}

// ─── Network Nodes Painter (on top of world map) ─────────────────────────

class _NetworkMapPainter extends CustomPainter {
  final List<GameNode> nodes;
  final double animationValue;
  final GameNode? selectedNode;
  final double zoom;
  final Offset pan;

  _NetworkMapPainter({
    required this.nodes,
    required this.animationValue,
    this.selectedNode,
    this.zoom = 1.0,
    this.pan = Offset.zero,
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

  @override
  void paint(Canvas canvas, Size size) {
    final Set<String> drawn = {};

    // ── Draw connections ──
    for (final node in nodes) {
      for (final connId in node.connections) {
        final key = '${node.id}-$connId';
        final rev = '$connId-${node.id}';
        if (drawn.contains(key) || drawn.contains(rev)) continue;
        drawn.add(key);

        final other = nodes.where((n) => n.id == connId).firstOrNull;
        if (other == null) continue;

        final isSel = selectedNode != null &&
            (selectedNode!.id == node.id || selectedNode!.id == other.id);

        final connColor = isSel
            ? const Color(0xFF00ff41).withOpacity(0.6)
            : node.isPlayerOwned && other.isPlayerOwned
                ? const Color(0xFF00ff41).withOpacity(0.2)
                : const Color(0xFFff4444).withOpacity(0.1);

        // Curved connection (arc toward top for visual appeal)
        final midX = (node.position.dx + other.position.dx) / 2;
        final midY = min(node.position.dy, other.position.dy) -
            (node.position - other.position).distance * 0.15;

        final path = Path()
          ..moveTo(node.position.dx, node.position.dy)
          ..quadraticBezierTo(midX, midY, other.position.dx, other.position.dy);

        canvas.drawPath(
          path,
          Paint()
            ..color = connColor
            ..strokeWidth = isSel ? 2.5 : 1
            ..style = PaintingStyle.stroke,
        );

        // Data flow particles
        if (node.isOnline && other.isOnline) {
          for (int i = 0; i < 3; i++) {
            final t = ((animationValue * 1.5 + i * 0.33 + node.position.dx * 0.003) % 1.0);
            final px = (1 - t) * (1 - t) * node.position.dx +
                2 * (1 - t) * t * midX +
                t * t * other.position.dx;
            final py = (1 - t) * (1 - t) * node.position.dy +
                2 * (1 - t) * t * midY +
                t * t * other.position.dy;

            canvas.drawCircle(
              Offset(px, py),
              isSel ? 2.5 : 1.5,
              Paint()
                ..color = isSel
                    ? const Color(0xFF00ff41)
                    : const Color(0xFF00e5ff).withOpacity(0.6),
            );
          }
        }
      }
    }

    // ── Draw nodes ──
    for (final node in nodes) {
      final color = _nodeColor(node);
      final isSel = selectedNode?.id == node.id;
      final pulse = sin(animationValue * 2 * pi + node.position.dx * 0.005) * 0.2 + 0.8;

      // Selection ring
      if (isSel) {
        final selPaint = Paint()
          ..color = color.withOpacity(0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawCircle(node.position, node.radius + 10, selPaint);

        final dashAngle = animationValue * 2 * pi;
        for (int i = 0; i < 8; i++) {
          final a = dashAngle + (i * pi / 4);
          final r1 = node.radius + 14;
          final r2 = node.radius + 20;
          canvas.drawLine(
            Offset(node.position.dx + cos(a) * r1, node.position.dy + sin(a) * r1),
            Offset(node.position.dx + cos(a) * r2, node.position.dy + sin(a) * r2),
            Paint()..color = color..strokeWidth = 2..strokeCap = StrokeCap.round,
          );
        }
      }

      // Outer glow
      if (node.isOnline) {
        canvas.drawCircle(
          node.position, node.radius * 2.2,
          Paint()
            ..color = color.withOpacity(0.1 * pulse)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
        );
      }

      // Background circle
      canvas.drawCircle(
        node.position, node.radius,
        Paint()..color = isSel ? const Color(0xFF0d1117) : const Color(0xFF121825),
      );

      // Border
      canvas.drawCircle(
        node.position, node.radius,
        Paint()
          ..color = node.isOnline ? color.withOpacity(0.8) : const Color(0xFF333333)
          ..strokeWidth = isSel ? 2.5 : 1.5
          ..style = PaintingStyle.stroke,
      );

      // Health bar
      if (node.health < node.maxHealth) {
        final bw = node.radius * 2;
        final bh = 3.5;
        final by = node.position.dy + node.radius + 5;
        final bx = node.position.dx - bw / 2;
        final hp = (node.health / node.maxHealth).clamp(0.0, 1.0);

        canvas.drawRect(Rect.fromLTWH(bx, by, bw, bh), Paint()..color = const Color(0xFF333333));
        canvas.drawRect(
          Rect.fromLTWH(bx, by, bw * hp, bh),
          Paint()..color = hp > 0.5 ? const Color(0xFF00ff41) : hp > 0.25 ? const Color(0xFFffaa00) : const Color(0xFFff4444),
        );
      }

      // Online indicator
      final indPos = Offset(
        node.position.dx + node.radius * 0.7,
        node.position.dy - node.radius * 0.7,
      );
      canvas.drawCircle(
        indPos, 3.5,
        Paint()
          ..color = node.isOnline ? const Color(0xFF00ff41) : const Color(0xFFff4444)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawCircle(
        indPos, 2.5,
        Paint()..color = node.isOnline ? const Color(0xFF00ff41) : const Color(0xFFff4444),
      );

      // City name label (above node)
      final citySpan = TextSpan(
        text: node.city,
        style: TextStyle(
          color: isSel ? color : node.isOnline ? const Color(0xFF8892b0) : const Color(0xFF555555),
          fontSize: 9,
          fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
          letterSpacing: 0.5,
          fontFamily: 'monospace',
        ),
      );
      final cityPainter = TextPainter(text: citySpan, textDirection: TextDirection.ltr, textAlign: TextAlign.center);
      cityPainter.layout();
      cityPainter.paint(canvas, Offset(node.position.dx - cityPainter.width / 2, node.position.dy - node.radius - 20));

      // Node name label (below node)
      final nameSpan = TextSpan(
        text: node.name,
        style: TextStyle(
          color: isSel ? color : node.isOnline ? const Color(0xFFc0c8d8) : const Color(0xFF444444),
          fontSize: 8,
          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
          letterSpacing: 1,
          fontFamily: 'monospace',
        ),
      );
      final namePainter = TextPainter(text: nameSpan, textDirection: TextDirection.ltr, textAlign: TextAlign.center);
      namePainter.layout();
      namePainter.paint(
        canvas,
        Offset(
          node.position.dx - namePainter.width / 2,
          node.position.dy + node.radius + (node.health < node.maxHealth ? 12 : 6),
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _NetworkMapPainter oldDelegate) => true;
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
        final scanRadius = scanProgress * 800;

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

    canvas.drawCircle(
      center, radius,
      Paint()
        ..color = const Color(0xFF00e5ff).withOpacity(0.25 * (1 - radius / 800))
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    canvas.drawCircle(
      center, radius,
      Paint()..color = const Color(0xFF00e5ff).withOpacity(0.02 * (1 - radius / 800)),
    );
  }

  @override
  bool shouldRepaint(covariant _ScanRingPainter oldDelegate) => radius != oldDelegate.radius;
}

// ─── Action Panel ────────────────────────────────────────────────────────

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
            color: (node.isPlayerOwned ? const Color(0xFF00ff41) : const Color(0xFFff4444)).withOpacity(0.1),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                node.isPlayerOwned ? Icons.shield_outlined : Icons.warning_amber,
                color: node.isPlayerOwned ? const Color(0xFF00ff41) : const Color(0xFFff4444),
                size: 20,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  node.name,
                  style: TextStyle(
                    color: node.isPlayerOwned ? const Color(0xFF00ff41) : const Color(0xFFff4444),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                node.city,
                style: TextStyle(
                  color: const Color(0xFF4a5568),
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onClose,
                child: const Icon(Icons.close, color: Color(0xFF4a5568), size: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFF2a2f40), height: 1),
          const SizedBox(height: 12),
          _buildStat('ТИП', node.type.name.toUpperCase(), const Color(0xFF00e5ff)),
          const SizedBox(height: 6),
          _buildStat('ГОРОД', node.city, const Color(0xFFc0c8d8)),
          const SizedBox(height: 6),
          _buildStat('ЗДОРОВЬЕ', '${node.health.toInt()}/${node.maxHealth.toInt()}',
              node.health > 50 ? const Color(0xFF00ff41) : const Color(0xFFff4444)),
          const SizedBox(height: 6),
          _buildStat('ФАЙРВОЛ', '${node.firewallStrength}/10', const Color(0xFFff9800)),
          const SizedBox(height: 6),
          _buildStat('СТАТУС', node.isOnline ? 'ОНЛАЙН' : 'ОФФЛАЙН',
              node.isOnline ? const Color(0xFF00ff41) : const Color(0xFFff4444)),
          const SizedBox(height: 16),
          Row(
            children: [
              if (!node.isPlayerOwned) ...[
                Expanded(child: _ActionBtn(label: 'АТАКА', color: const Color(0xFFff4444), onTap: onAttack)),
                const SizedBox(width: 8),
              ],
              if (node.isPlayerOwned) ...[
                Expanded(child: _ActionBtn(label: 'ЗАЩИТА', color: const Color(0xFF00ff41), onTap: onDefend)),
                const SizedBox(width: 8),
              ],
              Expanded(child: _ActionBtn(label: 'СКАН', color: const Color(0xFF00e5ff), onTap: onScan)),
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
        Text(label, style: const TextStyle(color: Color(0xFF4a5568), fontSize: 10, letterSpacing: 1.5, fontFamily: 'monospace')),
        Text(value, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1, fontFamily: 'monospace')),
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
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: _pressed ? widget.color.withOpacity(0.3) : widget.color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: widget.color.withOpacity(_pressed ? 0.8 : 0.4)),
          boxShadow: _pressed ? [BoxShadow(color: widget.color.withOpacity(0.2), blurRadius: 10)] : [],
        ),
        child: Center(
          child: Text(
            widget.label,
            style: TextStyle(
              color: widget.color, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontFamily: 'monospace',
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Game Map Screen ─────────────────────────────────────────────────────

class GameMapScreen extends StatefulWidget {
  const GameMapScreen({super.key});

  @override
  State<GameMapScreen> createState() => _GameMapScreenState();
}

class _GameMapScreenState extends State<GameMapScreen> with TickerProviderStateMixin {
  late AnimationController _mapAnimController;
  late AnimationController _gridScrollController;
  late List<GameNode> _nodes;
  final _random = Random(1337);

  GameNode? _selectedNode;
  bool _showScanEffect = false;
  GameNode? _draggingNode;

  // Zoom/Pan state
  final TransformationController _transformController = TransformationController();
  double _currentZoom = 1.0;

  @override
  void initState() {
    super.initState();
    _mapAnimController = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
    _gridScrollController = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
    _transformController.addListener(() {
      setState(() => _currentZoom = _transformController.value.getMaxScaleOnAxis());
    });
    _initNodes();
  }

  @override
  void dispose() {
    _mapAnimController.dispose();
    _gridScrollController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  void _initNodes() {
    _nodes = [];
    String idPrefix(int idx) => 'n$idx';

    for (int i = 0; i < _worldCities.length; i++) {
      final city = _worldCities[i];
      _nodes.add(GameNode(
        id: idPrefix(i),
        name: city.nodeName,
        city: city.name,
        position: Offset.zero, // Will be computed in build based on size
        type: city.nodeType,
        isPlayerOwned: city.isPlayerOwned,
        health: (city.isPlayerOwned ? 100.0 : 60.0 + _random.nextInt(40)),
        maxHealth: 100,
        firewallStrength: city.firewallStrength,
        attackPower: 3 + _random.nextInt(10),
        connections: [],
      ));
    }

    // Wire connections
    for (final conn in _connections) {
      if (conn[0] < _nodes.length && conn[1] < _nodes.length) {
        _nodes[conn[0]].connections.add(idPrefix(conn[1]));
      }
    }
  }

  void _recomputePositions(Size size) {
    for (int i = 0; i < _worldCities.length && i < _nodes.length; i++) {
      _nodes[i].position = _project(_worldCities[i].lat, _worldCities[i].lng, size.width, size.height);
    }
  }

  void _onCanvasTap(TapUpDetails details) {
    // Convert screen coordinates to map coordinates (accounting for zoom/pan)
    final tapPos = details.localPosition;
    GameNode? tapped;

    for (final node in _nodes) {
      final dist = (tapPos - node.position).distance;
      if (dist <= node.radius + 12) {
        tapped = node;
        break;
      }
    }

    setState(() {
      for (final n in _nodes) { n.isSelected = false; }
      if (tapped != null) {
        tapped.isSelected = true;
        _selectedNode = tapped;
      } else {
        _selectedNode = null;
      }
    });
  }

  void _onCanvasPanStart(DragStartDetails details) {
    final pos = details.localPosition;
    for (final node in _nodes) {
      if ((pos - node.position).distance <= node.radius + 8 && node.isPlayerOwned) {
        setState(() => _draggingNode = node);
        return;
      }
    }
  }

  void _onCanvasPanUpdate(DragUpdateDetails details) {
    if (_draggingNode != null) {
      _draggingNode!.position += details.delta;
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
        _selectedNode!.health = max(0, _selectedNode!.health - _random.nextInt(15) - 5);
        if (_selectedNode!.health <= 0) _selectedNode!.isOnline = false;
      });
    }
  }

  void _defendNode() {
    if (_selectedNode != null && _selectedNode!.isPlayerOwned) {
      setState(() {
        _selectedNode!.health = min(_selectedNode!.maxHealth, _selectedNode!.health + 10);
        _selectedNode!.isOnline = true;
      });
    }
  }

  void _resetView() {
    setState(() {
      _transformController.value = Matrix4.identity();
    });
  }

  void _centerOnRussia() {
    final Size size = MediaQuery.of(context).size;
    final moscow = _project(55.75, 37.62, size.width, size.height);
    final scale = 2.0;
    final tx = (size.width / 2 - moscow.dx * scale).clamp(-1000.0, 1000.0);
    final ty = (size.height / 2 - moscow.dy * scale).clamp(-1000.0, 1000.0);
    setState(() {
      _transformController.value = Matrix4.identity()
        ..translate(tx, ty)
        ..scale(scale);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0e17),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final mapSize = Size(constraints.maxWidth, constraints.maxHeight);
          _recomputePositions(mapSize);

          return Column(
            children: [
              // ── Top Bar ──
              _buildTopBar(),
              // ── Map Area ──
              Expanded(
                child: Stack(
                  children: [
                    // World map background (no interaction)
                    AnimatedBuilder(
                      animation: _gridScrollController,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: _WorldMapPainter(
                            animationValue: _mapAnimController.value,
                            zoom: _currentZoom,
                          ),
                          size: mapSize,
                        );
                      },
                    ),

                    // Network nodes layer (with interaction)
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
                              zoom: _currentZoom,
                            ),
                            size: mapSize,
                          );
                        },
                      ),
                    ),

                    // Scan effect
                    if (_showScanEffect) _ScanEffectOverlay(animation: _mapAnimController),

                    // ── Zoom controls (bottom-right) ──
                    Positioned(
                      right: 16,
                      top: 16,
                      child: Column(
                        children: [
                          _zoomButton(Icons.add, () {
                            final v = _transformController.value.clone()..scale(1.3);
                            setState(() => _transformController.value = v);
                          }),
                          const SizedBox(height: 4),
                          _zoomButton(Icons.remove, () {
                            final v = _transformController.value.clone()..scale(1 / 1.3);
                            setState(() => _transformController.value = v);
                          }),
                          const SizedBox(height: 4),
                          _zoomButton(Icons.my_location, _centerOnRussia),
                          const SizedBox(height: 4),
                          _zoomButton(Icons.fit_screen, _resetView),
                        ],
                      ),
                    ),

                    // ── Node count badges ──
                    Positioned(
                      left: 16,
                      top: 16,
                      child: _infoBadge('ВАШИ УЗЛЫ', '${_nodes.where((n) => n.isPlayerOwned).length}', const Color(0xFF00ff41)),
                    ),
                    Positioned(
                      left: 16,
                      top: 56,
                      child: _infoBadge('ЦЕЛИ', '${_nodes.where((n) => !n.isPlayerOwned).length}', const Color(0xFFff4444)),
                    ),

                    // ── Action Panel (bottom-right) ──
                    if (_selectedNode != null)
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: SizedBox(
                          width: 300,
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

                    // ── Legend (bottom-left) ──
                    Positioned(
                      left: 16,
                      bottom: 16,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1a1f2e).withOpacity(0.9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF2a2f40)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('ЛЕГЕНДА', style: TextStyle(color: Color(0xFF4a5568), fontSize: 9, letterSpacing: 2, fontFamily: 'monospace')),
                            const SizedBox(height: 6),
                            _legendItem(const Color(0xFF00ff41), 'Ваши узлы'),
                            _legendItem(const Color(0xFFff4444), 'Чужие узлы'),
                            _legendItem(const Color(0xFF00e5ff), 'Файрвол / Терминал'),
                            _legendItem(const Color(0xFFa855f7), 'База данных'),
                            _legendItem(const Color(0xFFcc3300), 'Роутер'),
                            const SizedBox(height: 4),
                            const Text('Используйте +/- для масштабирования',
                                style: TextStyle(color: Color(0xFF4a5568), fontSize: 8, letterSpacing: 0.5, fontFamily: 'monospace')),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1f2e),
        border: Border(bottom: BorderSide(color: const Color(0xFF00ff41).withOpacity(0.2))),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.go('/main-menu'),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0d1117),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFF00e5ff).withOpacity(0.3)),
              ),
              child: const Icon(Icons.arrow_back, color: Color(0xFF00e5ff), size: 18),
            ),
          ),
          const SizedBox(width: 16),
          const Text('◆ ГЛОБАЛЬНАЯ КАРТА СЕТИ',
              style: TextStyle(color: Color(0xFF00ff41), fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 2, fontFamily: 'monospace')),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF00ff41).withOpacity(0.1),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: const Color(0xFF00ff41).withOpacity(0.3)),
            ),
            child: Text('${_nodes.length} УЗЛОВ', style: const TextStyle(color: Color(0xFF00ff41), fontSize: 10, letterSpacing: 1, fontFamily: 'monospace')),
          ),
          const Spacer(),

          // Scan button
          GestureDetector(
            onTap: _scanNetwork,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [const Color(0xFF00e5ff).withOpacity(0.8), const Color(0xFF009eb8)]),
                borderRadius: BorderRadius.circular(4),
                boxShadow: [BoxShadow(color: const Color(0xFF00e5ff).withOpacity(0.3), blurRadius: 10)],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sensors, color: Color(0xFF0a0e17), size: 16),
                  SizedBox(width: 6),
                  Text('СКАНИРОВАТЬ', style: TextStyle(color: Color(0xFF0a0e17), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontFamily: 'monospace')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _zoomButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF1a1f2e).withOpacity(0.9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF2a2f40)),
        ),
        child: Icon(icon, color: const Color(0xFF00e5ff), size: 18),
      ),
    );
  }

  Widget _infoBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1f2e).withOpacity(0.9),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: const TextStyle(color: Color(0xFF4a5568), fontSize: 9, letterSpacing: 1, fontFamily: 'monospace')),
          Text(value, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1, fontFamily: 'monospace')),
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
            width: 10, height: 10,
            decoration: BoxDecoration(
              color: color.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: color, width: 1.5),
            ),
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Color(0xFFc0c8d8), fontSize: 9, letterSpacing: 0.5, fontFamily: 'monospace')),
        ],
      ),
    );
  }
}
