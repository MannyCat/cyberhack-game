import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../providers/game_provider.dart';
import '../../widgets/cyber_button.dart';
import '../../config/game_config.dart';

// ─── PC Profile Screen — Десктопный кибер-профиль ────────────────────────────

class ProfileScreen extends StatefulWidget {
  final PlayerProfileData? profile;

  const ProfileScreen({super.key, this.profile});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  late AnimationController _xpController;
  late Animation<double> _xpAnim;

  @override
  void initState() {
    super.initState();
    _xpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _xpAnim = Tween<double>(begin: 0, end: 0.0).animate(CurvedAnimation(
      parent: _xpController,
      curve: Curves.easeOutCubic,
    ));
    _xpController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final game = context.read<GameProvider>();
      final auth = context.read<AuthProvider>();
      if (auth.userId != null) {
        game.init(auth.userId!);
      }
      final level = game.level;
      final xp = game.xp;
      final xpNeeded = ProgressionConfig.xpRequiredForLevel(level);
      final target = xpNeeded > 0 ? (xp / xpNeeded).clamp(0.0, 1.0) : 0.0;
      if (mounted) {
        setState(() {
          _xpAnim = Tween<double>(begin: 0, end: target).animate(CurvedAnimation(
            parent: _xpController,
            curve: Curves.easeOutCubic,
          ));
        });
        _xpController.forward(from: 0);
      }
    });
  }

  @override
  void dispose() {
    _xpController.dispose();
    super.dispose();
  }

  String _rankTitle(int level) {
    if (level >= 50) return 'ЛЕГЕНДА';
    if (level >= 40) return 'МАСТЕР';
    if (level >= 30) return 'ВЕТЕРАН';
    if (level >= 20) return 'ОПЕРАТИВНИК';
    if (level >= 10) return 'СПЕЦИАЛИСТ';
    return 'НОВИЧОК';
  }

  Color _rankColor(int level) {
    if (level >= 50) return const Color(0xFFFFD700);
    if (level >= 40) return const Color(0xFF00F0FF);
    if (level >= 30) return const Color(0xFFa855f7);
    if (level >= 20) return const Color(0xFF00ff41);
    if (level >= 10) return const Color(0xFFff9800);
    return const Color(0xFF4a5568);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final game = context.watch<GameProvider>();

    final username = (widget.profile?.handle.isNotEmpty == true
        ? widget.profile!.handle
        : auth.displayName.isNotEmpty
            ? auth.displayName
            : 'Хакер');
    final level = widget.profile?.level ?? game.level;
    final xp = widget.profile?.currentXp ?? game.xp;
    final xpNeeded = widget.profile?.xpToNextLevel ?? ProgressionConfig.xpRequiredForLevel(level);
    final ranking = widget.profile?.ranking ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFF0a0e17),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header: Back + Title ──
                Row(
                  children: [
                    _cyberBackButton(() => context.pop()),
                    const SizedBox(width: 16),
                    const Text('ПРОФИЛЬ ХАКЕРА',
                      style: TextStyle(color: Color(0xFF00F0FF), fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 4, fontFamily: 'monospace')),
                    const Spacer(),
                    CyberButton(
                      label: 'РЕДАКТИРОВАТЬ',
                      variant: CyberButtonVariant.secondary,
                      icon: Icons.edit,
                      height: 38,
                      onPressed: _onEditProfile,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ── TOP ROW: Hero Card (left 60%) + Rank Card (right 40%) ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hero Card
                    Expanded(
                      flex: 6,
                      child: _HeroCard(
                        username: username,
                        level: level,
                        rankTitle: _rankTitle(level),
                        rankColor: _rankColor(level),
                        xp: xp,
                        xpNeeded: xpNeeded,
                        xpAnim: _xpAnim,
                        ranking: ranking,
                        clanId: auth.profile?.clanId,
                        createdAt: auth.profile?.createdAt,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Rank Card
                    Expanded(
                      flex: 4,
                      child: _RankCard(
                        level: level,
                        rankTitle: _rankTitle(level),
                        rankColor: _rankColor(level),
                        ranking: ranking,
                        game: game,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── STATS ROW: Resources + Combat (3 columns) ──
                _StatsRow(game: game, auth: auth),

                const SizedBox(height: 16),

                // ── BOTTOM ROW: Network (left 60%) + Achievements (right 40%) ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 6,
                      child: _NetworkPanel(nodes: game.networkNodes),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 4,
                      child: _AccountInfoCard(
                        auth: auth,
                        game: game,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cyberBackButton(VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF00ff41).withValues(alpha: 0.25)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_back, color: Color(0xFF00ff41), size: 18),
              SizedBox(width: 6),
              Text('НАЗАД', style: TextStyle(color: Color(0xFF00ff41), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1, fontFamily: 'monospace')),
            ],
          ),
        ),
      ),
    );
  }

  void _onEditProfile() {
    final auth = context.read<AuthProvider>();
    final ctrl = TextEditingController(text: auth.displayName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF00E5FF)),
        ),
        title: const Text('Редактировать профиль', style: TextStyle(color: Color(0xFF00E5FF))),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            labelText: 'Имя пользователя',
            labelStyle: const TextStyle(color: Color(0xFF00E5FF)),
            filled: true,
            fillColor: const Color(0xFF12162A),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: const Color(0xFF2A2F45))),
            focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF00E5FF))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ctrl.dispose();
              Navigator.pop(ctx);
            },
            child: const Text('ОТМЕНА', style: TextStyle(color: Colors.white54)),
          ),
          CyberButton(
            label: 'СОХРАНИТЬ',
            variant: CyberButtonVariant.secondary,
            height: 36,
            onPressed: () async {
              final newName = ctrl.text.trim();
              if (newName.isEmpty) return;
              Navigator.pop(ctx);
              ctrl.dispose();
              try {
                await Supabase.instance.client
                    .from('profiles')
                    .update({'username': newName})
                    .eq('id', auth.userId!);
                await auth.refreshProfile();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Профиль обновлён'), backgroundColor: Color(0xFF00FF41)),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ошибка: $e'), backgroundColor: Color(0xFFFF0040)),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}

// ─── Hero Card — Главная карточка профиля ───────────────────────────────────

class _HeroCard extends StatelessWidget {
  final String username;
  final int level;
  final String rankTitle;
  final Color rankColor;
  final int xp;
  final int xpNeeded;
  final Animation<double> xpAnim;
  final int ranking;
  final String? clanId;
  final DateTime? createdAt;

  const _HeroCard({
    required this.username,
    required this.level,
    required this.rankTitle,
    required this.rankColor,
    required this.xp,
    required this.xpNeeded,
    required this.xpAnim,
    required this.ranking,
    this.clanId,
    this.createdAt,
  });

  @override
  Widget build(BuildContext context) {
    final accountAge = createdAt != null ? DateTime.now().difference(createdAt!).inDays : 0;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFF111827), const Color(0xFF0d1220)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: rankColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(color: rankColor.withValues(alpha: 0.06), blurRadius: 32, spreadRadius: 2),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 88, height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [rankColor, rankColor.withValues(alpha: 0.4)]),
                  border: Border.all(color: rankColor.withValues(alpha: 0.5), width: 3),
                  boxShadow: [
                    BoxShadow(color: rankColor.withValues(alpha: 0.25), blurRadius: 24, spreadRadius: 4),
                  ],
                ),
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: const Color(0xFF0a0e17),
                  child: Text(
                    username.isNotEmpty ? username.substring(0, min(2, username.length)).toUpperCase() : '?',
                    style: TextStyle(color: rankColor, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 2),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              // Name + Rank
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(username,
                      style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: rankColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: rankColor.withValues(alpha: 0.3)),
                          ),
                          child: Text('УРОВЕНЬ $level',
                            style: TextStyle(color: rankColor, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1, fontFamily: 'monospace')),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: rankColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: rankColor.withValues(alpha: 0.2)),
                          ),
                          child: Text(rankTitle,
                            style: TextStyle(color: rankColor.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1, fontFamily: 'monospace')),
                        ),
                        if (clanId != null) ...[
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFa855f7).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFa855f7).withValues(alpha: 0.3)),
                            ),
                            child: const Text('В КЛАНЕ',
                              style: TextStyle(color: Color(0xFFa855f7), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1, fontFamily: 'monospace')),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Ranking badge
              if (ranking > 0)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00ff41).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF00ff41).withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 28),
                      const SizedBox(height: 4),
                      const Text('РЕЙТИНГ', style: TextStyle(color: Color(0xFF4a5568), fontSize: 9, letterSpacing: 1, fontFamily: 'monospace')),
                      Text('#$ranking', style: const TextStyle(color: Color(0xFFFFD700), fontSize: 20, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(color: Color(0xFF1e2535), height: 1),
          const SizedBox(height: 16),

          // XP Bar
          Row(
            children: [
              const Text('ОПЫТ', style: TextStyle(color: Color(0xFF4a5568), fontSize: 11, letterSpacing: 2, fontFamily: 'monospace')),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: ListenableBuilder(
                    listenable: xpAnim,
                    builder: (context, _) => LinearProgressIndicator(
                      value: xpAnim.value,
                      minHeight: 12,
                      backgroundColor: const Color(0xFF0d1117),
                      valueColor: AlwaysStoppedAnimation<Color>(rankColor),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('$xp / $xpNeeded', style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 12, fontFamily: 'monospace')),
            ],
          ),

          // Bottom info row
          const SizedBox(height: 16),
          Row(
            children: [
              _miniStat(Icons.schedule, '$accountAge ДНЕЙ В ИГРЕ', const Color(0xFF00E5FF)),
              const SizedBox(width: 24),
              _miniStat(Icons.dns, 'УЗЛОВ В СЕТИ', const Color(0xFF00ff41)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color.withValues(alpha: 0.5), size: 14),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color.withValues(alpha: 0.4), fontSize: 10, letterSpacing: 1, fontFamily: 'monospace')),
      ],
    );
  }
}

// ─── Rank Card — Информация о ранге ─────────────────────────────────────────

class _RankCard extends StatelessWidget {
  final int level;
  final String rankTitle;
  final Color rankColor;
  final int ranking;
  final GameProvider game;

  const _RankCard({
    required this.level,
    required this.rankTitle,
    required this.rankColor,
    required this.ranking,
    required this.game,
  });

  @override
  Widget build(BuildContext context) {
    final xpPercent = ProgressionConfig.xpRequiredForLevel(level) > 0
        ? (game.xp / ProgressionConfig.xpRequiredForLevel(level)).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: rankColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield, color: rankColor, size: 22),
              const SizedBox(width: 10),
              const Text('КЛАССИФИКАЦИЯ',
                style: TextStyle(color: Color(0xFF4a5568), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2, fontFamily: 'monospace')),
            ],
          ),
          const SizedBox(height: 16),
          // Rank icon
          Center(
            child: Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: rankColor.withValues(alpha: 0.08),
                border: Border.all(color: rankColor.withValues(alpha: 0.3), width: 2),
                boxShadow: [
                  BoxShadow(color: rankColor.withValues(alpha: 0.15), blurRadius: 16),
                ],
              ),
              child: Center(
                child: Text('$level',
                  style: TextStyle(color: rankColor, fontSize: 28, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(rankTitle,
              style: TextStyle(color: rankColor, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 2, fontFamily: 'monospace')),
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFF1e2535), height: 1),
          const SizedBox(height: 12),
          // Progress to next rank
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Прогресс ранга', style: TextStyle(color: Color(0xFF4a5568), fontSize: 10, fontFamily: 'monospace')),
              Text('${(xpPercent * 100).toStringAsFixed(0)}%',
                style: TextStyle(color: rankColor, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: xpPercent,
              minHeight: 6,
              backgroundColor: const Color(0xFF0d1117),
              valueColor: AlwaysStoppedAnimation<Color>(rankColor),
            ),
          ),
          const SizedBox(height: 16),
          // Quick stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _quickStat('XP', _formatNum(game.xp), const Color(0xFFFFD700)),
              _quickStat('УР', '$level', const Color(0xFF00E5FF)),
              _quickStat('КР', _formatNum(game.credits), const Color(0xFFFFD700)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
          Text(label, style: TextStyle(color: color.withValues(alpha: 0.4), fontSize: 9, letterSpacing: 1, fontFamily: 'monospace')),
        ],
      ),
    );
  }
}

// ─── Stats Row — Ресурсы + Боевая статистика ──────────────────────────────────

class _StatsRow extends StatelessWidget {
  final GameProvider game;
  final AuthProvider auth;

  const _StatsRow({required this.game, required this.auth});

  @override
  Widget build(BuildContext context) {
    final totalAttacks = game.attackHistory.where((a) => a.attackerId == auth.userId).length;
    final successfulAttacks = game.attackHistory.where((a) => a.attackerId == auth.userId && a.status == 'success').length;
    final creditsEarned = game.attackHistory
        .where((a) => a.attackerId == auth.userId && a.status == 'success')
        .fold<int>(0, (sum, a) => sum + a.creditsStolen);
    final onlineNodes = game.networkNodes.where((n) => n.isOnline).length;

    return Row(
      children: [
        // Resources
        Expanded(
          child: _StatsSection(
            title: 'РЕСУРСЫ',
            titleColor: const Color(0xFFFFD700),
            stats: [
              _StatItem(label: 'Кредиты', value: _formatNum(game.credits), icon: Icons.monetization_on, color: const Color(0xFFFFD700)),
              _StatItem(label: 'ЦПУ', value: '${game.cpu} THz', icon: Icons.memory, color: const Color(0xFF00E5FF)),
              _StatItem(label: 'Канал', value: '${game.bandwidth} MB/s', icon: Icons.wifi_tethering, color: const Color(0xFFFF9800)),
              _StatItem(label: 'Доход', value: '+${game.passiveIncomePerTick} ¢/30с', icon: Icons.trending_up, color: const Color(0xFF00ff41)),
            ],
            columns: 4,
          ),
        ),
        const SizedBox(width: 16),
        // Combat
        Expanded(
          child: _StatsSection(
            title: 'БОЕВАЯ СТАТИСТИКА',
            titleColor: const Color(0xFFFF1744),
            stats: [
              _StatItem(label: 'Всего атак', value: '$totalAttacks', icon: Icons.gps_fixed, color: const Color(0xFFFF1744)),
              _StatItem(label: 'Успешных', value: '$successfulAttacks', icon: Icons.check_circle_outline, color: const Color(0xFF39FF14)),
              _StatItem(label: 'Заработано', value: _formatNum(creditsEarned), icon: Icons.monetization_on, color: const Color(0xFFFFD700)),
              _StatItem(label: 'Узлов онлайн', value: '$onlineNodes/${game.networkNodes.length}', icon: Icons.dns, color: const Color(0xFF00E5FF)),
            ],
            columns: 4,
          ),
        ),
      ],
    );
  }
}

// ─── Stats Section — Универсальная секция статистики ─────────────────────────

class _StatsSection extends StatelessWidget {
  final String title;
  final Color titleColor;
  final List<_StatItem> stats;
  final int columns;

  const _StatsSection({
    required this.title,
    required this.titleColor,
    required this.stats,
    this.columns = 4,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: titleColor.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 3, height: 14, decoration: BoxDecoration(color: titleColor, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              Text(title,
                style: TextStyle(color: titleColor, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2, fontFamily: 'monospace')),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: List.generate(stats.length, (i) {
              if (i > 0) return Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Expanded(child: _PCStatCard(stat: stats[i])),
              );
              return Expanded(child: _PCStatCard(stat: stats[i]));
            }),
          ),
        ],
      ),
    );
  }
}

// ─── PC Stat Card — Широкая карточка статистики ─────────────────────────────

class _PCStatCard extends StatelessWidget {
  final _StatItem stat;
  const _PCStatCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: stat.color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: stat.color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: stat.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: stat.color.withValues(alpha: 0.2)),
            ),
            child: Icon(stat.icon, color: stat.color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stat.value,
                  style: TextStyle(color: stat.color, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5, fontFamily: 'monospace'),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(stat.label,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Network Panel — Список узлов ───────────────────────────────────────────

class _NetworkPanel extends StatelessWidget {
  final List nodes;

  const _NetworkPanel({required this.nodes});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(width: 3, height: 14, decoration: BoxDecoration(color: const Color(0xFF00E5FF), borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 8),
                const Text('ВАША СЕТЬ',
                  style: TextStyle(color: Color(0xFF00E5FF), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2, fontFamily: 'monospace')),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00ff41).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF00ff41).withValues(alpha: 0.2)),
                  ),
                  child: Text('${nodes.length} УЗЛОВ',
                    style: const TextStyle(color: const Color(0xFF00ff41), fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                ),
              ],
            ),
          ),
          if (nodes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.dns_outlined, color: const Color(0xFF4a5568).withValues(alpha: 0.3), size: 48),
                    const SizedBox(height: 12),
                    const Text('Сеть пуста. Разверните первый узел!',
                      style: TextStyle(color: Color(0xFF4a5568), fontSize: 13)),
                  ],
                ),
              ),
            )
          else
            ...nodes.take(8).map((node) {
              final isOnline = node.isOnline == true;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: const Color(0xFF1e2535).withValues(alpha: 0.5))),
                ),
                child: Row(
                  children: [
                    // Status dot
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: isOnline ? const Color(0xFF00ff41) : const Color(0xFF4a5568),
                        shape: BoxShape.circle,
                        boxShadow: isOnline
                            ? [BoxShadow(color: const Color(0xFF00ff41).withValues(alpha: 0.5), blurRadius: 6)]
                            : [],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.dns, color: isOnline ? const Color(0xFF00E5FF) : const Color(0xFF4a5568), size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${_nodeTypeLabel(node.nodeType ?? '')} #${node.id.length >= 8 ? node.id.substring(0, 8) : node.id}',
                        style: TextStyle(color: isOnline ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF4a5568), fontSize: 13, fontFamily: 'monospace'),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (isOnline ? const Color(0xFF00ff41) : const Color(0xFF4a5568)).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isOnline ? 'ОНЛАЙН' : 'ОФФЛАЙН',
                        style: TextStyle(
                          color: isOnline ? const Color(0xFF00ff41) : const Color(0xFF4a5568),
                          fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5, fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('УР ${node.nodeLevel ?? 1}',
                      style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                  ],
                ),
              );
            }),
          if (nodes.length > 8)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text('+ ещё ${nodes.length - 8} узлов',
                  style: const TextStyle(color: Color(0xFF4a5568), fontSize: 11, fontFamily: 'monospace')),
              ),
            ),
        ],
      ),
    );
  }

  String _nodeTypeLabel(String nodeType) {
    return switch (nodeType.toLowerCase()) {
      'server' => 'Сервер',
      'firewall' => 'Файрвол',
      'proxy' => 'Прокси',
      'router' => 'Роутер',
      'miner' => 'Майнер',
      'scanner' => 'Сканер',
      'database' => 'БД',
      'terminal' => 'Терминал',
      _ => nodeType,
    };
  }
}

// ─── Account Info Card ──────────────────────────────────────────────────────

class _AccountInfoCard extends StatelessWidget {
  final AuthProvider auth;
  final GameProvider game;

  const _AccountInfoCard({required this.auth, required this.game});

  @override
  Widget build(BuildContext context) {
    final createdAt = auth.profile?.createdAt;
    final accountAge = createdAt != null ? DateTime.now().difference(createdAt).inDays : 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFa855f7).withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 3, height: 14, decoration: BoxDecoration(color: const Color(0xFFa855f7), borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              const Text('ИНФОРМАЦИЯ АККАУНТА',
                style: TextStyle(color: Color(0xFFa855f7), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2, fontFamily: 'monospace')),
            ],
          ),
          const SizedBox(height: 16),
          _infoRow(Icons.person, 'Имя', auth.displayName.isEmpty ? 'Хакер' : auth.displayName, const Color(0xFF00E5FF)),
          const SizedBox(height: 10),
          _infoRow(Icons.email, 'Email', (auth.user?.email ?? '').isEmpty ? '---' : auth.user!.email!, const Color(0xFF78909c)),
          const SizedBox(height: 10),
          _infoRow(Icons.calendar_today, 'В игре', '$accountAge дней', const Color(0xFFFFD700)),
          const SizedBox(height: 10),
          _infoRow(Icons.groups, 'Банда', auth.profile?.clanId != null ? 'В клане' : 'Нет', const Color(0xFFa855f7)),
          const SizedBox(height: 10),
          _infoRow(Icons.shield, 'Уровень', '${game.level} (${_rankTitle(game.level)})', _rankColor(game.level)),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFF1e2535), height: 1),
          const SizedBox(height: 14),
          // Total stats summary
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00ff41).withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF00ff41).withValues(alpha: 0.12)),
                  ),
                  child: Column(
                    children: [
                      Text(_formatNum(game.xp),
                        style: const TextStyle(color: Color(0xFF00ff41), fontSize: 18, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
                      Text('ВСЕГО XP', style: TextStyle(color: const Color(0xFF00ff41).withValues(alpha: 0.4), fontSize: 9, letterSpacing: 1, fontFamily: 'monospace')),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.12)),
                  ),
                  child: Column(
                    children: [
                      Text(_formatNum(game.credits),
                        style: const TextStyle(color: Color(0xFFFFD700), fontSize: 18, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
                      Text('КРЕДИТЫ', style: TextStyle(color: const Color(0xFFFFD700).withValues(alpha: 0.4), fontSize: 9, letterSpacing: 1, fontFamily: 'monospace')),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.12)),
                  ),
                  child: Column(
                    children: [
                      Text('+${game.passiveIncomePerTick}',
                        style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 18, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
                      Text('¢/30С', style: TextStyle(color: const Color(0xFF00E5FF).withValues(alpha: 0.4), fontSize: 9, letterSpacing: 1, fontFamily: 'monospace')),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, color: color.withValues(alpha: 0.5), size: 16),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: Color(0xFF4a5568), fontSize: 12, fontFamily: 'monospace')),
        const Spacer(),
        Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
      ],
    );
  }

  String _rankTitle(int level) {
    if (level >= 50) return 'Легенда';
    if (level >= 40) return 'Мастер';
    if (level >= 30) return 'Ветеран';
    if (level >= 20) return 'Оперативник';
    if (level >= 10) return 'Специалист';
    return 'Новичок';
  }

  Color _rankColor(int level) {
    if (level >= 50) return const Color(0xFFFFD700);
    if (level >= 40) return const Color(0xFF00F0FF);
    if (level >= 30) return const Color(0xFFa855f7);
    if (level >= 20) return const Color(0xFF00ff41);
    if (level >= 10) return const Color(0xFFff9800);
    return const Color(0xFF4a5568);
  }
}

// ── Data model ──────────────────────────────────────────────────────────────

class PlayerProfileData {
  final String id;
  final String handle;
  final String avatarUrl;
  final int level;
  final int currentXp;
  final int xpToNextLevel;
  final int totalAttacks;
  final int successfulAttacks;
  final int creditsEarned;
  final int networksDestroyed;
  final int ranking;
  final String clanTag;

  const PlayerProfileData({
    required this.id,
    required this.handle,
    this.avatarUrl = '',
    this.level = 1,
    this.currentXp = 0,
    this.xpToNextLevel = 1000,
    this.totalAttacks = 0,
    this.successfulAttacks = 0,
    this.creditsEarned = 0,
    this.networksDestroyed = 0,
    this.ranking = 0,
    this.clanTag = '',
  });
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

// ── Helpers ──────────────────────────────────────────────────────────────────

String _formatNum(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return n.toString();
}

