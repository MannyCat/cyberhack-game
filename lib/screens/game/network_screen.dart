import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../providers/auth_provider.dart';

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

// ─── Маппинг типов узлов ────────────────────────────────────────────────────

String _nodeTypeLabel(String nodeType) {
  return switch (nodeType.toLowerCase()) {
    'server' => 'Сервер',
    'firewall' => 'Файрвол',
    'proxy' => 'Прокси',
    'router' => 'Роутер',
    'miner' => 'Майнер',
    'scanner' => 'Сканер',
    'database' => 'База данных',
    'terminal' => 'Терминал',
    _ => nodeType,
  };
}

IconData _nodeTypeIcon(String nodeType) {
  return switch (nodeType.toLowerCase()) {
    'server' => Icons.dns,
    'firewall' => Icons.shield,
    'proxy' => Icons.vpn_lock,
    'router' => Icons.router,
    'miner' => Icons.currency_bitcoin,
    'scanner' => Icons.sensors,
    'database' => Icons.storage,
    'terminal' => Icons.terminal,
    _ => Icons.devices,
  };
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class NetworkOverviewScreen extends StatefulWidget {
  const NetworkOverviewScreen({super.key});

  @override
  State<NetworkOverviewScreen> createState() => _NetworkOverviewScreenState();
}

class _NetworkOverviewScreenState extends State<NetworkOverviewScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  int _calcTotalCpu(List<NetworkNode> nodes) {
    int total = 0;
    for (final n in nodes) {
      if (n.isOnline) {
        final t = n.nodeType.toLowerCase();
        if (t == 'server') total += n.nodeLevel * 50;
        else if (t == 'miner') total += n.nodeLevel * 10;
      }
    }
    return total;
  }

  int _calcTotalBandwidth(List<NetworkNode> nodes) {
    int total = 0;
    for (final n in nodes) {
      if (n.isOnline) {
        final t = n.nodeType.toLowerCase();
        if (t == 'router') total += n.nodeLevel * 30;
        else if (t == 'scanner') total += n.nodeLevel * 10;
      }
    }
    return total;
  }

  int _calcTotalSecurity(List<NetworkNode> nodes) {
    int total = 0;
    for (final n in nodes) {
      if (n.isOnline) {
        final t = n.nodeType.toLowerCase();
        if (t == 'firewall') total += n.nodeLevel * 40;
        else if (t == 'proxy') total += n.nodeLevel * 15;
      }
    }
    return total;
  }

  int _upgradeCost(NetworkNode node) => node.nodeLevel * 500;

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    final auth = context.watch<AuthProvider>();
    final nodes = game.networkNodes;
    final credits = game.credits;

    if (auth.userId == null) {
      return Scaffold(
        backgroundColor: _Theme.bg,
        appBar: AppBar(
          backgroundColor: _Theme.card,
          elevation: 0,
          title: const Text('Управление Сетью'),
        ),
        body: const Center(
          child: Text('Не авторизован', style: TextStyle(color: _Theme.textSecondary)),
        ),
      );
    }

    final totalCpu = _calcTotalCpu(nodes);
    final totalBw = _calcTotalBandwidth(nodes);
    final totalSec = _calcTotalSecurity(nodes);

    return Scaffold(
      backgroundColor: _Theme.bg,
      appBar: AppBar(
        backgroundColor: _Theme.card,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _Theme.accentCyan),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            const Icon(Icons.account_tree, color: _Theme.accentCyan, size: 22),
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
                  Text('$credits\u20BF', style: const TextStyle(color: _Theme.accentGreen, fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Network Stats Bar ──
          _buildStatsBar(totalCpu, totalBw, totalSec, nodes.length),
          const SizedBox(height: 12),

          // ── Nodes List ──
          Expanded(
            child: nodes.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: () => game.refreshNetworkNodes(auth.userId!),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: nodes.length,
                      itemBuilder: (context, index) =>
                          _buildNodeCard(nodes[index], credits, game, auth),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showBuildDialog(game, auth),
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.dns_outlined, size: 64, color: _Theme.accentCyan.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            const Text('Сеть пуста', style: TextStyle(color: _Theme.accentCyan, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Разверните первый узел, чтобы начать!', style: TextStyle(color: _Theme.textSecondary, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsBar(int cpu, int bw, int sec, int nodeCount) {
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
          _statChip(Icons.memory, 'ЦПУ', '$cpu', _Theme.accentCyan),
          _statChip(Icons.speed, 'Канал', '${bw}MB/s', _Theme.accentGreen),
          _statChip(Icons.shield, 'Защита', '$sec%', _Theme.warningRed),
          _statChip(Icons.devices, 'Узлы', '$nodeCount', _Theme.accentCyan),
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

  Widget _buildNodeCard(NetworkNode node, int credits, GameProvider game, AuthProvider auth) {
    final isOnline = node.isOnline;
    final statusColor = isOnline ? _Theme.accentGreen : _Theme.textSecondary;
    final statusLabel = isOnline ? 'ОНЛАЙН' : 'ОФФЛАЙН';
    final healthPercent = node.maxHealth > 0 ? node.health / node.maxHealth : 0.0;
    final upgradeCost = _upgradeCost(node);

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _Theme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _Theme.border),
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
                    child: Icon(_nodeTypeIcon(node.nodeType), color: _Theme.accentCyan, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('${_nodeTypeLabel(node.nodeType)} #${node.id.substring(0, 6)}',
                                style: const TextStyle(color: _Theme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
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
                        Text('УР ${node.nodeLevel}', style: const TextStyle(color: _Theme.textSecondary, fontSize: 12)),
                      ],
                    ),
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
                              width: constraints.maxWidth * healthPercent.clamp(0.0, 1.0),
                              decoration: BoxDecoration(
                                color: healthPercent > 0.5 ? _Theme.accentGreen : healthPercent > 0.25 ? Colors.orange : _Theme.warningRed,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${node.health}/${node.maxHealth}', style: const TextStyle(color: _Theme.textSecondary, fontSize: 11, fontFamily: 'monospace')),
                ],
              ),

              const SizedBox(height: 14),

              // ── Action Buttons ──
              Row(
                children: [
                  _actionButton(
                    icon: Icons.arrow_upward,
                    label: 'Улучшить',
                    cost: '$upgradeCost\u20BF',
                    color: _Theme.accentCyan,
                    enabled: isOnline && credits >= upgradeCost,
                    onTap: () => _upgradeNode(node, game, auth),
                  ),
                  const SizedBox(width: 10),
                  if (!isOnline)
                    _actionButton(
                      icon: Icons.power_settings_new,
                      label: 'Перезагрузить',
                      cost: '200\u20BF',
                      color: _Theme.accentGreen,
                      enabled: credits >= 200,
                      onTap: () => _rebootNode(node, game, auth),
                    ),
                ],
              ),
            ],
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

  // ─── Actions ─────────────────────────────────────────────────────────────

  Future<void> _upgradeNode(NetworkNode node, GameProvider game, AuthProvider auth) async {
    final cost = _upgradeCost(node);
    if (auth.userId == null) return;
    final success = await game.upgradeNode(nodeId: node.id, userId: auth.userId!, cost: cost);
    if (!mounted) return;
    if (success) {
      _showSnackBar('Узел улучшен!', _Theme.accentGreen);
      await game.refreshNetworkNodes(auth.userId!);
      await game.refreshResources(auth.userId!);
    } else {
      _showSnackBar(game.errorMessage ?? 'Не удалось улучшить', _Theme.warningRed);
    }
  }

  Future<void> _rebootNode(NetworkNode node, GameProvider game, AuthProvider auth) async {
    _showSnackBar('Перезагрузка узла...', _Theme.accentGreen);
    // В реальной версии — RPC вызов для перезагрузки
  }

  Future<void> _deployNode(String nodeType, GameProvider game, AuthProvider auth) async {
    if (auth.userId == null) return;
    final success = await game.deployNode(
      userId: auth.userId!,
      nodeType: nodeType,
      health: 150,
      maxHealth: 150,
    );
    if (!mounted) return;
    if (success) {
      _showSnackBar('Узел $_nodeTypeLabel(nodeType) развёрнут!', _Theme.accentGreen);
    } else {
      _showSnackBar(game.errorMessage ?? 'Не удалось развернуть', _Theme.warningRed);
    }
  }

  void _showBuildDialog(GameProvider game, AuthProvider auth) {
    final types = ['server', 'firewall', 'proxy', 'router', 'miner', 'scanner'];
    final cost = 1000;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.55,
        decoration: const BoxDecoration(
          color: _Theme.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: _Theme.border, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            const Text('Развернуть Новый Узел', style: TextStyle(color: _Theme.accentCyan, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Баланс: ${game.credits}\u20BF', style: const TextStyle(color: _Theme.accentGreen, fontSize: 14)),
            const Divider(color: _Theme.border, height: 24),
            Expanded(
              child: ListView.separated(
                itemCount: types.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final type = types[index];
                  final canAfford = game.credits >= cost;
                  return InkWell(
                    onTap: canAfford ? () {
                      Navigator.pop(context);
                      _deployNode(type, game, auth);
                    } : null,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: canAfford ? _Theme.cardHover : _Theme.bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: canAfford ? _Theme.accentCyan.withValues(alpha: 0.3) : _Theme.border),
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
                            child: Icon(_nodeTypeIcon(type), color: canAfford ? _Theme.accentCyan : _Theme.textSecondary, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_nodeTypeLabel(type), style: TextStyle(color: canAfford ? _Theme.textPrimary : _Theme.textSecondary, fontSize: 16, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('$cost\u20BF', style: TextStyle(color: canAfford ? _Theme.accentGreen : _Theme.warningRed, fontSize: 16, fontWeight: FontWeight.bold)),
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
                },
              ),
            ),
          ],
        ),
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
}
