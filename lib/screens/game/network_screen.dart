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

  // PC Desktop-specific
  static const sidePanelWidth = 380.0;
  static const headerHeight = 64.0;
  static const statsBarHeight = 72.0;
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

String _nodeTypeDescription(String nodeType) {
  return switch (nodeType.toLowerCase()) {
    'server' => 'Основной юнит для генерации дохода и вычислительной мощности.',
    'firewall' => 'Защищает вашу сеть от атак. Высокий показатель защиты.',
    'proxy' => 'Скрывает вашу активность и увеличивает пропускную способность.',
    'router' => 'Расширяет канал связи и обеспечивает вычислительный ресурс.',
    'miner' => 'Специализированный узел для добычи криптовалюты.',
    'scanner' => 'Разведывательный узел для анализа чужих сетей.',
    'database' => 'Хранилище данных для генерации стабильного дохода.',
    'terminal' => 'Центр управления — увеличивает эффективность всех узлов.',
    _ => 'Универсальный сетевой узел.',
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

  /// Currently selected node for the right-side detail panel
  NetworkNode? _selectedNode;

  /// Currently hovered node for highlight effect
  NetworkNode? _hoveredNode;

  /// Whether the build overlay is visible
  bool _showBuildOverlay = false;

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

  int _totalBandwidth(List<NetworkNode> nodes) {
    int total = 0;
    for (final n in nodes) {
      if (n.isOnline) {
        total += _bwPerLevel(n.nodeType) * n.nodeLevel;
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
    final bandwidth = _totalBandwidth(nodes);

    // Sync selected node with live data
    _syncSelectedNode(nodes);

    return Scaffold(
      backgroundColor: _Theme.bg,
      body: Stack(
        children: [
          // ── Main Content ──
          Column(
            children: [
              // ── Header Bar ──
              _buildHeader(credits, game, auth),
              const SizedBox(height: 16),

              // ── Stats Overview Bar ──
              _buildStatsBar(income, defense, cpu, bandwidth, nodes.length, onlineCount),
              const SizedBox(height: 16),

              // ── Main Area: Grid + Side Panel ──
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Node Grid (left)
                    Expanded(
                      child: nodes.isEmpty
                          ? _buildEmptyState()
                          : _buildBuildingGrid(nodes, credits, game, auth),
                    ),

                    const SizedBox(width: 16),

                    // Side Panel (right)
                    _buildSidePanel(game, auth),
                  ],
                ),
              ),
            ],
          ),

          // ── Build Overlay (wide panel dialog) ──
          if (_showBuildOverlay)
            _buildOverlay(game, auth),
        ],
      ),
    );
  }

  /// Keep the selected node reference in sync with live provider data
  void _syncSelectedNode(List<NetworkNode> nodes) {
    if (_selectedNode != null) {
      final updated =
          nodes.where((n) => n.id == _selectedNode!.id).firstOrNull;
      if (updated != null) {
        if (updated != _selectedNode) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _selectedNode = updated);
          });
        }
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _selectedNode = null);
        });
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HEADER
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildHeader(int credits, GameProvider game, AuthProvider auth) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: [
          // ── Title Block ──
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _Theme.accentCyan.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _Theme.accentCyan.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Icon(
                    Icons.hub,
                    color: _Theme.accentCyan,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'УПРАВЛЕНИЕ СЕТЬЮ',
                      style: TextStyle(
                        color: _Theme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 1),
                    const Text(
                      'Развертывание и управление узлами',
                      style: TextStyle(
                        color: _Theme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Action Buttons ──
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Refresh button
              _headerActionButton(
                icon: Icons.refresh,
                label: 'Обновить',
                color: _Theme.accentCyan,
                onTap: () => game.refreshNetworkNodes(auth.userId!),
              ),
              const SizedBox(width: 10),

              // Build button
              _headerActionButton(
                icon: Icons.add_circle_outline,
                label: 'Построить',
                color: _Theme.accentGreen,
                onTap: () => setState(() => _showBuildOverlay = true),
              ),
              const SizedBox(width: 16),

              // Credits badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
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
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$credits',
                      style: const TextStyle(
                        color: _Theme.accentGold,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      ' CR',
                      style: TextStyle(
                        color: _Theme.accentGreen,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STATS BAR
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildStatsBar(
    int income,
    int defense,
    int cpu,
    int bandwidth,
    int total,
    int online,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: _statCard(
              icon: Icons.trending_up,
              label: 'Доход',
              value: '+$income/мин',
              color: _Theme.accentGold,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _statCard(
              icon: Icons.shield,
              label: 'Защита',
              value: '$defense',
              color: _Theme.warningRed,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _statCard(
              icon: Icons.memory,
              label: 'ЦПУ',
              value: '$cpu',
              color: _Theme.accentCyan,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _statCard(
              icon: Icons.wifi,
              label: 'Канал',
              value: '$bandwidth MB/s',
              color: const Color(0xFF38bdf8),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _statCard(
              icon: Icons.dns,
              label: 'Узлы',
              value: '$online / $total',
              color: _Theme.accentGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: _Theme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _Theme.border),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  label,
                  style: const TextStyle(
                    color: _Theme.textMuted,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // NODE GRID (Left Area)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildBuildingGrid(
    List<NetworkNode> nodes,
    int credits,
    GameProvider game,
    AuthProvider auth,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // On wide screens: 3 columns; on narrower: 2 columns
        final crossCount =
            constraints.maxWidth > 700 ? 3 : (constraints.maxWidth > 450 ? 2 : 1);
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(24, 0, 8, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: crossCount == 1 ? 2.8 : (crossCount == 2 ? 1.6 : 1.2),
          ),
          itemCount: nodes.length,
          itemBuilder: (context, index) =>
              _buildBuildingCard(nodes[index], credits, game, auth),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // NODE CARD (Wide, desktop-style)
  // ══════════════════════════════════════════════════════════════════════════

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
    final cpuYield = _cpuPerLevel(node.nodeType) * node.nodeLevel;
    final bwYield = _bwPerLevel(node.nodeType) * node.nodeLevel;
    final isSelected = _selectedNode?.id == node.id;
    final isHovered = _hoveredNode?.id == node.id;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final glowAlpha = isOnline
            ? 0.08 + 0.07 * math.sin(_pulseController.value * 2 * math.pi)
            : 0.0;

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hoveredNode = node),
          onExit: (_) {
            if (_hoveredNode?.id == node.id) {
              setState(() => _hoveredNode = null);
            }
          },
          child: GestureDetector(
            onTap: () => setState(() {
              _selectedNode = (_selectedNode?.id == node.id) ? null : node;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: isSelected
                    ? _Theme.cardElevated
                    : (isHovered ? _Theme.cardElevated : _Theme.card),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? accent.withValues(alpha: 0.6)
                      : (isOnline
                          ? accent.withValues(alpha: 0.25 + glowAlpha)
                          : _Theme.border),
                  width: isSelected ? 2.0 : (isOnline ? 1.5 : 1),
                ),
                boxShadow: [
                  if (isOnline || isHovered)
                    BoxShadow(
                      color: isSelected
                          ? accent.withValues(alpha: 0.15)
                          : accent.withValues(alpha: glowAlpha + 0.04),
                      blurRadius: isSelected ? 20 : 16,
                      spreadRadius: 0,
                    ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  children: [
                    // ── Card Content ──
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Top Row ──
                          Row(
                            children: [
                              // Node Icon
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
                              const SizedBox(width: 12),

                              // Name + Level
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _nodeTypeLabel(node.nodeType),
                                      style: TextStyle(
                                        color: isOnline
                                            ? _Theme.textPrimary
                                            : _Theme.textSecondary,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        // Level badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _Theme.accentCyan
                                                .withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                              color: _Theme.accentCyan
                                                  .withValues(alpha: 0.3),
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
                                        const SizedBox(width: 8),

                                        // Role tag
                                        Text(
                                          _nodeTypeRole(node.nodeType),
                                          style: const TextStyle(
                                            color: _Theme.textMuted,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Online indicator
                              if (isOnline)
                                Container(
                                  width: 10,
                                  height: 10,
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
                                )
                              else
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _Theme.textMuted,
                                  ),
                                ),

                              const SizedBox(width: 12),

                              // Delete button
                              MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  onTap: () => _destroyNode(node, game, auth),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: _Theme.warningRed
                                          .withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: _Theme.warningRed
                                            .withValues(alpha: 0.2),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.delete_forever,
                                      color: _Theme.warningRed,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // ── Stats Row ──
                          Row(
                            children: [
                              if (production > 0 && isOnline) ...[
                                _miniStat(
                                  Icons.arrow_upward,
                                  '+$production CR/мин',
                                  _Theme.accentGold,
                                ),
                                const SizedBox(width: 12),
                              ],
                              if (def > 0 && isOnline) ...[
                                _miniStat(
                                  Icons.shield,
                                  '$def',
                                  _Theme.warningRed,
                                ),
                                const SizedBox(width: 12),
                              ],
                              if (cpuYield > 0 && isOnline) ...[
                                _miniStat(
                                  Icons.memory,
                                  '+$cpuYield ЦПУ',
                                  _Theme.accentCyan,
                                ),
                                const SizedBox(width: 12),
                              ],
                              if (bwYield > 0 && isOnline) ...[
                                _miniStat(
                                  Icons.wifi,
                                  '+$bwYield MB/s',
                                  const Color(0xFF38bdf8),
                                ),
                                const SizedBox(width: 12),
                              ],
                              if (!isOnline)
                                _miniStat(
                                  Icons.power_off,
                                  'Офлайн',
                                  _Theme.textMuted,
                                ),
                            ],
                          ),

                          const Spacer(),

                          // ── Health Bar ──
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'HP',
                                    style: const TextStyle(
                                      color: _Theme.textMuted,
                                      fontSize: 10,
                                    ),
                                  ),
                                  Text(
                                    '${node.health}/${node.maxHealth}',
                                    style: const TextStyle(
                                      color: _Theme.textMuted,
                                      fontSize: 10,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: healthPct.clamp(0.0, 1.0),
                                  minHeight: 6,
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
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _miniStat(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SIDE PANEL (Right Area)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildSidePanel(GameProvider game, AuthProvider auth) {
    return Container(
      width: _Theme.sidePanelWidth,
      constraints: const BoxConstraints(minHeight: double.infinity),
      decoration: BoxDecoration(
        color: _Theme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Theme.border),
      ),
      child: _selectedNode != null
          ? _buildNodeDetailPanel(game, auth)
          : _buildSidePlaceholder(),
    );
  }

  /// Placeholder when no node is selected
  Widget _buildSidePlaceholder() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final alpha =
                  0.15 + 0.1 * math.sin(_pulseController.value * 2 * math.pi);
              return Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: _Theme.accentCyan.withValues(alpha: alpha * 0.3),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _Theme.accentCyan.withValues(alpha: alpha * 0.5),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.touch_app,
                  size: 32,
                  color: _Theme.accentCyan.withValues(alpha: 0.4 + alpha),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          const Text(
            'Выберите узел',
            style: TextStyle(
              color: _Theme.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Нажмите на узел в сетке\nдля просмотра деталей',
            style: TextStyle(
              color: _Theme.textMuted,
              fontSize: 12,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Node detail panel with upgrade / reboot actions
  Widget _buildNodeDetailPanel(GameProvider game, AuthProvider auth) {
    final node = _selectedNode!;
    final isOnline = node.isOnline;
    final accent = _nodeTypeAccent(node.nodeType);
    final healthPct =
        node.maxHealth > 0 ? node.health / node.maxHealth : 0.0;
    final production = _productionPerLevel(node.nodeType) * node.nodeLevel;
    final def = _defensePerLevel(node.nodeType) * node.nodeLevel;
    final cpuYield = _cpuPerLevel(node.nodeType) * node.nodeLevel;
    final bwYield = _bwPerLevel(node.nodeType) * node.nodeLevel;
    final cost = _upgradeCost(node);
    final canUpgrade = isOnline && game.credits >= cost;
    final canReboot = !isOnline && game.credits >= 200;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Close button ──
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => setState(() => _selectedNode = null),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _Theme.card,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _Theme.border),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: _Theme.textSecondary,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Header ──
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: accent.withValues(alpha: 0.3)),
                ),
                child: Icon(
                  _nodeTypeIcon(node.nodeType),
                  color: accent,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
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
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        // Level badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
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
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isOnline
                                ? _Theme.accentGreen.withValues(alpha: 0.12)
                                : _Theme.warningRed.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isOnline
                                  ? _Theme.accentGreen.withValues(alpha: 0.3)
                                  : _Theme.warningRed.withValues(alpha: 0.3),
                            ),
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
                              const SizedBox(width: 5),
                              Text(
                                isOnline ? 'ОНЛАЙН' : 'ОФФЛАЙН',
                                style: TextStyle(
                                  color: isOnline
                                      ? _Theme.accentGreen
                                      : _Theme.warningRed,
                                  fontSize: 11,
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

          // ── Description ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _Theme.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _Theme.border),
            ),
            child: Text(
              _nodeTypeDescription(node.nodeType),
              style: const TextStyle(
                color: _Theme.textSecondary,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Stats Block ──
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _Theme.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _Theme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ХАРАКТЕРИСТИКИ',
                  style: TextStyle(
                    color: _Theme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 14),

                // Health
                _detailStatRow(
                  'Здоровье',
                  '${node.health} / ${node.maxHealth}',
                  _Theme.accentGreen,
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: healthPct.clamp(0.0, 1.0),
                    minHeight: 8,
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
                const SizedBox(height: 14),

                // Production
                _detailStatRow(
                  'Производство',
                  isOnline ? '+$production CR/мин' : '—',
                  _Theme.accentGold,
                ),

                // Defense
                if (def > 0)
                  _detailStatRow(
                    'Защита',
                    isOnline ? '$def' : '—',
                    _Theme.warningRed,
                  ),

                // CPU
                if (cpuYield > 0)
                  _detailStatRow(
                    'ЦПУ',
                    isOnline ? '+$cpuYield' : '—',
                    _Theme.accentCyan,
                  ),

                // Bandwidth
                if (bwYield > 0)
                  _detailStatRow(
                    'Канал',
                    isOnline ? '+$bwYield MB/s' : '—',
                    const Color(0xFF38bdf8),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Upgrade Preview ──
          if (isOnline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _Theme.accentCyan.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _Theme.accentCyan.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.trending_up,
                    color: _Theme.accentCyan,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Следующий уровень: УР ${_nextLevel()}',
                          style: TextStyle(
                            color: _Theme.accentCyan,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _nextLevelPreview(node),
                          style: TextStyle(
                            color: _Theme.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 20),

          // ── Action Buttons ──
          Row(
            children: [
              // Upgrade button
              Expanded(
                child: _sideActionButton(
                  icon: Icons.arrow_upward,
                  label: 'Улучшить',
                  subtitle: '$cost CR',
                  color: _Theme.accentCyan,
                  enabled: canUpgrade,
                  onTap: () => _upgradeNode(node, game, auth),
                ),
              ),
              if (!isOnline) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: _sideActionButton(
                    icon: Icons.power_settings_new,
                    label: 'Перезагрузить',
                    subtitle: '200 CR',
                    color: _Theme.accentGreen,
                    enabled: canReboot,
                    onTap: () => _rebootNode(node, game, auth),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  int _nextLevel() {
    return (_selectedNode?.nodeLevel ?? 0) + 1;
  }

  String _nextLevelPreview(NetworkNode node) {
    final nextLevel = node.nodeLevel + 1;
    final parts = <String>[];
    final prod = _productionPerLevel(node.nodeType) * nextLevel;
    if (prod > 0) parts.add('+$prod CR/мин');
    final def = _defensePerLevel(node.nodeType) * nextLevel;
    if (def > 0) parts.add('Защита $def');
    final cpu = _cpuPerLevel(node.nodeType) * nextLevel;
    if (cpu > 0) parts.add('+$cpu ЦПУ');
    final bw = _bwPerLevel(node.nodeType) * nextLevel;
    if (bw > 0) parts.add('+$bw MB/s');
    return parts.isEmpty ? 'Характеристики увеличатся' : parts.join(' · ');
  }

  Widget _detailStatRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sideActionButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            gradient: enabled
                ? LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.15),
                      color.withValues(alpha: 0.05),
                    ],
                  )
                : null,
            color: enabled ? null : _Theme.card,
            borderRadius: BorderRadius.circular(12),
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
                size: 24,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: enabled ? color : _Theme.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
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

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD OVERLAY (Wide Panel)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildOverlay(GameProvider game, AuthProvider auth) {
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

    return Positioned.fill(
      child: GestureDetector(
        // Tap outside to close
        onTap: () => setState(() => _showBuildOverlay = false),
        child: Container(
          color: Colors.black.withValues(alpha: 0.6),
          alignment: Alignment.center,
          child: GestureDetector(
            // Prevent tap-through
            onTap: () {},
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 720,
              constraints: const BoxConstraints(maxHeight: 560),
              decoration: BoxDecoration(
                color: _Theme.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _Theme.accentGreen.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _Theme.accentGreen.withValues(alpha: 0.08),
                    blurRadius: 40,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 20, 20, 0),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color:
                                _Theme.accentGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _Theme.accentGreen.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Icon(
                            Icons.build_circle,
                            color: _Theme.accentGreen,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ПОСТРОИТЬ УЗЕЛ',
                                style: TextStyle(
                                  color: _Theme.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Выберите тип узла для развёртывания',
                                style: TextStyle(
                                  color: _Theme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Balance badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _Theme.accentGold.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _Theme.accentGold.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.monetization_on,
                                color: _Theme.accentGold,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${game.credits} CR',
                                style: const TextStyle(
                                  color: _Theme.accentGold,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Close button
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _showBuildOverlay = false),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: _Theme.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _Theme.border),
                              ),
                              child: const Icon(
                                Icons.close,
                                color: _Theme.textSecondary,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Build Grid ──
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const BouncingScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: buildTypes.length,
                        itemBuilder: (context, index) {
                          final type = buildTypes[index];
                          return _buildOptionCard(type, game, auth);
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard(
    String type,
    GameProvider game,
    AuthProvider auth,
  ) {
    final itemCost = _buildCost(type);
    final canAfford = game.credits >= itemCost;
    final accent = _nodeTypeAccent(type);
    final stats = _statsFor(type);
    final income = stats?.passiveIncome ?? 0;
    final def = stats?.defense ?? 0;
    final cpu = stats?.cpuYield ?? 0;
    final bw = stats?.bandwidthYield ?? 0;

    return MouseRegion(
      cursor: canAfford ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
      child: GestureDetector(
        onTap: canAfford
            ? () {
                setState(() => _showBuildOverlay = false);
                _deployNode(type, game, auth);
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: canAfford ? _Theme.cardElevated : _Theme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: canAfford
                  ? accent.withValues(alpha: 0.35)
                  : _Theme.border,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
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
                  color: canAfford ? accent : _Theme.textMuted,
                  size: 26,
                ),
              ),
              const SizedBox(height: 10),

              // Name
              Text(
                _nodeTypeLabel(type),
                style: TextStyle(
                  color: canAfford ? _Theme.textPrimary : _Theme.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 2),

              // Role
              Text(
                _nodeTypeRole(type),
                style: TextStyle(
                  color: canAfford
                      ? _Theme.textMuted
                      : _Theme.textMuted.withValues(alpha: 0.5),
                  fontSize: 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 4),

              // Stats hint
              if (income > 0)
                Text(
                  '+$income CR/мин',
                  style: TextStyle(
                    color: canAfford
                        ? _Theme.accentGold.withValues(alpha: 0.9)
                        : _Theme.textMuted.withValues(alpha: 0.4),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else if (def > 0)
                Text(
                  'Защита $def',
                  style: TextStyle(
                    color: canAfford
                        ? _Theme.warningRed.withValues(alpha: 0.9)
                        : _Theme.textMuted.withValues(alpha: 0.4),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else if (cpu > 0)
                Text(
                  '+$cpu ЦПУ',
                  style: TextStyle(
                    color: canAfford
                        ? _Theme.accentCyan.withValues(alpha: 0.9)
                        : _Theme.textMuted.withValues(alpha: 0.4),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else if (bw > 0)
                Text(
                  '+$bw MB/s',
                  style: TextStyle(
                    color: canAfford
                        ? const Color(0xFF38bdf8).withValues(alpha: 0.9)
                        : _Theme.textMuted.withValues(alpha: 0.4),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),

              const Spacer(),

              // Cost
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
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
                    color: canAfford ? accent : _Theme.textMuted,
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
  }

  // ══════════════════════════════════════════════════════════════════════════
  // EMPTY STATE
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final alpha =
                    0.2 + 0.15 * math.sin(_pulseController.value * 2 * math.pi);
                return Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: _Theme.accentCyan.withValues(alpha: alpha * 0.3),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _Theme.accentCyan.withValues(alpha: alpha),
                        blurRadius: 40,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.hub_outlined,
                    size: 44,
                    color: _Theme.accentCyan.withValues(alpha: 0.5 + alpha),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'База пуста',
              style: TextStyle(
                color: _Theme.accentCyan,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Нажмите «Построить» вверху, чтобы\nразвернуть первый узел и начать!',
              style: TextStyle(
                color: _Theme.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ACTIONS (Game Logic — preserved from original)
  // ══════════════════════════════════════════════════════════════════════════

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
      _showSnackBar('Узел улучшен до УР ${node.nodeLevel + 1}!',
          _Theme.accentCyan);
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
            Text('Удалить узел?',
                style: TextStyle(color: Color(0xFFFF0040))),
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
            style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFF0040)),
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
      setState(() => _selectedNode = null);
      final stats = _statsFor(node.nodeType);
      if (stats != null) {
        await game.refreshResources(auth.userId!);
      }
    } else {
      _showSnackBar(
          game.errorMessage ?? 'Не удалось удалить', _Theme.warningRed);
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
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    );
  }
}
