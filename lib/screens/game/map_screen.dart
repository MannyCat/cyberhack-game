import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';

// ─── Game Map Node Model ──────────────────────────────────────────────────

enum NodeType { server, firewall, database, router, terminal, target }

class GameNode {
  String id;
  String name;
  String city;
  LatLng position;
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

// ─── City data ─────────────────────────────────────────────────────────────

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

const List<List<int>> _connections = [
  [0, 1], [0, 2], [0, 3], [0, 4], [1, 4],
  [0, 5], [0, 6], [1, 7],
  [5, 6], [6, 7],
  [2, 8], [2, 9], [2, 10], [3, 9],
  [8, 9], [9, 10],
  [0, 11], [11, 14], [14, 12],
  [12, 8], [12, 13], [12, 14],
  [5, 15], [7, 15],
  [15, 16], [5, 17],
  [17, 14], [16, 17],
  [2, 12],
  [6, 11], [6, 9],
];

// ─── Cyber Marker Widget ──────────────────────────────────────────────────

class _CyberMarker extends StatelessWidget {
  final GameNode node;
  final VoidCallback onTap;

  const _CyberMarker({required this.node, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _nodeColor(node);
    return GestureDetector(
      onDoubleTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: node.isSelected ? 48 : 38,
        height: node.isSelected ? 48 : 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF0a0e17).withValues(alpha: 0.85),
          border: Border.all(
            color: node.isOnline ? color : const Color(0xFF333333),
            width: node.isSelected ? 3 : 1.5,
          ),
          boxShadow: [
            if (node.isOnline)
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: node.isSelected ? 18 : 10,
                spreadRadius: node.isSelected ? 2 : 0,
              ),
          ],
        ),
        child: Center(
          child: Icon(
            _nodeIcon(node.type),
            color: node.isOnline ? color : const Color(0xFF555555),
            size: node.isSelected ? 22 : 16,
          ),
        ),
      ),
    );
  }

  Color _nodeColor(GameNode node) {
    if (!node.isOnline) return const Color(0xFF333333);
    switch (node.type) {
      case NodeType.server:
        return node.isPlayerOwned ? const Color(0xFF00ff41) : const Color(0xFFff4444);
      case NodeType.firewall:
        return node.isPlayerOwned ? const Color(0xFF00e5ff) : const Color(0xFFff6600);
      case NodeType.database:
        return node.isPlayerOwned ? const Color(0xFFa855f7) : const Color(0xFFff9800);
      case NodeType.router:
        return node.isPlayerOwned ? const Color(0xFF00cc88) : const Color(0xFFcc3300);
      case NodeType.terminal:
        return const Color(0xFF00e5ff);
      case NodeType.target:
        return const Color(0xFFff4444);
    }
  }

  IconData _nodeIcon(NodeType type) {
    switch (type) {
      case NodeType.server: return Icons.dns;
      case NodeType.firewall: return Icons.shield;
      case NodeType.database: return Icons.storage;
      case NodeType.router: return Icons.router;
      case NodeType.terminal: return Icons.terminal;
      case NodeType.target: return Icons.gps_fixed;
    }
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
    canvas.drawCircle(center, radius,
      Paint()
        ..color = const Color(0xFF00e5ff).withValues(alpha: 0.25 * (1 - radius / 600))
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(center, radius,
      Paint()..color = const Color(0xFF00e5ff).withValues(alpha: 0.02 * (1 - radius / 600)),
    );
  }

  @override
  bool shouldRepaint(covariant _ScanRingPainter oldDelegate) => radius != oldDelegate.radius;
}

// ─── Action Panel (right side, PC style) ──────────────────────────────────

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
      width: 320,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1f2e).withValues(alpha: 0.96),
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
        border: Border(
          left: BorderSide(
            color: node.isPlayerOwned
                ? const Color(0xFF00ff41).withValues(alpha: 0.5)
                : const Color(0xFFff4444).withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(-4, 0),
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
              Icon(node.isPlayerOwned ? Icons.shield_outlined : Icons.warning_amber,
                  color: node.isPlayerOwned ? const Color(0xFF00ff41) : const Color(0xFFff4444), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(node.name,
                  style: TextStyle(
                    color: node.isPlayerOwned ? const Color(0xFF00ff41) : const Color(0xFFff4444),
                    fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2, fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Text(node.city, style: const TextStyle(color: Color(0xFF4a5568), fontSize: 11, fontFamily: 'monospace')),
              const SizedBox(width: 8),
              GestureDetector(onTap: onClose, child: const Icon(Icons.close, color: Color(0xFF4a5568), size: 20)),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFF2a2f40), height: 1),
          const SizedBox(height: 14),
          _buildStat('ТИП', node.type.name.toUpperCase(), const Color(0xFF00e5ff)),
          const SizedBox(height: 8),
          _buildStat('ГОРОД', node.city, const Color(0xFFc0c8d8)),
          const SizedBox(height: 8),
          _buildStat('ЗДОРОВЬЕ', '${node.health.toInt()}/${node.maxHealth.toInt()}',
              node.health > 50 ? const Color(0xFF00ff41) : const Color(0xFFff4444)),
          const SizedBox(height: 8),
          _buildStat('ФАЙРВОЛ', '${node.firewallStrength}/10', const Color(0xFFff9800)),
          const SizedBox(height: 8),
          _buildStat('СТАТУС', node.isOnline ? 'ОНЛАЙН' : 'ОФФЛАЙН',
              node.isOnline ? const Color(0xFF00ff41) : const Color(0xFFff4444)),
          const SizedBox(height: 20),
          Row(
            children: [
              if (!node.isPlayerOwned) ...[
                Expanded(child: _ActionBtn(label: 'АТАКА', color: const Color(0xFFff4444), onTap: onAttack)),
                const SizedBox(width: 10),
              ],
              if (node.isPlayerOwned) ...[
                Expanded(child: _ActionBtn(label: 'ЗАЩИТА', color: const Color(0xFF00ff41), onTap: onDefend)),
                const SizedBox(width: 10),
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
        Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1, fontFamily: 'monospace')),
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
    return MouseRegion(
      onEnter: (_) => setState(() => _pressed = true),
      onExit: (_) => setState(() => _pressed = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: _pressed ? widget.color.withValues(alpha: 0.3) : widget.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: widget.color.withValues(alpha: _pressed ? 0.8 : 0.4)),
            boxShadow: _pressed ? [BoxShadow(color: widget.color.withValues(alpha: 0.2), blurRadius: 10)] : [],
          ),
          child: Center(
            child: Text(widget.label,
              style: TextStyle(color: widget.color, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontFamily: 'monospace'),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Mission Card Widget ─────────────────────────────────────────────────

class _MissionCard extends StatelessWidget {
  final Mission mission;
  final VoidCallback? onClaim;

  const _MissionCard({required this.mission, this.onClaim});

  IconData get _missionIcon {
    final icon = mission.icon;
    if (icon is IconData) return icon;
    switch (mission.type) {
      case MissionType.deployNode: return Icons.dns;
      case MissionType.attackPlayer: return Icons.gps_fixed;
      case MissionType.buyItem: return Icons.shopping_cart;
      case MissionType.upgradeNode: return Icons.arrow_upward;
    }
  }

  @override
  Widget build(BuildContext context) {
    final progressRatio = mission.target > 0
        ? (mission.progress.clamp(0, mission.target) / mission.target) : 0.0;
    final isReady = mission.isComplete && !mission.isClaimed;
    final isDone = mission.isClaimed;

    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1f2e).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDone ? const Color(0xFF4a5568).withValues(alpha: 0.4)
              : isReady ? const Color(0xFF00ff41).withValues(alpha: 0.6)
              : const Color(0xFF00e5ff).withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: isDone ? const Color(0xFF4a5568).withValues(alpha: 0.2)
                      : isReady ? const Color(0xFF00ff41).withValues(alpha: 0.15)
                      : const Color(0xFF00e5ff).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDone ? const Color(0xFF4a5568).withValues(alpha: 0.3)
                        : isReady ? const Color(0xFF00ff41).withValues(alpha: 0.4)
                        : const Color(0xFF00e5ff).withValues(alpha: 0.2),
                  ),
                ),
                child: Icon(_missionIcon, color: isDone ? const Color(0xFF4a5568)
                    : isReady ? const Color(0xFF00ff41)
                    : const Color(0xFF00e5ff), size: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(mission.title,
                  style: TextStyle(color: isDone ? const Color(0xFF4a5568) : const Color(0xFFe0e6f0),
                      fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace', letterSpacing: 0.5),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(mission.description, style: const TextStyle(color: Color(0xFF6a7080), fontSize: 9, fontFamily: 'monospace')),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progressRatio, minHeight: 4,
              backgroundColor: const Color(0xFF2a2f40),
              valueColor: AlwaysStoppedAnimation<Color>(isDone ? const Color(0xFF4a5568)
                  : isReady ? const Color(0xFF00ff41) : const Color(0xFF00e5ff)),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.monetization_on, color: Color(0xFFffcc00), size: 11),
              const SizedBox(width: 3),
              Text('+${mission.rewardCredits}', style: const TextStyle(color: Color(0xFFffcc00), fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              const Icon(Icons.star, color: Color(0xFFa855f7), size: 11),
              const SizedBox(width: 3),
              Text('+${mission.rewardXp}', style: const TextStyle(color: Color(0xFFa855f7), fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
              const Spacer(),
              if (isDone)
                const Text('✓', style: TextStyle(color: Color(0xFF4a5568), fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace'))
              else if (isReady)
                GestureDetector(
                  onTap: onClaim,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00ff41).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF00ff41).withValues(alpha: 0.5)),
                    ),
                    child: const Text('ЗАБРАТЬ', style: TextStyle(color: Color(0xFF00ff41), fontSize: 9, fontWeight: FontWeight.bold, fontFamily: 'monospace', letterSpacing: 0.5)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Game Map Screen — PC Layout (Vikings-style world map) ────────────────

class GameMapScreen extends StatefulWidget {
  const GameMapScreen({super.key});

  @override
  State<GameMapScreen> createState() => _GameMapScreenState();
}

class _GameMapScreenState extends State<GameMapScreen> with TickerProviderStateMixin {
  late AnimationController _mapAnimController;
  late List<GameNode> _nodes;
  final _random = Random(1337);

  GameNode? _selectedNode;
  bool _showScanEffect = false;

  final MapController _mapController = MapController();
  static const LatLng _initialCenter = LatLng(50.0, 40.0);
  static const double _initialZoom = 3.5;

  @override
  void initState() {
    super.initState();
    _mapAnimController = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
    _initNodes();
  }

  @override
  void dispose() {
    _mapAnimController.dispose();
    super.dispose();
  }

  void _initNodes() {
    _nodes = [];
    for (int i = 0; i < _worldCities.length; i++) {
      final city = _worldCities[i];
      _nodes.add(GameNode(
        id: 'n$i', name: city.nodeName, city: city.name,
        position: LatLng(city.lat, city.lng), type: city.nodeType,
        isPlayerOwned: city.isPlayerOwned,
        health: (city.isPlayerOwned ? 100.0 : 60.0 + _random.nextInt(40)),
        maxHealth: 100, firewallStrength: city.firewallStrength,
        attackPower: 3 + _random.nextInt(10), connections: [],
      ));
    }
    for (final conn in _connections) {
      if (conn[0] < _nodes.length && conn[1] < _nodes.length) {
        _nodes[conn[0]].connections.add('n${conn[1]}');
      }
    }
  }

  void _onNodeTap(GameNode node) {
    setState(() {
      for (final n in _nodes) { n.isSelected = false; }
      node.isSelected = true;
      _selectedNode = node;
      _mapController.move(node.position, 6.0);
    });
  }

  void _onMapTap(TapPosition? tapPosition, LatLng point) {
    if (_selectedNode != null) {
      setState(() { _selectedNode!.isSelected = false; _selectedNode = null; });
    }
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

  void _resetView() => _mapController.move(_initialCenter, _initialZoom);
  void _centerOnRussia() => _mapController.move(const LatLng(55.75, 37.62), 5.0);

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0a0e17),
      body: Stack(
        children: [
          // ── Full-screen Map ──
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: _initialZoom,
              minZoom: 2.0,
              maxZoom: 18.0,
              onTap: _onMapTap,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
              backgroundColor: const Color(0xFF060a12),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                userAgentPackageName: 'com.cyberhack.game',
                maxZoom: 19,
              ),
              _buildConnectionPolylines(),
              MarkerLayer(
                markers: _nodes.map((node) => Marker(
                  point: node.position,
                  width: node.isSelected ? 48 : 38,
                  height: node.isSelected ? 48 : 38,
                  child: _CyberMarker(node: node, onTap: () => _onNodeTap(node)),
                )).toList(),
              ),
              if (_selectedNode != null)
                MarkerLayer(markers: [
                  Marker(point: _selectedNode!.position, width: 260, height: 0,
                      alignment: Alignment.topCenter, child: const SizedBox.shrink()),
                ]),
            ],
          ),

          // ── Scan effect overlay ──
          if (_showScanEffect) _ScanEffectOverlay(animation: _mapAnimController),

          // ── Mini Player Card (top-left) ──
          Positioned(
            top: 12, left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1a1f2e).withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF00ff41).withValues(alpha: 0.25)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 12)],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF00ff41).withValues(alpha: 0.12),
                      border: Border.all(color: const Color(0xFF00ff41).withValues(alpha: 0.4)),
                    ),
                    child: Center(
                      child: Text('${game.level}',
                        style: const TextStyle(color: Color(0xFF00ff41), fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.account_balance_wallet, color: Color(0xFFffcc00), size: 14),
                          const SizedBox(width: 4),
                          Text('${game.credits} ¢', style: const TextStyle(color: Color(0xFFffcc00), fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                          const SizedBox(width: 16),
                          const Icon(Icons.dns, color: Color(0xFF00e5ff), size: 14),
                          const SizedBox(width: 4),
                          Text('${game.networkNodes.length} узл.', style: const TextStyle(color: Color(0xFF00e5ff), fontSize: 12, fontFamily: 'monospace')),
                          const SizedBox(width: 16),
                          const Icon(Icons.trending_up, color: Color(0xFF00ff41), size: 12),
                          const SizedBox(width: 4),
                          Text('+${game.passiveIncomePerTick} ¢/30с', style: TextStyle(color: const Color(0xFF00ff41).withValues(alpha: 0.7), fontSize: 11, fontFamily: 'monospace')),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Map Title Bar (top-center) ──
          Positioned(
            top: 12, left: 320, right: 12,
            child: Row(
              children: [
                const Text('◆ ГЛОБАЛЬНАЯ КАРТА СЕТИ',
                    style: TextStyle(color: Color(0xFF00ff41), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontFamily: 'monospace')),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00ff41).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF00ff41).withValues(alpha: 0.25)),
                  ),
                  child: Text('${_nodes.length} УЗЛОВ', style: const TextStyle(color: Color(0xFF00ff41), fontSize: 10, letterSpacing: 1, fontFamily: 'monospace')),
                ),
                const Spacer(),
                // Node count badges
                _infoBadge('ВАШИ', '${_nodes.where((n) => n.isPlayerOwned).length}', const Color(0xFF00ff41)),
                const SizedBox(width: 8),
                _infoBadge('ЦЕЛИ', '${_nodes.where((n) => !n.isPlayerOwned).length}', const Color(0xFFff4444)),
                const SizedBox(width: 12),
                // Scan button
                _cyberButton(Icons.sensors, 'СКАН', const Color(0xFF00e5ff), _scanNetwork),
              ],
            ),
          ),

          // ── Zoom controls (right side, compact vertical) ──
          Positioned(
            right: 12, top: 60,
            child: Column(
              children: [
                _zoomButton(Icons.add, () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1)),
                const SizedBox(height: 4),
                _zoomButton(Icons.remove, () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1)),
                const SizedBox(height: 4),
                _zoomButton(Icons.my_location, _centerOnRussia),
                const SizedBox(height: 4),
                _zoomButton(Icons.fit_screen, _resetView),
              ],
            ),
          ),

          // ── Action Panel (right side) ──
          if (_selectedNode != null)
            Positioned(
              right: 0, top: 0, bottom: 0,
              child: SingleChildScrollView(
                child: _ActionPanel(
                  node: _selectedNode!,
                  onAttack: _attackNode,
                  onDefend: _defendNode,
                  onScan: _scanNetwork,
                  onClose: () { setState(() { _selectedNode!.isSelected = false; _selectedNode = null; }); },
                ),
              ),
            ),

          // ── Missions Panel (bottom, horizontal strip) ──
          Positioned(
            left: 12, right: _selectedNode != null ? 332 : 12, bottom: 12,
            child: _buildMissionsPanel(game),
          ),

          // ── Legend (bottom-right corner, compact) ──
          if (_selectedNode == null)
            Positioned(
              right: 12, bottom: 12,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1a1f2e).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
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
                    const Text('Двойной клик → действия', style: TextStyle(color: Color(0xFF4a5568), fontSize: 8, letterSpacing: 0.5, fontFamily: 'monospace')),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Missions Panel (horizontal strip for PC) ──

  Widget _buildMissionsPanel(GameProvider game) {
    final missions = game.missions;
    if (missions.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 140,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF0d1117).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00e5ff).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 6, bottom: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.assignment, color: Color(0xFF00e5ff), size: 14),
                SizedBox(width: 6),
                Text('МИССИИ', style: TextStyle(color: Color(0xFF00e5ff), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2, fontFamily: 'monospace')),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: missions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final mission = missions[index];
                return _MissionCard(
                  mission: mission,
                  onClaim: () => game.claimMission(mission),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──

  Widget _buildConnectionPolylines() {
    final nodeMap = {for (var n in _nodes) n.id: n};
    final polylines = <Polyline>[];

    for (final node in _nodes) {
      for (final connId in node.connections) {
        final target = nodeMap[connId];
        if (target != null && node.id.compareTo(target.id) < 0) {
          final isPlayerConn = node.isPlayerOwned && target.isPlayerOwned;
          polylines.add(Polyline(
            points: [node.position, target.position],
            strokeWidth: isPlayerConn ? 2.5 : 1.2,
            color: isPlayerConn
                ? const Color(0xFF00ff41).withValues(alpha: 0.35)
                : const Color(0xFF3a4060).withValues(alpha: 0.4),
          ));
        }
      }
    }
    return PolylineLayer(polylines: polylines);
  }

  Widget _zoomButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF1a1f2e).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF2a2f40)),
        ),
        child: Icon(icon, color: const Color(0xFF00e5ff), size: 18),
      ),
    );
  }

  Widget _infoBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: TextStyle(color: color.withValues(alpha: 0.6), fontSize: 9, letterSpacing: 1, fontFamily: 'monospace')),
          Text(value, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _cyberButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1, fontFamily: 'monospace')),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 4)])),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Color(0xFF6a7080), fontSize: 9, fontFamily: 'monospace')),
      ],
    );
  }
}

