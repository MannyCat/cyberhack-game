import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../providers/auth_provider.dart';

class AttackScreen extends StatefulWidget {
  const AttackScreen({super.key});

  @override
  State<AttackScreen> createState() => _AttackScreenState();
}

class _AttackScreenState extends State<AttackScreen> with TickerProviderStateMixin {
  AttackTarget? _selectedTarget;
  _AttackType? _selectedAttackType;
  bool _isAttacking = false;
  double _attackProgress = 0.0;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  static const _attackTypes = <_AttackType>[
    _AttackType(
      name: 'DDoS',
      icon: Icons.wifi_off,
      damage: 30,
      creditCost: 500,
      cpuCost: 20,
      color: Colors.redAccent,
      description: 'Overwhelm target with traffic flood',
    ),
    _AttackType(
      name: 'Malware',
      icon: Icons.bug_report,
      damage: 50,
      creditCost: 1200,
      cpuCost: 35,
      color: Colors.purpleAccent,
      description: 'Deploy malicious payload',
    ),
    _AttackType(
      name: 'Phishing',
      icon: Icons.phishing,
      damage: 25,
      creditCost: 300,
      cpuCost: 10,
      color: Colors.tealAccent,
      description: 'Social engineering credentials',
    ),
    _AttackType(
      name: 'Brute Force',
      icon: Icons.lock_open,
      damage: 40,
      creditCost: 800,
      cpuCost: 45,
      color: Colors.orangeAccent,
      description: 'Exhaustive password cracking',
    ),
    _AttackType(
      name: 'SQL Injection',
      icon: Icons.code,
      damage: 60,
      creditCost: 2000,
      cpuCost: 50,
      color: Colors.blueAccent,
      description: 'Exploit database vulnerabilities',
    ),
    _AttackType(
      name: 'Zero Day',
      icon: Icons.warning,
      damage: 100,
      creditCost: 5000,
      cpuCost: 80,
      color: Colors.yellowAccent,
      description: 'Unknown exploit — devastating',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _launchAttack() async {
    if (_selectedTarget == null || _selectedAttackType == null) return;

    final auth = context.read<AuthProvider>();
    final game = context.read<GameProvider>();
    if (auth.userId == null) return;

    final attackType = _selectedAttackType!;

    // Check resource requirements
    if (game.credits < attackType.creditCost) {
      _showSnackBar('Insufficient credits! Need ${attackType.creditCost} CR');
      return;
    }
    if (game.cpu < attackType.cpuCost) {
      _showSnackBar('Insufficient CPU! Need ${attackType.cpuCost} CPU');
      return;
    }

    setState(() {
      _isAttacking = true;
      _attackProgress = 0.0;
    });

    // Animate progress
    for (int i = 0; i <= 100; i += 2) {
      await Future.delayed(const Duration(milliseconds: 30));
      if (!mounted) return;
      setState(() => _attackProgress = i / 100);
    }

    final success = await game.launchAttack(
      attackerId: auth.userId!,
      defenderId: _selectedTarget!.id,
      targetNodeId: null,
      attackType: attackType.name,
      damage: attackType.damage,
    );

    if (!mounted) return;
    setState(() => _isAttacking = false);

    if (success) {
      _showSnackBar('Attack launched against ${_selectedTarget!.username}!');
      await game.refreshResources(auth.userId!);
      await game.refreshAttackHistory(auth.userId!);
    } else {
      _showSnackBar(game.errorMessage ?? 'Attack failed');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);

    if (auth.userId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('ATTACK')),
        body: Center(child: Text('Not authenticated', style: theme.textTheme.bodyLarge)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('CYBERWARFARE'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh targets',
            onPressed: () {
              game.refreshTargets(auth.userId!);
              game.refreshAttackHistory(auth.userId!);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Resource Bar ──
            _buildResourceBar(game, theme),
            const SizedBox(height: 16),

            // ── Target Selection ──
            _buildSectionTitle('SELECT TARGET', Icons.gps_fixed, theme),
            const SizedBox(height: 8),
            _buildTargetSelector(game, theme),
            const SizedBox(height: 20),

            // ── Attack Type Selector ──
            _buildSectionTitle('ATTACK VECTOR', Icons.flash_on, theme),
            const SizedBox(height: 8),
            _buildAttackTypeGrid(game, theme),
            const SizedBox(height: 20),

            // ── Launch Button ──
            _buildLaunchButton(game, theme),
            const SizedBox(height: 8),

            // ── Attack Progress ──
            if (_isAttacking) _buildAttackProgress(theme),
            if (_isAttacking) const SizedBox(height: 20),

            // ── Attack History ──
            _buildSectionTitle('ATTACK LOG', Icons.history, theme),
            const SizedBox(height: 8),
            _buildAttackHistory(game, theme),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildResourceBar(GameProvider game, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _resourceChip(Icons.monetization_on, 'CR', '${game.credits}', Colors.amber, theme),
          _resourceChip(Icons.memory, 'CPU', '${game.cpu}', Colors.cyanAccent, theme),
          _resourceChip(Icons.speed, 'BW', '${game.bandwidth}', Colors.greenAccent, theme),
          _resourceChip(Icons.shield, 'LVL', '${game.level}', Colors.purpleAccent, theme),
        ],
      ),
    );
  }

  Widget _resourceChip(IconData icon, String label, String value, Color color, ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(value, style: theme.textTheme.titleSmall?.copyWith(color: color, fontWeight: FontWeight.bold)),
        Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, ThemeData theme) {
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 18),
        const SizedBox(width: 8),
        Text(title, style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        )),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: theme.colorScheme.primary.withValues(alpha: 0.3))),
      ],
    );
  }

  Widget _buildTargetSelector(GameProvider game, ThemeData theme) {
    if (game.availableTargets.isEmpty) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off, size: 36, color: theme.colorScheme.outline),
              const SizedBox(height: 8),
              Text('Scanning for targets...', style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              )),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: game.availableTargets.length,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemBuilder: (context, index) {
          final target = game.availableTargets[index];
          final isSelected = _selectedTarget?.id == target.id;

          return GestureDetector(
            onTap: () => setState(() => _selectedTarget = target),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 160,
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline.withValues(alpha: 0.3),
                  width: isSelected ? 2 : 1,
                ),
                color: isSelected
                    ? theme.colorScheme.primaryContainer.withValues(alpha: 0.2)
                    : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
                boxShadow: isSelected
                    ? [BoxShadow(color: theme.colorScheme.primary.withValues(alpha: 0.2), blurRadius: 12)]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: theme.colorScheme.primary,
                        child: Text(
                          target.username.isNotEmpty ? target.username[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          target.username,
                          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (target.clanTag.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.tertiary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: theme.colorScheme.tertiary.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        '[${target.clanTag}]',
                        style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.tertiary),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Row(
                    children: [
                      Text('LVL ${target.level}', style: theme.textTheme.labelSmall),
                      const SizedBox(width: 12),
                      Text('STR', style: theme.textTheme.labelSmall),
                      const SizedBox(width: 4),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: (target.networkStrength / 500).clamp(0.0, 1.0),
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            target.networkStrength > 300
                                ? Colors.redAccent
                                : target.networkStrength > 150
                                    ? Colors.orangeAccent
                                    : Colors.greenAccent,
                          ),
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAttackTypeGrid(GameProvider game, ThemeData theme) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.85,
      ),
      itemCount: _attackTypes.length,
      itemBuilder: (context, index) {
        final attack = _attackTypes[index];
        final isSelected = _selectedAttackType == attack;
        final canAfford = game.credits >= attack.creditCost && game.cpu >= attack.cpuCost;

        return GestureDetector(
          onTap: canAfford ? () => setState(() => _selectedAttackType = attack) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? attack.color
                    : theme.colorScheme.outline.withValues(alpha: 0.2),
                width: isSelected ? 2 : 1,
              ),
              color: isSelected
                  ? attack.color.withValues(alpha: 0.15)
                  : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
              boxShadow: isSelected
                  ? [BoxShadow(color: attack.color.withValues(alpha: 0.15), blurRadius: 8)]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  attack.icon,
                  color: canAfford ? attack.color : theme.colorScheme.outline.withValues(alpha: 0.4),
                  size: 26,
                ),
                const SizedBox(height: 6),
                Text(
                  attack.name,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: canAfford ? theme.colorScheme.onSurface : theme.colorScheme.outline,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'DMG ${attack.damage}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: attack.color.withValues(alpha: canAfford ? 1.0 : 0.4),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${attack.creditCost} CR | ${attack.cpuCost} CPU',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: canAfford ? 1.0 : 0.4),
                    fontSize: 9,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLaunchButton(GameProvider game, ThemeData theme) {
    final canLaunch = _selectedTarget != null &&
        _selectedAttackType != null &&
        !_isAttacking &&
        game.credits >= (_selectedAttackType?.creditCost ?? 0) &&
        game.cpu >= (_selectedAttackType?.cpuCost ?? 0);

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: canLaunch ? _pulseAnimation.value : 0.4,
          child: child,
        );
      },
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: canLaunch ? _launchAttack : null,
          icon: _isAttacking
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.onPrimary,
                  ),
                )
              : const Icon(Icons.rocket_launch),
          label: Text(
            _isAttacking ? 'EXECUTING...' : 'LAUNCH ATTACK',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttackProgress(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'INITIATING ${_selectedAttackType?.name.toUpperCase() ?? ""}...',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              Text('${(_attackProgress * 100).toInt()}%', style: theme.textTheme.labelMedium),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _attackProgress,
              minHeight: 8,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                _selectedAttackType?.color ?? theme.colorScheme.primary,
              ),
            ),
          ),
          if (_selectedTarget != null) ...[
            const SizedBox(height: 6),
            Text(
              'Target: ${_selectedTarget!.username}',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAttackHistory(GameProvider game, ThemeData theme) {
    if (game.attackHistory.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_outlined, size: 36, color: theme.colorScheme.outline.withValues(alpha: 0.5)),
              const SizedBox(height: 8),
              Text(
                'No attack records yet',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
              ),
              Text(
                'Select a target and launch your first attack',
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline.withValues(alpha: 0.6)),
              ),
            ],
          ),
        ),
      );
    }

    final records = game.attackHistory.take(15).toList();
    return Column(
      children: records.map((record) {
        final isOutgoing = record.attackerId == context.read<AuthProvider>().userId;
        final statusColor = record.status == 'success'
            ? Colors.greenAccent
            : record.status == 'failed'
                ? Colors.redAccent
                : Colors.orangeAccent;
        final statusIcon = record.status == 'success'
            ? Icons.check_circle
            : record.status == 'failed'
                ? Icons.cancel
                : Icons.hourglass_top;

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.12),
            border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: (isOutgoing ? Colors.greenAccent : Colors.redAccent).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            isOutgoing ? 'OUT' : 'IN',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: isOutgoing ? Colors.greenAccent : Colors.redAccent,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${record.attackType} vs ${record.defenderName ?? "Unknown"}',
                            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text('DMG: ${record.damage}', style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant, fontSize: 11,
                        )),
                        if (record.creditsStolen > 0) ...[
                          const SizedBox(width: 12),
                          Text('+${record.creditsStolen} CR', style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.amberAccent, fontSize: 11,
                          )),
                        ],
                        const Spacer(),
                        Text(
                          _formatTimestamp(record.createdAt),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline, fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  record.status.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${dt.month}/${dt.day}';
  }
}

class _AttackType {
  final String name;
  final IconData icon;
  final int damage;
  final int creditCost;
  final int cpuCost;
  final Color color;
  final String description;

  const _AttackType({
    required this.name,
    required this.icon,
    required this.damage,
    required this.creditCost,
    required this.cpuCost,
    required this.color,
    required this.description,
  });
}
