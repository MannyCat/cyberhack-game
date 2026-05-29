import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/game_provider.dart';
import '../../providers/auth_provider.dart';
import '../../config/game_config.dart';

// ─── Theme Constants ──────────────────────────────────────────────────────────

class _Theme {
  _Theme._();

  static const bg = Color(0xFF0a0e17);
  static const surface = Color(0xFF0d1320);
  static const card = Color(0xFF111827);
  static const cardElevated = Color(0xFF1a2236);
  static const accentCyan = Color(0xFF00F0FF);
  static const accentGreen = Color(0xFF00ff41);
  static const accentGold = Color(0xFFFFD700);
  static const warningRed = Color(0xFFFF0040);
  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFF7b8ca8);
  static const textMuted = Color(0xFF4a5568);
  static const border = Color(0xFF1e293b);
  static const borderGlow = Color(0xFF00F0FF);
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

const _keyMap = <String, String>{
  'server': 'server',
  'firewall': 'firewall',
  'proxy': 'proxy_node',
  'router': 'router',
  'miner': 'mining_rig',
  'scanner': 'scanner',
  'database': 'database',
  'terminal': 'terminal',
};

BuildingStats? _statsFor(String nodeType) {
  final key = _keyMap[nodeType.toLowerCase()] ?? nodeType.toLowerCase();
  return BuildingConfig.stats[key];
}

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

Color _nodeTypeAccent(String nodeType) {
  return switch (nodeType.toLowerCase()) {
    'server' => _Theme.accentCyan,
    'firewall' => _Theme.warningRed,
    'proxy' => const Color(0xFFa78bfa),
    'router' => const Color(0xFF38bdf8),
    'miner' => _Theme.accentGold,
    'scanner' => const Color(0xFFf472b6),
    'database' => const Color(0xFF34d399),
    'terminal' => const Color(0xFFfb923c),
    _ => _Theme.accentCyan,
  };
}

String _nodeTypeRole(String nodeType) {
  return switch (nodeType.toLowerCase()) {
    'server' => 'Доход · ЦПУ',
    'firewall' => 'Защита',
    'proxy' => 'Маскировка · Канал',
    'router' => 'Канал · ЦПУ',
    'miner' => 'Доход',
    'scanner' => 'Разведка',
    'database' => 'Доход',
    'terminal' => 'Управление',
    _ => 'Общее',
  };
}

int _productionPerLevel(String nodeType) {
  return _statsFor(nodeType)?.passiveIncome ?? 0;
}

int _defensePerLevel(String nodeType) {
  return _statsFor(nodeType)?.defense ?? 0;
}

int _cpuPerLevel(String nodeType) {
  return _statsFor(nodeType)?.cpuYield ?? 0;
}

int _bwPerLevel(String nodeType) {
  return _statsFor(nodeType)?.bandwidthYield ?? 0;
}

int _buildCost(String nodeType) {
  return _statsFor(nodeType)?.buildCostCredits ?? 1000;
}

int _upgradeCost(NetworkNode node) {
  final stats = _statsFor(node.nodeType);
  if (stats == null) return 500 * node.nodeLevel;
  return (stats.buildCostCredits * stats.upgradeCostMultiplier * node.nodeLevel)
      .round();
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
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  // ─── Aggregate Calculations ──────────────────────────────────────────────

  int _totalIncome(List<NetworkNode> nodes) {
    int total = 0;
    for (final n in nodes) {
      if (n.isOnline) {
        total += _productionPerLevel(n.nodeType) * n.nodeLevel;
      }
    }
    return total;
  }

  int _totalDefense(List<NetworkNode> nodes) {
    int total = 0;
    for (final n in nodes) {
      if (n.isOnline) {
        total += _defensePerLevel(n.nodeType) * n.nodeLevel;
      }
    }
    return total;
  }

  int _totalCpu(List<NetworkNode> nodes) {
    int total = 0;
    for (final n in nodes) {
      if (n.isOnline) {
        total += _cpuPerLevel(n.nodeType) * n.nodeLevel;
      }
    }
    return total;
  }

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
        body: const Center(
          child: Text(
            'Не авторизован',
            style: TextStyle(color: _Theme.textSecondary),
          ),
        ),
      );
    }

    final onlineCount = nodes.where((n) => n.isOnline).length;
    final income = _totalIncome(nodes);
    final defense = _totalDefense(nodes);
    final cpu = _totalCpu(nodes);

    return Scaffold(
      backgroundColor: _Theme.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Header ──
            _buildHeader(credits),
            const SizedBox(height: 12),

            // ── Stats Overview ──
            _buildStatsRow(income, defense, cpu, nodes.length, onlineCount),
            const SizedBox(height: 16),

            // ── Building Grid ──
            Expanded(
              child: nodes.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      color: _Theme.accentCyan,
                      backgroundColor: _Theme.card,
                      onRefresh: () =>
                          game.refreshNetworkNodes(auth.userId!),
                      child: _buildBuildingGrid(nodes, credits, game, auth),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(game, auth),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // ─── Header ──────────────────────────────────────────────────────────────

  Widget _buildHeader(int credits) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.hub,
                      color: _Theme.accentCyan,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'БАЗА СЕТИ',
                      style: TextStyle(
                        color: _Theme.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'Управляйте своей кибер-империей',
                  style: TextStyle(
                    color: _Theme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Credits badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _Theme.accentGold.withValues(alpha: 0.15),
                  _Theme.accentGold.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _Theme.accentGold.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.monetization_on,
                  color: _Theme.accentGold,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  '${credits.toString()}',
                  style: const TextStyle(
                    color: _Theme.accentGold,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  ' CR',
                  style: TextStyle(
                    color: const Color(0xB2ff41),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Stats Row ───────────────────────────────────────────────────────────

  Widget _buildStatsRow(
    int income,
    int defense,
    int cpu,
    int total,
    int online,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(child: _statCard(Icons.trending_up, 'Доход', '+$income/мин', _Theme.accentGold)),
          const SizedBox(width: 8),
          Expanded(child: _statCard(Icons.shield, 'Защита', '$defense', _Theme.warningRed)),
          const SizedBox(width: 8),
          Expanded(child: _statCard(Icons.memory, 'ЦПУ', '$cpu', _Theme.accentCyan)),
          const SizedBox(width: 8),
          Expanded(child: _statCard(Icons.dns, 'Узлы', '$online/$total', _Theme.accentGreen)),
        ],
      ),
    );
  }

  Widget _statCard(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: _Theme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _Theme.border),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 12,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: const TextStyle(
              color: _Theme.textMuted,
              fontSize: 9,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Building Grid ───────────────────────────────────────────────────────

  Widget _buildBuildingGrid(
    List<NetworkNode> nodes,
    int credits,
    GameProvider game,
    AuthProvider auth,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth > 600 ? 3 : 2;
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.72,
          ),
          itemCount: nodes.length,
          itemBuilder: (context, index) =>
              _buildBuildingCard(nodes[index], credits, game, auth),
        );
      },
    );
  }

  // ─── Building Card ───────────────────────────────────────────────────────

  Widget _buildBuildingCard(
    NetworkNode node,
    int credits,
    GameProvider game,
    AuthProvider auth,
  ) {
    final isOnline = node.isOnline;
    final accent = _nodeTypeAccent(node.nodeType);
    final healthPct = node.maxHealth > 0 ? node.health / node.maxHealth : 0.0;
    final production = _productionPerLevel(node.nodeType) * node.nodeLevel;
    final def = _defensePerLevel(node.nodeType) * node.nodeLevel;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final glowAlpha = isOnline
            ? 0.08 + 0.07 * math.sin(_pulseController.value * 2 * math.pi)
            : 0.0;

        return GestureDetector(
          onTap: () => _showBuildingDetail(node, game, auth),
          child: Container(
            decoration: BoxDecoration(
              color: _Theme.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isOnline
                    ? accent.withValues(alpha: 0.25 + glowAlpha)
                    : _Theme.border,
                width: isOnline ? 1.5 : 1,
              ),
              boxShadow: [
                if (isOnline)
                  BoxShadow(
                    color: accent.withValues(alpha: glowAlpha + 0.04),
                    blurRadius: 16,
                    spreadRadius: 0,
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  // Content
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Top row: Icon + Level + Status ──
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Building icon
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: isOnline
                                    ? accent.withValues(alpha: 0.12)
                                    : _Theme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isOnline
                                      ? accent.withValues(alpha: 0.25)
                                      : _Theme.border,
                                ),
                              ),
                              child: Icon(
                                _nodeTypeIcon(node.nodeType),
                                color: isOnline ? accent : _Theme.textMuted,
                                size: 26,
                              ),
                            ),

                            // Level badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _Theme.accentCyan.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _Theme.accentCyan.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                'УР ${node.nodeLevel}',
                                style: const TextStyle(
                                  color: _Theme.accentCyan,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_forever, color: Color(0xFFFF0040), size: 20),
                              onPressed: () => _destroyNode(node, game, auth),
                              tooltip: 'Удалить узел',
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // ── Name ──
                        Text(
                          _nodeTypeLabel(node.nodeType),
                          style: TextStyle(
                            color: isOnline
                                ? _Theme.textPrimary
                                : _Theme.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 2),

                        // ── Role tag ──
                        Text(
                          _nodeTypeRole(node.nodeType),
                          style: const TextStyle(
                            color: _Theme.textMuted,
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const Spacer(),

                        // ── Production / Defense info ──
                        if (production > 0 && isOnline)
                          Row(
                            children: [
                              const Icon(
                                Icons.arrow_upward,
                                color: _Theme.accentGold,
                                size: 12,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '+$production CR/мин',
                                style: const TextStyle(
                                  color: _Theme.accentGold,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        else if (def > 0 && isOnline)
                          Row(
                            children: [
                              const Icon(
                                Icons.shield,
                                color: _Theme.warningRed,
                                size: 12,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'Защита $def',
                                style: const TextStyle(
                                  color: _Theme.warningRed,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        else if (!isOnline)
                          const Row(
                            children: [
                              Icon(
                                Icons.power_off,
                                color: _Theme.textMuted,
                                size: 12,
                              ),
                              SizedBox(width: 3),
                              Text(
                                'Офлайн',
                                style: TextStyle(
                                  color: _Theme.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),

                        const SizedBox(height: 8),

                        // ── Health bar ──
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'HP',
                                  style: TextStyle(
                                    color: _Theme.textMuted,
                                    fontSize: 9,
                                  ),
                                ),
                                Text(
                                  '${node.health}/${node.maxHealth}',
                                  style: TextStyle(
                                    color: _Theme.textMuted,
                                    fontSize: 9,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: healthPct.clamp(0.0, 1.0),
                                minHeight: 5,
                                backgroundColor: _Theme.surface,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  healthPct > 0.6
                                      ? _Theme.accentGreen
                                      : healthPct > 0.3
                                          ? Colors.orange
                                          : _Theme.warningRed,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ── Online glow overlay ──
                  if (isOnline)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _Theme.accentGreen,
                          boxShadow: [
                            BoxShadow(
                              color: _Theme.accentGreen
                                  .withValues(alpha: 0.4 + glowAlpha * 2),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── Building Detail Bottom Sheet ────────────────────────────────────────

  void _showBuildingDetail(
    NetworkNode node,
    GameProvider game,
    AuthProvider auth,
  ) {
    final isOnline = node.isOnline;
    final accent = _nodeTypeAccent(node.nodeType);
    final healthPct = node.maxHealth > 0 ? node.health / node.maxHealth : 0.0;
    final production = _productionPerLevel(node.nodeType) * node.nodeLevel;
    final def = _defensePerLevel(node.nodeType) * node.nodeLevel;
    final cpuYield = _cpuPerLevel(node.nodeType) * node.nodeLevel;
    final bwYield = _bwPerLevel(node.nodeType) * node.nodeLevel;
    final cost = _upgradeCost(node);
    final canUpgrade = isOnline && game.credits >= cost;
    final canReboot = !isOnline && game.credits >= 200;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.75,
        ),
        decoration: const BoxDecoration(
          color: _Theme.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _Theme.textMuted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: accent.withValues(alpha: 0.3)),
                    ),
                    child: Icon(
                      _nodeTypeIcon(node.nodeType),
                      color: accent,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _nodeTypeLabel(node.nodeType),
                          style: const TextStyle(
                            color: _Theme.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _Theme.accentCyan
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'УР ${node.nodeLevel}',
                                style: const TextStyle(
                                  color: _Theme.accentCyan,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isOnline
                                    ? _Theme.accentGreen.withValues(alpha: 0.12)
                                    : _Theme.warningRed.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isOnline
                                          ? _Theme.accentGreen
                                          : _Theme.warningRed,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isOnline ? 'ОНЛАЙН' : 'ОФФЛАЙН',
                                    style: TextStyle(
                                      color: isOnline
                                          ? _Theme.accentGreen
                                          : _Theme.warningRed,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Stats grid
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _Theme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _Theme.border),
                ),
                child: Column(
                  children: [
                    _detailStatRow('Здоровье', '${node.health} / ${node.maxHealth}',
                        _Theme.accentGreen),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: healthPct.clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: _Theme.bg,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          healthPct > 0.6
                              ? _Theme.accentGreen
                              : healthPct > 0.3
                                  ? Colors.orange
                                  : _Theme.warningRed,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _detailStatRow(
                        'Производство', '+$production CR/мин', _Theme.accentGold),
                    if (def > 0)
                      _detailStatRow('Защита', '$def', _Theme.warningRed),
                    if (cpuYield > 0)
                      _detailStatRow('ЦПУ', '+$cpuYield', _Theme.accentCyan),
                    if (bwYield > 0)
                      _detailStatRow(
                          'Канал', '${bwYield > 0 ? '+' : ''}$bwYield MB/s',
                          const Color(0xFF38bdf8)),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Action buttons
              Row(
                children: [
                  // Upgrade button
                  Expanded(
                    child: _detailActionButton(
                      icon: Icons.arrow_upward,
                      label: 'Улучшить',
                      subtitle: '$cost CR',
                      color: _Theme.accentCyan,
                      enabled: canUpgrade,
                      onTap: () {
                        Navigator.pop(ctx);
                        _upgradeNode(node, game, auth);
                      },
                    ),
                  ),
                  if (!isOnline) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: _detailActionButton(
                        icon: Icons.power_settings_new,
                        label: 'Перезагрузить',
                        subtitle: '200 CR',
                        color: _Theme.accentGreen,
                        enabled: canReboot,
                        onTap: () {
                          Navigator.pop(ctx);
                          _rebootNode(node, game, auth);
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailStatRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _Theme.textSecondary,
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailActionButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            gradient: enabled
                ? LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.18),
                      color.withValues(alpha: 0.06),
                    ],
                  )
                : null,
            color: enabled ? null : _Theme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: enabled
                  ? color.withValues(alpha: 0.4)
                  : _Theme.border,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: enabled ? color : _Theme.textMuted,
                size: 22,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: enabled ? color : _Theme.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: enabled
                      ? _Theme.textSecondary
                      : _Theme.textMuted.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Build New Building Dialog ───────────────────────────────────────────

  Widget _buildFAB(GameProvider game, AuthProvider auth) {
    return FloatingActionButton(
      onPressed: () => _showBuildDialog(game, auth),
      backgroundColor: _Theme.accentGreen.withValues(alpha: 0.12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: _Theme.accentGreen.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _Theme.accentGreen.withValues(alpha: 0.15),
              blurRadius: 16,
            ),
          ],
        ),
        child: const Icon(
          Icons.add,
          color: _Theme.accentGreen,
          size: 28,
        ),
      ),
    );
  }

  void _showBuildDialog(GameProvider game, AuthProvider auth) {
    final buildTypes = [
      'server',
      'firewall',
      'router',
      'miner',
      'database',
      'proxy',
      'scanner',
      'terminal',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.7,
        ),
        decoration: const BoxDecoration(
          color: _Theme.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _Theme.textMuted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              const Text(
                'ПОСТРОИТЬ УЗЕЛ',
                style: TextStyle(
                  color: _Theme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Text(
                    'Баланс: ',
                    style: TextStyle(color: _Theme.textSecondary, fontSize: 13),
                  ),
                  Text(
                    '${game.credits} CR',
                    style: const TextStyle(
                      color: _Theme.accentGold,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Building options grid
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.05,
                  ),
                  itemCount: buildTypes.length,
                  itemBuilder: (context, index) {
                    final type = buildTypes[index];
                    final itemCost = _buildCost(type);
                    final canAfford = game.credits >= itemCost;
                    final accent = _nodeTypeAccent(type);
                    final stats = _statsFor(type);
                    final income = stats?.passiveIncome ?? 0;
                    final def = stats?.defense ?? 0;

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: canAfford
                            ? () {
                                Navigator.pop(ctx);
                                _deployNode(type, game, auth);
                              }
                            : null,
                        borderRadius: BorderRadius.circular(14),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: canAfford
                                ? _Theme.cardElevated
                                : _Theme.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: canAfford
                                  ? accent.withValues(alpha: 0.3)
                                  : _Theme.border,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Icon
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: canAfford
                                      ? accent.withValues(alpha: 0.12)
                                      : _Theme.bg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: canAfford
                                        ? accent.withValues(alpha: 0.25)
                                        : _Theme.border,
                                  ),
                                ),
                                child: Icon(
                                  _nodeTypeIcon(type),
                                  color: canAfford
                                      ? accent
                                      : _Theme.textMuted,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Name
                              Text(
                                _nodeTypeLabel(type),
                                style: TextStyle(
                                  color: canAfford
                                      ? _Theme.textPrimary
                                      : _Theme.textMuted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),

                              // Stats hint
                              if (income > 0)
                                Text(
                                  '+$income CR/мин',
                                  style: TextStyle(
                                    color: canAfford
                                        ? _Theme.accentGold
                                            .withValues(alpha: 0.8)
                                        : _Theme.textMuted.withValues(alpha: 0.5),
                                    fontSize: 10,
                                  ),
                                )
                              else if (def > 0)
                                Text(
                                  'Защита $def',
                                  style: TextStyle(
                                    color: canAfford
                                        ? _Theme.warningRed
                                            .withValues(alpha: 0.8)
                                        : _Theme.textMuted.withValues(alpha: 0.5),
                                    fontSize: 10,
                                  ),
                                ),

                              const SizedBox(height: 8),

                              // Cost & button
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                  horizontal: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: canAfford
                                      ? accent.withValues(alpha: 0.12)
                                      : _Theme.bg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: canAfford
                                        ? accent.withValues(alpha: 0.25)
                                        : _Theme.border,
                                  ),
                                ),
                                child: Text(
                                  '$itemCost CR',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: canAfford
                                        ? accent
                                        : _Theme.textMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Empty State ─────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated glow icon
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final alpha = 0.2 +
                    0.15 *
                        math.sin(_pulseController.value * 2 * math.pi);
                return Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: _Theme.accentCyan.withValues(alpha: alpha * 0.3),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _Theme.accentCyan.withValues(alpha: alpha),
                        blurRadius: 32,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.hub_outlined,
                    size: 40,
                    color: _Theme.accentCyan.withValues(alpha: 0.5 + alpha),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'База пуста',
              style: TextStyle(
                color: _Theme.accentCyan,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Разверните первый узел,\nчтобы начать строительство!',
              style: TextStyle(
                color: _Theme.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Actions ─────────────────────────────────────────────────────────────

  Future<void> _upgradeNode(
    NetworkNode node,
    GameProvider game,
    AuthProvider auth,
  ) async {
    final cost = _upgradeCost(node);
    if (auth.userId == null) return;
    final success = await game.upgradeNode(
      nodeId: node.id,
      userId: auth.userId!,
      cost: cost,
    );
    if (!mounted) return;
    if (success) {
      _showSnackBar('Узел улучшен до УР ${node.nodeLevel + 1}!', _Theme.accentCyan);
      await game.refreshNetworkNodes(auth.userId!);
      await game.refreshResources(auth.userId!);
    } else {
      _showSnackBar(
        game.errorMessage ?? 'Не удалось улучшить',
        _Theme.warningRed,
      );
    }
  }

  Future<void> _rebootNode(
    NetworkNode node,
    GameProvider game,
    AuthProvider auth,
  ) async {
    if (auth.userId == null || game.credits < 200) return;
    try {
      await Supabase.instance.client
          .from('network_nodes')
          .update({'is_online': true, 'health': node.maxHealth})
          .eq('id', node.id);
      await game.refreshNetworkNodes(auth.userId!);
      await game.refreshResources(auth.userId!);
      if (mounted) {
        _showSnackBar('Узел перезагружен!', _Theme.accentGreen);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Ошибка перезагрузки: $e', _Theme.warningRed);
      }
    }
  }


  Future<void> _destroyNode(
    NetworkNode node,
    GameProvider game,
    AuthProvider auth,
  ) async {
    if (auth.userId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFFF0040), width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Color(0xFFFF0040)),
            SizedBox(width: 10),
            Text('Удалить узел?', style: TextStyle(color: Color(0xFFFF0040))),
          ],
        ),
        content: Text(
          'Узел ${_nodeTypeLabel(node.nodeType)} УР ${node.nodeLevel} будет безвозвратно удалён. Вы получите 50% стоимости постройки.',
          style: const TextStyle(color: Color(0xFF7b8ca8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ОТМЕНА'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF0040)),
            child: const Text('УДАЛИТЬ'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await game.destroyNode(
      nodeId: node.id,
      userId: auth.userId!,
    );

    if (!mounted) return;
    if (success) {
      _showSnackBar('Узел удалён', _Theme.warningRed);
      // Refund 50% of build cost
      final stats = _statsFor(node.nodeType);
      if (stats != null) {
        final refund = (stats.buildCostCredits * 0.5).round();
        await game.refreshResources(auth.userId!);
      }
    } else {
      _showSnackBar(game.errorMessage ?? 'Не удалось удалить', _Theme.warningRed);
    }
  }


  Future<void> _deployNode(
    String nodeType,
    GameProvider game,
    AuthProvider auth,
  ) async {
    if (auth.userId == null) return;
    final stats = _statsFor(nodeType);
    final hp = stats?.hp ?? 150;
    final success = await game.deployNode(
      userId: auth.userId!,
      nodeType: nodeType,
      health: hp,
      maxHealth: hp,
    );
    if (!mounted) return;
    if (success) {
      _showSnackBar(
        '${_nodeTypeLabel(nodeType)} развёрнут!',
        _Theme.accentGreen,
      );
      await game.refreshNetworkNodes(auth.userId!);
      await game.refreshResources(auth.userId!);
    } else {
      _showSnackBar(
        game.errorMessage ?? 'Не удалось развернуть',
        _Theme.warningRed,
      );
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: color.withValues(alpha: 0.85),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
