import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/game_provider.dart';
import '../../providers/auth_provider.dart';

// ─── Campaign / PvE Missions Screen ────────────────────────────────────────────

class CampaignScreen extends StatefulWidget {
  const CampaignScreen({super.key});

  @override
  State<CampaignScreen> createState() => _CampaignScreenState();
}

class _CampaignScreenState extends State<CampaignScreen> with TickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _campaigns = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Battle dialog state
  bool _isBattleInProgress = false;
  double _battleProgress = 0.0;
  bool? _battleResult;
  Map<String, dynamic>? _currentBattle;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    _glowController.repeat(reverse: true);

    _loadCampaigns();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  // ── Data Loading ──

  Future<void> _loadCampaigns() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userId = context.read<AuthProvider>().userId;
      if (userId == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Не авторизован';
        });
        return;
      }

      final response = await _supabase
          .from('campaigns')
          .select('*, campaign_progress(status, attempts, best_damage, completed_at)')
          .eq('is_active', true)
          .order('sort_order');

      _campaigns = (response as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading campaigns: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Не удалось загрузить миссии';
      });
    }
  }

  // ── Campaign Status Helpers ──

  String _getCampaignStatus(Map<String, dynamic> campaign) {
    final progress = campaign['campaign_progress'] as List?;
    final playerLevel = context.read<GameProvider>().level;
    final requiredLevel = (campaign['required_level'] as num?)?.toInt() ?? 1;

    if (playerLevel < requiredLevel) return 'locked';
    if (progress != null && progress.isNotEmpty) {
      return progress.first['status'] as String? ?? 'available';
    }
    return 'available';
  }

  bool _isCompleted(String status) => status == 'completed';
  bool _isLocked(String status) => status == 'locked';
  bool _isAvailable(String status) => status == 'available' || status == 'in_progress';

  // ── Battle Logic ──

  Future<void> _startBattle(Map<String, dynamic> campaign) async {
    final auth = context.read<AuthProvider>();
    if (auth.userId == null) return;

    final playerLevel = context.read<GameProvider>().level;
    final enemyStrength = (campaign['enemy_strength'] as num?)?.toInt() ?? 50;

    // Player power = level * 20 + random(0, 50)
    final playerPower = playerLevel * 20 + Random().nextInt(51);

    setState(() {
      _isBattleInProgress = true;
      _battleProgress = 0.0;
      _battleResult = null;
      _currentBattle = {
        'campaign': campaign,
        'playerPower': playerPower,
        'enemyStrength': enemyStrength,
      };
    });

    // Animated progress over 3 seconds
    for (int i = 0; i <= 100; i += 2) {
      await Future.delayed(const Duration(milliseconds: 60));
      if (!mounted) return;
      setState(() => _battleProgress = i / 100);
    }

    // Success if player_power > enemy_strength * 0.7
    final success = playerPower > (enemyStrength * 0.7);
    setState(() {
      _battleResult = success;
    });

    if (success) {
      // Record completion in DB
      try {
        final userId = auth.userId!;
        final progress = campaign['campaign_progress'] as List?;
        final existingStatus = progress?.isNotEmpty == true
            ? progress!.first['status'] as String?
            : null;

        if (existingStatus != 'completed') {
          // Upsert campaign progress
          if (existingStatus != null) {
            await _supabase
                .from('campaign_progress')
                .update({
                  'status': 'completed',
                  'attempts': ((progress!.first['attempts'] as num?)?.toInt() ?? 0) + 1,
                  'best_damage': max(
                    (progress.first['best_damage'] as num?)?.toInt() ?? 0,
                    playerPower,
                  ),
                  'completed_at': DateTime.now().toUtc().toIso8601String(),
                })
                .eq('player_id', userId)
                .eq('campaign_id', campaign['id']);
          } else {
            await _supabase.from('campaign_progress').insert({
              'player_id': userId,
              'campaign_id': campaign['id'],
              'status': 'completed',
              'attempts': 1,
              'best_damage': playerPower,
              'completed_at': DateTime.now().toUtc().toIso8601String(),
            });
          }

          // Award rewards via RPC
          try {
            await _supabase.rpc('complete_campaign', params: {
              'p_player_id': userId,
              'p_campaign_id': campaign['id'],
              'p_credits': campaign['reward_credits'],
              'p_xp': campaign['reward_xp'],
            });
          } catch (rpcErr) {
            debugPrint('RPC complete_campaign failed, applying manually: $rpcErr');
            // Manual fallback: directly update profile
            final rewardCredits = (campaign['reward_credits'] as num?)?.toInt() ?? 0;
            final rewardXp = (campaign['reward_xp'] as num?)?.toInt() ?? 0;
            if (rewardCredits > 0 || rewardXp > 0) {
              await _supabase.rpc('add_rewards', params: {
                'p_player_id': userId,
                'p_credits': rewardCredits,
                'p_xp': rewardXp,
              });
            }
          }

          // Refresh game resources
          await context.read<GameProvider>().refreshResources(userId);
        }
      } catch (e) {
        debugPrint('Error recording campaign completion: $e');
      }
    }
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final game = context.watch<GameProvider>();
    final auth = context.watch<AuthProvider>();

    if (auth.userId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('МИССИИ')),
        body: Center(
          child: Text('Не авторизован', style: theme.textTheme.bodyLarge),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('МИССИИ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Обновить',
            onPressed: _isLoading ? null : _loadCampaigns,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Header Info ──
          _buildHeader(game, theme),
          const SizedBox(height: 8),

          // ── Campaign List ──
          Expanded(
            child: _isLoading
                ? _buildLoadingState(theme)
                : _errorMessage != null
                    ? _buildErrorState(theme)
                    : _campaigns.isEmpty
                        ? _buildEmptyState(theme)
                        : _buildCampaignList(game, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(GameProvider game, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _headerChip(Icons.shield, 'УР', '${game.level}', const Color(0xFF00F0FF), theme),
          _headerChip(Icons.bolt, 'АТАКА', '${game.level * 20}', const Color(0xFFFF0040), theme),
          _headerChip(Icons.monetization_on, 'CR', '${game.credits}', const Color(0xFFFFD700), theme),
          _headerChip(Icons.star, 'XP', '${game.xp}', const Color(0xFF00ff41), theme),
        ],
      ),
    );
  }

  Widget _headerChip(IconData icon, String label, String value, Color color, ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Color(0xFFFFD700),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Загрузка миссий...',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off, size: 48, color: theme.colorScheme.error.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadCampaigns,
              icon: const Icon(Icons.refresh),
              label: const Text('ПОВТОРИТЬ'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.military_tech, size: 64, color: const Color(0xFFFFD700).withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'Миссий пока нет',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Скоро здесь появятся новые задания',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCampaignList(GameProvider game, ThemeData theme) {
    return RefreshIndicator(
      color: const Color(0xFFFFD700),
      backgroundColor: const Color(0xFF111827),
      onRefresh: _loadCampaigns,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _campaigns.length,
        itemBuilder: (context, index) {
          final campaign = _campaigns[index];
          final status = _getCampaignStatus(campaign);
          return _buildCampaignCard(campaign, status, game, theme, index);
        },
      ),
    );
  }

  Widget _buildCampaignCard(
    Map<String, dynamic> campaign,
    String status,
    GameProvider game,
    ThemeData theme,
    int index,
  ) {
    final difficulty = (campaign['difficulty'] as num?)?.toInt() ?? 1;
    final requiredLevel = (campaign['required_level'] as num?)?.toInt() ?? 1;
    final rewardCredits = (campaign['reward_credits'] as num?)?.toInt() ?? 0;
    final rewardXp = (campaign['reward_xp'] as num?)?.toInt() ?? 0;
    final enemyName = campaign['enemy_name'] as String? ?? 'Неизвестный';
    final enemyStrength = (campaign['enemy_strength'] as num?)?.toInt() ?? 50;
    final missionName = campaign['name'] as String? ?? 'Миссия #${index + 1}';
    final missionDesc = campaign['description'] as String? ?? '';
    final attempts = _getAttempts(campaign);
    final bestDamage = _getBestDamage(campaign);
    final isLocked = _isLocked(status);
    final isCompleted = _isCompleted(status);
    final isAvailable = _isAvailable(status);

    final difficultyColor = _getDifficultyColor(difficulty);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: isLocked ? 0.45 : 1.0,
            child: child,
          );
        },
        child: GestureDetector(
          onTap: isAvailable
              ? () => _showAttackDialog(campaign, game, theme)
              : isCompleted
                  ? () => _showCompletedInfo(campaign, theme)
                  : null,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: isCompleted
                  ? LinearGradient(
                      colors: [
                        const Color(0xFF111827),
                        const Color(0xFF00ff41).withValues(alpha: 0.08),
                      ],
                    )
                  : isAvailable
                      ? LinearGradient(
                          colors: [
                            const Color(0xFF111827),
                            const Color(0xFF00F0FF).withValues(alpha: 0.05),
                          ],
                        )
                      : null,
              color: isAvailable || isCompleted ? null : const Color(0xFF111827),
              border: Border.all(
                color: isCompleted
                    ? const Color(0xFF00ff41).withValues(alpha: 0.4)
                    : isAvailable
                        ? const Color(0xFF00F0FF).withValues(alpha: 0.3)
                        : theme.colorScheme.outline.withValues(alpha: 0.15),
                width: isAvailable ? 1.5 : 1,
              ),
              boxShadow: isAvailable
                  ? [
                      BoxShadow(
                        color: const Color(0xFF00F0FF).withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  // ── Main Content ──
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        // ── Left: Difficulty ──
                        _buildDifficultyIndicator(difficulty, difficultyColor),
                        const SizedBox(width: 14),

                        // ── Center: Info ──
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Mission name
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      missionName,
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        color: isLocked
                                            ? theme.colorScheme.outline
                                            : Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isCompleted)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00ff41).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: const Color(0xFF00ff41).withValues(alpha: 0.4),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.check_circle, color: Color(0xFF00ff41), size: 14),
                                          const SizedBox(width: 4),
                                          const Text(
                                            'СДАНО',
                                            style: TextStyle(
                                              color: Color(0xFF00ff41),
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),

                              if (missionDesc.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  missionDesc,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: isLocked
                                        ? theme.colorScheme.outline.withValues(alpha: 0.5)
                                        : theme.colorScheme.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],

                              const SizedBox(height: 8),

                              // Enemy info
                              Row(
                                children: [
                                  Icon(
                                    Icons.report_problem,
                                    color: isLocked
                                        ? theme.colorScheme.outline.withValues(alpha: 0.4)
                                        : const Color(0xFFFF0040),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    enemyName,
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      color: isLocked
                                          ? theme.colorScheme.outline.withValues(alpha: 0.4)
                                          : const Color(0xFFFF0040),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'СИЛ',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  SizedBox(
                                    width: 60,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(3),
                                      child: LinearProgressIndicator(
                                        value: (enemyStrength / 200).clamp(0.0, 1.0),
                                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          enemyStrength > 150
                                              ? const Color(0xFFFF0040)
                                              : enemyStrength > 100
                                                  ? Colors.orangeAccent
                                                  : const Color(0xFFFFD700),
                                        ),
                                        minHeight: 5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$enemyStrength',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 8),

                              // Rewards row
                              Row(
                                children: [
                                  if (rewardCredits > 0)
                                    _rewardChip(Icons.monetization_on, '+$rewardCredits CR', const Color(0xFFFFD700)),
                                  if (rewardCredits > 0 && rewardXp > 0)
                                    const SizedBox(width: 10),
                                  if (rewardXp > 0)
                                    _rewardChip(Icons.star, '+$rewardXp XP', const Color(0xFF00ff41)),
                                  const Spacer(),
                                  if (isLocked)
                                    _lockedIndicator(requiredLevel, theme),
                                  if (isCompleted && attempts > 0)
                                    Text(
                                      'Попыток: $attempts',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                        fontSize: 11,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // ── Right: Action ──
                        const SizedBox(width: 8),
                        if (isAvailable)
                          AnimatedBuilder(
                            animation: _glowAnimation,
                            builder: (context, child) {
                              return Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFFFF0040).withValues(
                                    alpha: 0.15 + _glowAnimation.value * 0.1,
                                  ),
                                  border: Border.all(
                                    color: const Color(0xFFFF0040).withValues(
                                      alpha: 0.4 + _glowAnimation.value * 0.3,
                                    ),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFF0040).withValues(
                                        alpha: _glowAnimation.value * 0.25,
                                      ),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.bolt,
                                  color: Color(0xFFFF0040),
                                  size: 22,
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),

                  // ── Completed overlay checkmark ──
                  if (isCompleted)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF00ff41).withValues(alpha: 0.15),
                          border: Border.all(
                            color: const Color(0xFF00ff41).withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Color(0xFF00ff41),
                          size: 16,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultyIndicator(int difficulty, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFF1A2030),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: (difficulty / 10).clamp(0.1, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 0),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(
            '$difficulty',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _rewardChip(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _lockedIndicator(int requiredLevel, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.outline.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock, color: Color(0xFF3a4060), size: 12),
          const SizedBox(width: 4),
          Text(
            'УР $requiredLevel',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  int _getAttempts(Map<String, dynamic> campaign) {
    final progress = campaign['campaign_progress'] as List?;
    if (progress != null && progress.isNotEmpty) {
      return (progress.first['attempts'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  int _getBestDamage(Map<String, dynamic> campaign) {
    final progress = campaign['campaign_progress'] as List?;
    if (progress != null && progress.isNotEmpty) {
      return (progress.first['best_damage'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  Color _getDifficultyColor(int difficulty) {
    if (difficulty <= 3) return const Color(0xFF00ff41);
    if (difficulty <= 5) return const Color(0xFFFFD700);
    if (difficulty <= 7) return Colors.orangeAccent;
    return const Color(0xFFFF0040);
  }

  // ── Attack Dialog ──

  void _showAttackDialog(Map<String, dynamic> campaign, GameProvider game, ThemeData theme) {
    final difficulty = (campaign['difficulty'] as num?)?.toInt() ?? 1;
    final enemyName = campaign['enemy_name'] as String? ?? 'Неизвестный';
    final enemyStrength = (campaign['enemy_strength'] as num?)?.toInt() ?? 50;
    final rewardCredits = (campaign['reward_credits'] as num?)?.toInt() ?? 0;
    final rewardXp = (campaign['reward_xp'] as num?)?.toInt() ?? 0;
    final playerPower = game.level * 20;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return Dialog(
              backgroundColor: const Color(0xFF111827),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: const Color(0xFF00F0FF).withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Title ──
                    const Icon(Icons.shield, color: Color(0xFFFF0040), size: 36),
                    const SizedBox(height: 12),
                    Text(
                      campaign['name'] as String? ?? 'МИССИЯ',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: const Color(0xFF00F0FF),
                        fontSize: 20,
                        letterSpacing: 2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      campaign['description'] as String? ?? '',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    // ── Enemy Info ──
                    _buildEnemyBlock(enemyName, enemyStrength, difficulty, theme),
                    const SizedBox(height: 16),

                    // ── Player Power ──
                    _buildPlayerPowerBlock(playerPower, game.level, theme),
                    const SizedBox(height: 20),

                    // ── Battle Progress ──
                    if (_isBattleInProgress) ...[
                      _buildBattleProgressBar(theme),
                      const SizedBox(height: 16),
                    ],

                    // ── Battle Result ──
                    if (_battleResult != null && !_isBattleInProgress) ...[
                      _buildBattleResult(_battleResult!, rewardCredits, rewardXp, theme),
                      const SizedBox(height: 16),
                    ],

                    // ── Action Buttons ──
                    if (!_isBattleInProgress && _battleResult == null)
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            _startBattle(campaign);
                          },
                          icon: const Icon(Icons.bolt),
                          label: const Text(
                            'НАЧАТЬ АТАКУ',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF0040),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                    if (_battleResult != null && !_isBattleInProgress)
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text(
                            'ЗАКРЫТЬ',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),

                    if (_isBattleInProgress)
                      Text(
                        'Взлом в процессе...',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          letterSpacing: 1,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      // Reset state when dialog closes
      setState(() {
        _isBattleInProgress = false;
        _battleProgress = 0.0;
        _battleResult = null;
        _currentBattle = null;
      });
      _loadCampaigns();
    });
  }

  Widget _buildEnemyBlock(String enemyName, int enemyStrength, int difficulty, ThemeData theme) {
    final difficultyColor = _getDifficultyColor(difficulty);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFF0040).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFF0040).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.report_problem, color: Color(0xFFFF0040), size: 20),
              const SizedBox(width: 8),
              Text(
                'ЦЕЛЬ',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: const Color(0xFFFF0040),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: difficultyColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: difficultyColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  'СЛОЖ. $difficulty/10',
                  style: TextStyle(
                    color: difficultyColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            enemyName,
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Защита: ',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (enemyStrength / 200).clamp(0.0, 1.0),
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF0040)),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$enemyStrength',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFFF0040),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerPowerBlock(int playerPower, int playerLevel, ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF00F0FF).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF00F0FF).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person, color: Color(0xFF00F0FF), size: 20),
              const SizedBox(width: 8),
              Text(
                'ВАША МОЩЬ',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: const Color(0xFF00F0FF),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              Text(
                'УР $playerLevel',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Атака: ',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (playerPower / 200).clamp(0.0, 1.0),
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00F0FF)),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '~$playerPower',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF00F0FF),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '+ случайный бонус (0-50)',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBattleProgressBar(ThemeData theme) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ВЗЛОМ СИСТЕМЫ',
              style: theme.textTheme.labelMedium?.copyWith(
                color: const Color(0xFFFFD700),
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            Text(
              '${(_battleProgress * 100).toInt()}%',
              style: theme.textTheme.labelMedium?.copyWith(
                color: const Color(0xFFFFD700),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: _battleProgress,
            minHeight: 10,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
          ),
        ),
      ],
    );
  }

  Widget _buildBattleResult(bool success, int rewardCredits, int rewardXp, ThemeData theme) {
    final icon = success ? Icons.verified : Icons.cancel;
    final color = success ? const Color(0xFF00ff41) : const Color(0xFFFF0040);
    final title = success ? 'ВЗЛОМ УДАЛСЯ!' : 'ЗАЩИТА ОТБОЙ!';
    final subtitle = success
        ? 'Система успешно взломана'
        : 'Слишком сильная защита';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 44),
          const SizedBox(height: 10),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (success && _currentBattle != null) ...[
            const SizedBox(height: 12),
            Divider(color: color.withValues(alpha: 0.2)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    Text(
                      'Урон',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_currentBattle!['playerPower']}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: const Color(0xFF00F0FF),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
                if (rewardCredits > 0)
                  Column(
                    children: [
                      Text(
                        'Кредиты',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '+$rewardCredits',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: const Color(0xFFFFD700),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                if (rewardCredits > 0 && rewardXp > 0)
                  Container(
                    width: 1,
                    height: 32,
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                if (rewardXp > 0)
                  Column(
                    children: [
                      Text(
                        'Опыт',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '+$rewardXp',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: const Color(0xFF00ff41),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Completed Info Dialog ──

  void _showCompletedInfo(Map<String, dynamic> campaign, ThemeData theme) {
    final attempts = _getAttempts(campaign);
    final bestDamage = _getBestDamage(campaign);
    final progress = campaign['campaign_progress'] as List?;
    final completedAt = progress?.isNotEmpty == true
        ? progress!.first['completed_at'] as String?
        : null;

    String formattedDate = '';
    if (completedAt != null) {
      try {
        final dt = DateTime.parse(completedAt);
        formattedDate = '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: const Color(0xFF111827),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: const Color(0xFF00ff41).withValues(alpha: 0.3),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified, color: Color(0xFF00ff41), size: 44),
                const SizedBox(height: 12),
                Text(
                  'МИССИЯ ВЫПОЛНЕНА',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF00ff41),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 16),
                _infoRow('Миссия', campaign['name'] as String? ?? '-', theme),
                _infoRow('Враг', campaign['enemy_name'] as String? ?? '-', theme),
                _infoRow('Попыток', '$attempts', theme),
                _infoRow('Лучший урон', '$bestDamage', theme),
                if (formattedDate.isNotEmpty) _infoRow('Завершена', formattedDate, theme),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text(
                      'ЗАКРЫТЬ',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
