import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ─── Data Models ───────────────────────────────────────────────────────────────

enum NodeType {
  server('Сервер', Icons.dns, 'Высокая мощность ЦПУ и хранилище'),
  firewall('Файрвол', Icons.shield, 'Блокирует входящие атаки'),
  proxy('Прокси', Icons.vpn_lock, 'Скрывает вашу личность'),
  router('Роутер', Icons.router, 'Соединяет и направляет трафик'),
  miner('Майнер', Icons.currency_bitcoin, 'Генерирует пассивный доход'),
  scanner('Сканер', Icons.radar, 'Обнаруживает ближайшие сети');

  const NodeType(this.label, this.icon, this.description);
  final String label;
  final IconData icon;
  final String description;
}

enum NodeStatus { online, offline, upgrading, underAttack }

class NetworkNode {
  final String id;
  final NodeType type;
  final String name;
  int level;
  double health;
  int maxHealth;
  NodeStatus status;
  final String ip;
  DateTime createdAt;

  NetworkNode({
    required this.id,
    required this.type,
    required this.name,
    required this.level,
    required this.health,
    required this.maxHealth,
    required this.status,
    required this.ip,
    required this.createdAt,
  });

  double get healthPercent => health / maxHealth;
  int get upgradeCost => level * 500;
  int get destroyRefund => (level * 300 * 0.6).floor();
}

// ─── Theme Constants ──────────────────────────────────────────────────────────

class _Theme {
  static const bg = Color(0xFF0a0e17);
  static const card = Color(0xFF1a1f2e);
  static const cardHover = Color(0xFF222840);
  static const accentGreen = Color(0xFF00ff41);
  static const accentCyan = Color(0xFF00e5ff);
  static const warningRed = Color(0xFFFF0040);
  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFF8892b0);
  static const border = Color(0xFF2a3040);
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class NetworkOverviewScreen extends StatefulWidget {
  const NetworkOverviewScreen({super.key});

  @override
  State<NetworkOverviewScreen> createState() => _NetworkOverviewScreenState();
}

class _NetworkOverviewScreenState extends State<NetworkOverviewScreen>
    with TickerProviderStateMixin {
  List<NetworkNode> _nodes = [];
  int _playerCredits = 15000;
  int _playerCpu = 0;
  int _playerBandwidth = 0;
  int _playerSecurity = 0;

  late AnimationController _pulseController;
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _initNodes();
    _recalcStats();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  void _initNodes() {
    _nodes = [
      NetworkNode(
        id: 'n1',
        type: NodeType.server,
        name: 'Alpha Server',
        level: 3,
        health: 450,
        maxHealth: 500,
        status: NodeStatus.online,
        ip: '192.168.1.${10 + Random().nextInt(240)}',
        createdAt: DateTime.now().subtract(const Duration(days: 15)),
      ),
      NetworkNode(
        id: 'n2',
        type: NodeType.firewall,
        name: 'Cerberus Wall',
        level: 2,
        health: 300,
        maxHealth: 350,
        status: NodeStatus.online,
        ip: '10.0.0.${10 + Random().nextInt(240)}',
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      ),
      NetworkNode(
        id: 'n3',
        type: NodeType.proxy,
        name: 'Ghost Proxy',
        level: 1,
        health: 80,
        maxHealth: 150,
        status: NodeStatus.underAttack,
        ip: '172.16.0.${10 + Random().nextInt(240)}',
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
      NetworkNode(
        id: 'n4',
        type: NodeType.router,
        name: 'Nexus Router',
        level: 4,
        health: 600,
        maxHealth: 600,
        status: NodeStatus.online,
        ip: '10.10.10.${10 + Random().nextInt(240)}',
        createdAt: DateTime.now().subtract(const Duration(days: 20)),
      ),
      NetworkNode(
        id: 'n5',
        type: NodeType.miner,
        name: 'Crypto Miner',
        level: 2,
        health: 0,
        maxHealth: 250,
        status: NodeStatus.offline,
        ip: '192.168.2.${10 + Random().nextInt(240)}',
        createdAt: DateTime.now().subtract(const Duration(days: 8)),
      ),
    ];
  }

  void _recalcStats() {
    _playerCpu = 0;
    _playerBandwidth = 0;
    _playerSecurity = 0;
    for (final node in _nodes) {
      if (node.status == NodeStatus.online || node.status == NodeStatus.upgrading) {
        switch (node.type) {
          case NodeType.server:
            _playerCpu += node.level * 50;
          case NodeType.router:
            _playerBandwidth += node.level * 30;
          case NodeType.firewall:
            _playerSecurity += node.level * 40;
          case NodeType.proxy:
            _playerSecurity += (node.level * 15);
          case NodeType.miner:
            _playerCpu += node.level * 10;
          case NodeType.scanner:
            _playerBandwidth += node.level * 10;
        }
      }
    }
  }

  // ─── Dialogs ─────────────────────────────────────────────────────────────

  void _showBuildDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _BuildNodeDialog(
        playerCredits: _playerCredits,
        onBuild: (type) {
          final newNode = NetworkNode(
            id: 'n${DateTime.now().millisecondsSinceEpoch}',
            type: type,
            name: '${type.label} ${_nodes.length + 1}',
            level: 1,
            health: 150,
            maxHealth: 150,
            status: NodeStatus.online,
            ip: '${Random().nextInt(255)}.${Random().nextInt(255)}.${Random().nextInt(255)}.${Random().nextInt(255)}',
            createdAt: DateTime.now(),
          );
          setState(() {
            _nodes.add(newNode);
            _playerCredits -= 1000;
            _recalcStats();
          });
          Navigator.pop(context);
          _showSnackBar('Узел ${type.label} успешно развёрнут!', _Theme.accentGreen);
        },
      ),
    );
  }

  void _showUpgradeDialog(NetworkNode node) {
    if (node.upgradeCost > _playerCredits) {
      _showSnackBar('Недостаточно кредитов! Нужно ${node.upgradeCost}₿', _Theme.warningRed);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _Theme.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: _Theme.accentCyan, width: 1),
        ),
        title: const Text('Улучшить Узел'),
        titleTextStyle: const TextStyle(color: _Theme.accentCyan, fontSize: 18),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Узел: ${node.name}', style: const TextStyle(color: _Theme.textPrimary)),
            const SizedBox(height: 8),
            Text('Текущий Уровень: ${node.level}', style: const TextStyle(color: _Theme.textSecondary)),
            Text('Новый Уровень: ${node.level + 1}', style: const TextStyle(color: _Theme.accentGreen)),
            const SizedBox(height: 8),
            Text('Стоимость: ${node.upgradeCost}₿', style: const TextStyle(color: _Theme.warningRed)),
            Text('+${50 + node.level * 20} Макс. здоровье', style: const TextStyle(color: _Theme.accentGreen)),
          ],
        ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена', style: TextStyle(color: _Theme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                node.level += 1;
                node.maxHealth += 50 + node.level * 20;
                node.health = node.maxHealth.toDouble();
                _playerCredits -= node.upgradeCost;
                _recalcStats();
              });
              Navigator.pop(context);
              _showSnackBar('${node.name} улучшен до уровня ${node.level}!', _Theme.accentGreen);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _Theme.accentGreen,
              foregroundColor: _Theme.bg,
            ),
            child: const Text('Улучшить'),
          ),
        ],
      ),
    );
  }

  void _showDestroyDialog(NetworkNode node) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _Theme.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: _Theme.warningRed, width: 1),
        ),
        title: const Text('Уничтожить Узел', style: TextStyle(color: _Theme.warningRed, fontSize: 18)),
        content: Text(
          'Вы уверены, что хотите уничтожить ${node.name}?\n\n'
          'Вы получите возврат ${node.destroyRefund}₿.',
          style: const TextStyle(color: _Theme.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена', style: TextStyle(color: _Theme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _playerCredits += node.destroyRefund;
                _nodes.remove(node);
                _recalcStats();
              });
              Navigator.pop(context);
              _showSnackBar('${node.name} уничтожен. +${node.destroyRefund}₿', _Theme.warningRed);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _Theme.warningRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Уничтожить'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: color.withValues(alpha: 0.8),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Theme.bg,
      appBar: AppBar(
        backgroundColor: _Theme.card,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _Theme.accentCyan),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            const Icon(Icons.hub, color: _Theme.accentCyan, size: 22),
            const SizedBox(width: 10),
            const Text('Управление Сетью', style: TextStyle(color: _Theme.textPrimary, fontSize: 18)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _Theme.accentGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _Theme.accentGreen.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.monetization_on, color: _Theme.accentGreen, size: 16),
                  const SizedBox(width: 4),
                  Text('$_playerCredits₿', style: const TextStyle(color: _Theme.accentGreen, fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Network Stats Bar ──
          _buildStatsBar(),
          const SizedBox(height: 12),

          // ── Nodes List ──
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _nodes.length,
              itemBuilder: (context, index) => _buildNodeCard(_nodes[index], index),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showBuildDialog,
        backgroundColor: _Theme.accentGreen.withValues(alpha: 0.15),
        foregroundColor: _Theme.accentGreen,
        elevation: 0,
        icon: const Icon(Icons.add_circle),
        label: const Text('Создать Узел', style: TextStyle(fontWeight: FontWeight.bold)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: _Theme.accentGreen.withValues(alpha: 0.4)),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildStatsBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _Theme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _Theme.border),
        boxShadow: [
          BoxShadow(color: _Theme.accentCyan.withValues(alpha: 0.05), blurRadius: 20),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statChip(Icons.memory, 'ЦПУ', '$_playerCpu', _Theme.accentCyan),
          _statChip(Icons.speed, 'Канал', '${_playerBandwidth}MB/s', _Theme.accentGreen),
          _statChip(Icons.shield, 'Защита', '$_playerSecurity%', _Theme.warningRed),
          _statChip(Icons.devices, 'Узлы', '${_nodes.length}', _Theme.accentCyan),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: _Theme.textSecondary, fontSize: 11)),
      ],
    );
  }

  Widget _buildNodeCard(NetworkNode node, int index) {
    final statusColor = switch (node.status) {
      NodeStatus.online => _Theme.accentGreen,
      NodeStatus.offline => _Theme.textSecondary,
      NodeStatus.upgrading => _Theme.accentCyan,
      NodeStatus.underAttack => _Theme.warningRed,
    };
    final statusLabel = switch (node.status) {
      NodeStatus.online => 'ОНЛАЙН',
      NodeStatus.offline => 'ОФФЛАЙН',
      NodeStatus.upgrading => 'ОБНОВЛЕНИЕ',
      NodeStatus.underAttack => 'ПОД АТАКОЙ',
    };

    return AnimatedBuilder(
      listenable: _pulseController,
      builder: (context, child) {
        final pulse = node.status == NodeStatus.underAttack
            ? 1.0 + _pulseController.value * 0.02
            : 1.0;

        return Transform.scale(
          scale: pulse,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _Theme.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: node.status == NodeStatus.underAttack
                    ? _Theme.warningRed.withValues(alpha: 0.5)
                    : _Theme.border,
              ),
              boxShadow: [
                if (node.status == NodeStatus.underAttack)
                  BoxShadow(color: _Theme.warningRed.withValues(alpha: 0.1), blurRadius: 16),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _Theme.accentCyan.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _Theme.accentCyan.withValues(alpha: 0.2)),
                      ),
                      child: Icon(node.type.icon, color: _Theme.accentCyan, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(node.name, style: const TextStyle(color: _Theme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                                ),
                                child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(node.ip, style: const TextStyle(color: _Theme.textSecondary, fontSize: 12, fontFamily: 'monospace')),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Lv.${node.level}', style: const TextStyle(color: _Theme.accentGreen, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(node.type.label, style: const TextStyle(color: _Theme.textSecondary, fontSize: 11)),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // ── Health Bar ──
                Row(
                  children: [
                    const Text('ОЗ', style: TextStyle(color: _Theme.textSecondary, fontSize: 11, fontFamily: 'monospace')),
                    const SizedBox(width: 8),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Stack(
                            children: [
                              Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _Theme.bg,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 600),
                                height: 8,
                                width: constraints.maxWidth * node.healthPercent.clamp(0.0, 1.0),
                                decoration: BoxDecoration(
                                  color: node.healthPercent > 0.5
                                      ? _Theme.accentGreen
                                      : node.healthPercent > 0.25
                                          ? Colors.orange
                                          : _Theme.warningRed,
                                  borderRadius: BorderRadius.circular(4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (node.healthPercent > 0.5 ? _Theme.accentGreen : _Theme.warningRed).withValues(alpha: 0.4),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${node.health.toInt()}/${node.maxHealth}', style: const TextStyle(color: _Theme.textSecondary, fontSize: 11, fontFamily: 'monospace')),
                  ],
                ),

                const SizedBox(height: 14),

                // ── Action Buttons ──
                Row(
                  children: [
                    _actionButton(
                      icon: Icons.arrow_upward,
                      label: 'Улучшить',
                      cost: '${node.upgradeCost}₿',
                      color: _Theme.accentCyan,
                      enabled: node.status != NodeStatus.offline && _playerCredits >= node.upgradeCost,
                      onTap: () => _showUpgradeDialog(node),
                    ),
                    const SizedBox(width: 10),
                    _actionButton(
                      icon: Icons.delete_forever,
                      label: 'Уничтожить',
                      cost: '+${node.destroyRefund}₿',
                      color: _Theme.warningRed,
                      enabled: true,
                      onTap: () => _showDestroyDialog(node),
                    ),
                    const Spacer(),
                    if (node.status == NodeStatus.offline)
                      _actionButton(
                        icon: Icons.power_settings_new,
                        label: 'Перезагрузить',
                        cost: '200₿',
                        color: _Theme.accentGreen,
                        enabled: _playerCredits >= 200,
                        onTap: () {
                          if (_playerCredits >= 200) {
                            setState(() {
                              node.health = node.maxHealth.toDouble();
                              node.status = NodeStatus.online;
                              _playerCredits -= 200;
                              _recalcStats();
                            });
                            _showSnackBar('${node.name} перезагружен!', _Theme.accentGreen);
                          }
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required String cost,
    required Color color,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: enabled ? color.withValues(alpha: 0.1) : _Theme.bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled ? color.withValues(alpha: 0.3) : _Theme.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: enabled ? color : _Theme.textSecondary, size: 16),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: TextStyle(color: enabled ? color : _Theme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                Text(cost, style: TextStyle(color: enabled ? _Theme.textSecondary : _Theme.textSecondary.withValues(alpha: 0.5), fontSize: 9)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Build Node Dialog ────────────────────────────────────────────────────────

class _BuildNodeDialog extends StatelessWidget {
  final int playerCredits;
  final ValueChanged<NodeType> onBuild;

  const _BuildNodeDialog({required this.playerCredits, required this.onBuild});

  static const int baseCost = 1000;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: _Theme.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Handle ──
          Center(
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: _Theme.border, borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 16),

          // ── Title ──
          Text('Развернуть Новый Узел', style: const TextStyle(color: _Theme.accentCyan, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Доступные Кредиты: $playerCredits₿', style: const TextStyle(color: _Theme.accentGreen, fontSize: 14)),
          const SizedBox(height: 0),
          const Divider(color: _Theme.border, height: 24),

          // ── Node Types ──
          Expanded(
            child: ListView.separated(
              itemCount: NodeType.values.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final type = NodeType.values[index];
                final canAfford = playerCredits >= baseCost;
                return _buildNodeTypeCard(context, type, canAfford);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNodeTypeCard(BuildContext context, NodeType type, bool canAfford) {
    return InkWell(
      onTap: canAfford ? () => onBuild(type) : null,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: canAfford ? _Theme.cardHover : _Theme.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: canAfford ? _Theme.accentCyan.withValues(alpha: 0.3) : _Theme.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _Theme.accentCyan.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _Theme.accentCyan.withValues(alpha: 0.2)),
              ),
              child: Icon(type.icon, color: canAfford ? _Theme.accentCyan : _Theme.textSecondary, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(type.label, style: TextStyle(color: canAfford ? _Theme.textPrimary : _Theme.textSecondary, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(type.description, style: const TextStyle(color: _Theme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$baseCost₿', style: TextStyle(color: canAfford ? _Theme.accentGreen : _Theme.warningRed, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: canAfford ? _Theme.accentGreen : _Theme.warningRed,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(canAfford ? 'РАЗВЕРНУТЬ' : 'НЕТ СРЕДСТВ', style: const TextStyle(color: _Theme.bg, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper widget that builds based on an [Animation] (used for the pulse effect).
/// This wraps [AnimatedBuilder] since Flutter's built-in is [AnimatedBuilder].
class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;

  const AnimatedBuilder({
    super.key,
    required super.listenable,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }
}
