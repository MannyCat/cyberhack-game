import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/game_provider.dart';
import '../../providers/auth_provider.dart';

// ─── Campaign / PvE Missions Screen — PC Desktop ──────────────────────────────

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

    for (int i = 0; i <= 100; i += 2) {
      await Future.delayed(const Duration(milliseconds: 60));
      if (!mounted) return;
      setState(() => _battleProgress = i / 100);
    }

    final success = playerPower > (enemyStrength * 0.7);
    setState(() {
      _battleResult = success;
    });

    if (success) {
      try {
        final userId = auth.userId!;
        final progress = campaign['campaign_progress'] as List?;
        final existingStatus = progress?.isNotEmpty == true
            ? progress!.first['status'] as String?
            : null;

        if (existingStatus != 'completed') {
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

          try {
            await _supabase.rpc('complete_campaign', params: {
              'p_player_id': userId,
              'p_campaign_id': campaign['id'],
              'p_credits': campaign['reward_credits'],
              'p_xp': campaign['reward_xp'],
            });
          } catch (rpcErr) {
            debugPrint('RPC complete_campaign failed, applying manually: $rpcErr');
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
    final game = context.watch<GameProvider>();
    final auth = context.watch<AuthProvider>();

    if (auth.userId == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0a0e17),
        body: Center(
          child: Text('Не авторизован', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 16)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0a0e17),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            children: [
              // ── Header ──
              _buildHeader(game),
              const SizedBox(height: 16),

              // ── Content ──
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : _errorMessage != null
                        ? _buildErrorState()
                        : _campaigns.isEmpty
                            ? _buildEmptyState()
                            : _buildCampaignList(game),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(GameProvider game) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0d1220),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield, color: Color(0xFFFF0040), size: 24),
          const SizedBox(width: 12),
          const Text(
            'МИССИИ',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          const Spacer(),
          _headerChip(Icons.shield, 'УРОВЕНЬ', '${game.level}', const Color(0xFF00F0FF)),
          const SizedBox(width: 28),
          _headerChip(Icons.bolt, 'АТАКА', '${game.level * 20}', const Color(0xFFFF0040)),
          const SizedBox(width: 28),
          _headerChip(Icons.monetization_on, 'КРЕДИТЫ', '${game.credits}', const Color(0xFFFFD700)),
          const SizedBox(width: 28),
          _headerChip(Icons.star, 'ОПЫТ', '${game.xp}', const Color(0xFF00ff41)),
          const SizedBox(width: 16),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: _isLoading ? null : _loadCampaigns,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF1e293b)),
                ),
                child: const Icon(Icons.refresh, color: Color(0xFF4a5568), size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerChip(IconData icon, String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              value,
              style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF4a5568), fontSize: 10, letterSpacing: 1),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Color(0xFFFFD700),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Загрузка миссий...',
            style: TextStyle(color: Color(0xFF4a5568), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off, size: 56, color: Color(0xFFFF0040)),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: const TextStyle(color: Color(0xFFFF0040), fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: _loadCampaigns,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF0040).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFF0040).withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh, color: Color(0xFFFF0040), size: 18),
                    SizedBox(width: 8),
                    Text('ПОВТОРИТЬ', style: TextStyle(color: Color(0xFFFF0040), fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.military_tech, size: 72, color: Color(0xFFFFD700)),
          const SizedBox(height: 20),
          const Text(
            'Миссий пока нет',
            style: TextStyle(color: Color(0xFF4a5568), fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Скоро здесь появятся новые задания',
            style: TextStyle(color: Color(0xFF3a4060), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildCampaignList(GameProvider game) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      itemCount: _campaigns.length,
      itemBuilder: (context, index) {
        final campaign = _campaigns[index];
        final status = _getCampaignStatus(campaign);
        return _buildCampaignCard(campaign, status, game, index);
      },
    );
  }

  Widget _buildCampaignCard(
    Map<String, dynamic> campaign,
    String status,
    GameProvider game,
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
      padding: const EdgeInsets.only(bottom: 12),
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: isLocked ? 0.45 : 1.0,
            child: child,
          );
        },
        child: MouseRegion(
          cursor: (isAvailable || isCompleted) ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: GestureDetector(
            onTap: isAvailable
                ? () => _showAttackDialog(campaign, game)
                : isCompleted
                    ? () => _showCompletedInfo(campaign)
                    : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: isCompleted
                    ? LinearGradient(
                        colors: [
                          const Color(0xFF0d1220),
                          const Color(0xFF00ff41).withValues(alpha: 0.08),
                        ],
                      )
                    : isAvailable
                        ? LinearGradient(
                            colors: [
                              const Color(0xFF0d1220),
                              const Color(0xFF00F0FF).withValues(alpha: 0.05),
                            ],
                          )
                        : null,
                color: isAvailable || isCompleted ? null : const Color(0xFF0d1220),
                border: Border.all(
                  color: isCompleted
                      ? const Color(0xFF00ff41).withValues(alpha: 0.4)
                      : isAvailable
                          ? const Color(0xFF00F0FF).withValues(alpha: 0.3)
                          : const Color(0xFF1e293b),
                  width: isAvailable ? 1.5 : 1,
                ),
                boxShadow: isAvailable
                    ? [
                        BoxShadow(
                          color: const Color(0xFF00F0FF).withValues(alpha: 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  // ── Left: Difficulty ──
                  _buildDifficultyIndicator(difficulty, difficultyColor),
                  const SizedBox(width: 20),

                  // ── Center: Info ──
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                missionName,
                                style: TextStyle(
                                  color: isLocked
                                      ? const Color(0xFF4a5568)
                                      : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isCompleted)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00ff41).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF00ff41).withValues(alpha: 0.4)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle, color: Color(0xFF00ff41), size: 14),
                                    SizedBox(width: 4),
                                    Text('СДАНО', style: TextStyle(color: Color(0xFF00ff41), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        if (missionDesc.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            missionDesc,
                            style: TextStyle(color: isLocked ? const Color(0xFF3a4060) : Colors.white.withValues(alpha: 0.5), fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 10),
                        // Enemy info row
                        Row(
                          children: [
                            Icon(Icons.report_problem, color: isLocked ? const Color(0xFF3a4060) : const Color(0xFFFF0040), size: 16),
                            const SizedBox(width: 6),
                            Text(enemyName, style: TextStyle(color: isLocked ? const Color(0xFF3a4060) : const Color(0xFFFF0040), fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(width: 16),
                            Text('СИЛА:', style: const TextStyle(color: Color(0xFF4a5568), fontSize: 11)),
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 80,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: (enemyStrength / 200).clamp(0.0, 1.0),
                                  backgroundColor: const Color(0xFF111827),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    enemyStrength > 150 ? const Color(0xFFFF0040) : enemyStrength > 100 ? Colors.orangeAccent : const Color(0xFFFFD700),
                                  ),
                                  minHeight: 6,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('$enemyStrength', style: const TextStyle(color: Color(0xFF4a5568), fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Rewards row
                        Row(
                          children: [
                            if (rewardCredits > 0) _rewardChip(Icons.monetization_on, '+$rewardCredits CR', const Color(0xFFFFD700)),
                            if (rewardCredits > 0 && rewardXp > 0) const SizedBox(width: 16),
                            if (rewardXp > 0) _rewardChip(Icons.star, '+$rewardXp XP', const Color(0xFF00ff41)),
                            const Spacer(),
                            if (isLocked) _lockedIndicator(requiredLevel),
                            if (isCompleted && attempts > 0)
                              Text('Попыток: $attempts', style: const TextStyle(color: Color(0xFF4a5568), fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ── Right: Action ──
                  if (isAvailable)
                    AnimatedBuilder(
                      animation: _glowAnimation,
                      builder: (context, child) {
                        return Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFFF0040).withValues(alpha: 0.15 + _glowAnimation.value * 0.1),
                            border: Border.all(color: const Color(0xFFFF0040).withValues(alpha: 0.4 + _glowAnimation.value * 0.3), width: 2),
                            boxShadow: [
                              BoxShadow(color: const Color(0xFFFF0040).withValues(alpha: _glowAnimation.value * 0.25), blurRadius: 14),
                            ],
                          ),
                          child: const Icon(Icons.bolt, color: Color(0xFFFF0040), size: 24),
                        );
                      },
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
          width: 8,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFF1A2030),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: (difficulty / 10).clamp(0.1, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8)],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text('$difficulty', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _rewardChip(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 15),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _lockedIndicator(int requiredLevel) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF1e293b)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock, color: Color(0xFF3a4060), size: 14),
          const SizedBox(width: 4),
          Text('УР $requiredLevel', style: const TextStyle(color: Color(0xFF4a5568), fontSize: 12)),
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

  void _showAttackDialog(Map<String, dynamic> campaign, GameProvider game) {
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
                side: BorderSide(color: const Color(0xFF00F0FF).withValues(alpha: 0.3), width: 1.5),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shield, color: Color(0xFFFF0040), size: 40),
                      const SizedBox(height: 14),
                      Text(
                        campaign['name'] as String? ?? 'МИССИЯ',
                        style: const TextStyle(color: Color(0xFF00F0FF), fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 2),
                        textAlign: TextAlign.center,
                      ),
                      if ((campaign['description'] as String?)?.isNotEmpty == true) ...[
                        const SizedBox(height: 6),
                        Text(
                          campaign['description'] as String? ?? '',
                          style: const TextStyle(color: Color(0xFF4a5568), fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 20),

                      // Enemy + Player side by side
                      Row(
                        children: [
                          Expanded(child: _buildEnemyBlock(enemyName, enemyStrength, difficulty)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildPlayerPowerBlock(playerPower, game.level)),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Battle Progress
                      if (_isBattleInProgress) ...[
                        _buildBattleProgressBar(),
                        const SizedBox(height: 16),
                      ],

                      // Battle Result
                      if (_battleResult != null && !_isBattleInProgress) ...[
                        _buildBattleResult(_battleResult!, rewardCredits, rewardXp),
                        const SizedBox(height: 16),
                      ],

                      // Action Buttons
                      if (!_isBattleInProgress && _battleResult == null)
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pop(dialogContext);
                              _startBattle(campaign);
                            },
                            child: Container(
                              width: double.infinity,
                              height: 52,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: const Color(0xFFFF0040),
                                boxShadow: [BoxShadow(color: const Color(0xFFFF0040).withValues(alpha: 0.3), blurRadius: 16)],
                              ),
                              child: const Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.bolt, color: Colors.white, size: 20),
                                    SizedBox(width: 8),
                                    Text('НАЧАТЬ АТАКУ', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 2)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                      if (_battleResult != null && !_isBattleInProgress)
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () => Navigator.pop(dialogContext),
                            child: Container(
                              width: double.infinity,
                              height: 48,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF1e293b)),
                              ),
                              child: const Center(
                                child: Text('ЗАКРЫТЬ', style: TextStyle(color: Color(0xFF4a5568), fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                              ),
                            ),
                          ),
                        ),

                      if (_isBattleInProgress)
                        const Text('Взлом в процессе...', style: TextStyle(color: Color(0xFFFFD700), fontSize: 13, letterSpacing: 1)),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      setState(() {
        _isBattleInProgress = false;
        _battleProgress = 0.0;
        _battleResult = null;
        _currentBattle = null;
      });
      _loadCampaigns();
    });
  }

  Widget _buildEnemyBlock(String enemyName, int enemyStrength, int difficulty) {
    final difficultyColor = _getDifficultyColor(difficulty);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFF0040).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF0040).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.report_problem, color: Color(0xFFFF0040), size: 18),
              const SizedBox(width: 6),
              const Text('ЦЕЛЬ', style: TextStyle(color: Color(0xFFFF0040), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: difficultyColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: difficultyColor.withValues(alpha: 0.4)),
                ),
                child: Text('СЛОЖ. $difficulty/10', style: TextStyle(color: difficultyColor, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(enemyName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Защита: ', style: TextStyle(color: Color(0xFF4a5568), fontSize: 12)),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (enemyStrength / 200).clamp(0.0, 1.0),
                    backgroundColor: const Color(0xFF111827),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF0040)),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('$enemyStrength', style: const TextStyle(color: Color(0xFFFF0040), fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerPowerBlock(int playerPower, int playerLevel) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF00F0FF).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00F0FF).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person, color: Color(0xFF00F0FF), size: 18),
              const SizedBox(width: 6),
              const Text('ВАША МОЩЬ', style: TextStyle(color: Color(0xFF00F0FF), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const Spacer(),
              Text('УР $playerLevel', style: const TextStyle(color: Color(0xFF4a5568), fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          Text('~$playerPower урона', style: const TextStyle(color: Color(0xFF00F0FF), fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Атака: ', style: TextStyle(color: Color(0xFF4a5568), fontSize: 12)),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (playerPower / 200).clamp(0.0, 1.0),
                    backgroundColor: const Color(0xFF111827),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00F0FF)),
                    minHeight: 8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text('+ случайный бонус (0-50)', style: TextStyle(color: Color(0xFF3a4060), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildBattleProgressBar() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('ВЗЛОМ СИСТЕМЫ', style: TextStyle(color: Color(0xFFFFD700), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
            Text('${(_battleProgress * 100).toInt()}%', style: const TextStyle(color: Color(0xFFFFD700), fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: _battleProgress,
            minHeight: 10,
            backgroundColor: const Color(0xFF111827),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
          ),
        ),
      ],
    );
  }

  Widget _buildBattleResult(bool success, int rewardCredits, int rewardXp) {
    final icon = success ? Icons.verified : Icons.cancel;
    final color = success ? const Color(0xFF00ff41) : const Color(0xFFFF0040);
    final title = success ? 'ВЗЛОМ УДАЛСЯ!' : 'ЗАЩИТА ОТБОЙ!';
    final subtitle = success ? 'Система успешно взломана' : 'Слишком сильная защита';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 44),
          const SizedBox(height: 10),
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 2)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Color(0xFF4a5568), fontSize: 12)),
          if (success && _currentBattle != null) ...[
            const SizedBox(height: 12),
            const Divider(color: Color(0xFF1e293b)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    const Text('Урон', style: TextStyle(color: Color(0xFF4a5568), fontSize: 11)),
                    const SizedBox(height: 2),
                    Text('${_currentBattle!['playerPower']}', style: const TextStyle(color: Color(0xFF00F0FF), fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                Container(width: 1, height: 32, color: const Color(0xFF1e293b)),
                if (rewardCredits > 0)
                  Column(
                    children: [
                      const Text('Кредиты', style: TextStyle(color: Color(0xFF4a5568), fontSize: 11)),
                      const SizedBox(height: 2),
                      Text('+$rewardCredits', style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                if (rewardCredits > 0 && rewardXp > 0)
                  Container(width: 1, height: 32, color: const Color(0xFF1e293b)),
                if (rewardXp > 0)
                  Column(
                    children: [
                      const Text('Опыт', style: TextStyle(color: Color(0xFF4a5568), fontSize: 11)),
                      const SizedBox(height: 2),
                      Text('+$rewardXp', style: const TextStyle(color: Color(0xFF00ff41), fontWeight: FontWeight.bold, fontSize: 16)),
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

  void _showCompletedInfo(Map<String, dynamic> campaign) {
    final attempts = _getAttempts(campaign);
    final bestDamage = _getBestDamage(campaign);
    final progress = campaign['campaign_progress'] as List?;
    final completedAt = progress?.isNotEmpty == true ? progress!.first['completed_at'] as String? : null;

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
            side: BorderSide(color: const Color(0xFF00ff41).withValues(alpha: 0.3)),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified, color: Color(0xFF00ff41), size: 48),
                  const SizedBox(height: 14),
                  const Text('МИССИЯ ВЫПОЛНЕНА', style: TextStyle(color: Color(0xFF00ff41), fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 2)),
                  const SizedBox(height: 20),
                  _infoRow('Миссия', campaign['name'] as String? ?? '-'),
                  _infoRow('Враг', campaign['enemy_name'] as String? ?? '-'),
                  _infoRow('Попыток', '$attempts'),
                  _infoRow('Лучший урон', '$bestDamage'),
                  if (formattedDate.isNotEmpty) _infoRow('Завершена', formattedDate),
                  const SizedBox(height: 24),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(dialogContext),
                      child: Container(
                        width: double.infinity,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF1e293b)),
                        ),
                        child: const Center(
                          child: Text('ЗАКРЫТЬ', style: TextStyle(color: Color(0xFF4a5568), fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                        ),
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

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF4a5568), fontSize: 14)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }
}
