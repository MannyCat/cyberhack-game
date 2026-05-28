import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/cyber_button.dart';

// ── Data models ────────────────────────────────────────────────

class Achievement {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final bool unlocked;
  final DateTime? unlockedAt;

  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    this.unlocked = false,
    this.unlockedAt,
  });
}

class ActivityEntry {
  final String id;
  final String type; // 'attack', 'defense', 'purchase', 'clan', 'level_up'
  final String description;
  final DateTime timestamp;
  final IconData icon;
  final Color color;

  const ActivityEntry({
    required this.id,
    required this.type,
    required this.description,
    required this.timestamp,
    required this.icon,
    required this.color,
  });
}

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

// ── Screen ─────────────────────────────────────────────────────

class ProfileScreen extends StatefulWidget {
  final PlayerProfileData profile;

  const ProfileScreen({super.key, required this.profile});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  late AnimationController _xpController;
  late Animation<double> _xpAnim;

  final List<Achievement> _achievements = [];
  final List<ActivityEntry> _activity = [];

  @override
  void initState() {
    super.initState();
    _xpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _xpAnim = Tween<double>(begin: 0, end: widget.profile.xpToNextLevel > 0
        ? widget.profile.currentXp / widget.profile.xpToNextLevel
        : 0.0).animate(CurvedAnimation(
      parent: _xpController,
      curve: Curves.easeOutCubic,
    ));
    _xpController.forward();
    _loadMockData();
  }

  @override
  void dispose() {
    _xpController.dispose();
    super.dispose();
  }

  void _loadMockData() {
    _achievements.addAll([
      Achievement(id: 'a1', name: 'Первая кровь', description: 'Выполните первую атаку', icon: Icons.bloodtype, unlocked: true, unlockedAt: DateTime(2025, 1, 15)),
      Achievement(id: 'a2', name: 'Протокол Призрак', description: 'Выиграйте 10 атак, оставшись необнаруженным', icon: Icons.visibility_off, unlocked: true, unlockedAt: DateTime(2025, 2, 20)),
      Achievement(id: 'a3', name: 'Миллионер', description: 'Заработайте 1 000 000 кредитов', icon: Icons.diamond, unlocked: true, unlockedAt: DateTime(2025, 3, 10)),
      Achievement(id: 'a4', name: 'Уничтожитель сетей', description: 'Уничтожьте 50 сетей', icon: Icons.power, unlocked: true, unlockedAt: DateTime(2025, 4, 5)),
      Achievement(id: 'a5', name: 'Лидер клана', description: 'Создайте или возглавьте клан', icon: Icons.emoji_events, unlocked: true, unlockedAt: DateTime(2025, 5, 1)),
      Achievement(id: 'a6', name: 'Неприкасаемый', description: 'Успешно защититесь от 100 атак', icon: Icons.shield, unlocked: false),
      Achievement(id: 'a7', name: 'Даркнет', description: 'Достигните 50 уровня', icon: Icons.dangerous, unlocked: false),
      Achievement(id: 'a8', name: 'Криптокороль', description: 'Заработайте 10 000 000 кредитов', icon: Icons.currency_bitcoin, unlocked: false),
    ]);

    _activity.addAll([
      ActivityEntry(id: 'e1', type: 'attack', description: 'Успешно взломан файрвол Corp_Net_42', timestamp: DateTime.now().subtract(const Duration(minutes: 15)), icon: Icons.bug_report, color: const Color(0xFF00FF41)),
      ActivityEntry(id: 'e2', type: 'purchase', description: 'Куплен улучшенный модуль файрвола', timestamp: DateTime.now().subtract(const Duration(hours: 2)), icon: Icons.shopping_cart, color: const Color(0xFFFFD700)),
      ActivityEntry(id: 'e3', type: 'defense', description: 'Отражена атака от n30ngh0st', timestamp: DateTime.now().subtract(const Duration(hours: 5)), icon: Icons.shield, color: const Color(0xFF00E5FF)),
      ActivityEntry(id: 'e4', type: 'clan', description: 'Присоединился к Shadow Collective', timestamp: DateTime.now().subtract(const Duration(days: 1)), icon: Icons.group_add, color: const Color(0xFF00E5FF)),
      ActivityEntry(id: 'e5', type: 'level_up', description: 'Достигнут 24 уровень', timestamp: DateTime.now().subtract(const Duration(days: 2)), icon: Icons.arrow_upward, color: const Color(0xFFFF0040)),
      ActivityEntry(id: 'e6', type: 'attack', description: 'Неудачное вторжение на FortKnox_Server', timestamp: DateTime.now().subtract(const Duration(days: 3)), icon: Icons.bug_report, color: const Color(0xFFFF0040)),
      ActivityEntry(id: 'e7', type: 'purchase', description: 'ЦПУ улучшен до 4 уровня', timestamp: DateTime.now().subtract(const Duration(days: 4)), icon: Icons.memory, color: const Color(0xFFFFD700)),
    ]);
  }

  // ── Build ───────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17),
      body: CustomScrollView(
        slivers: [
          // ── App bar with avatar ──────────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: const Color(0xFF0A0E17),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back,
                  color: Color(0xFF00FF41)),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF0F1320), Color(0xFF0A0E17)],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      // Avatar
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: const Color(0xFF00FF41), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00FF41).withOpacity(0.2),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 44,
                          backgroundColor: const Color(0xFF1A1F2E),
                          child: Text(
                            widget.profile.handle.length >= 2
                                ? widget.profile.handle.substring(0, 2).toUpperCase()
                                : widget.profile.handle.toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFF00FF41),
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Handle
                      Text(
                        widget.profile.handle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                      if (widget.profile.clanTag.isNotEmpty)
                        Text(
                          '[${widget.profile.clanTag}]',
                          style: const TextStyle(
                            color: Color(0xFF00E5FF),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Level & XP ───────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _buildLevelSection(),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ── Stats grid ───────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildStatsGrid(),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // ── Achievements ─────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildAchievements(),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // ── Activity history ────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildActivity(),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // ── Edit profile button ──────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              child: CyberButton(
                label: 'РЕДАКТИРОВАТЬ',
                variant: CyberButtonVariant.secondary,
                icon: Icons.edit,
                width: double.infinity,
                onPressed: _onEditProfile,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Level & XP ──────────────────────────────────────────────
  Widget _buildLevelSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2A2F45)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.stars, color: Color(0xFFFFD700), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'УРОВЕНЬ ${widget.profile.level}',
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              Text(
                'Рейтинг #${widget.profile.ranking}',
                style: const TextStyle(
                  color: Color(0xFF00FF41),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: ListenableBuilder(
              listenable: _xpAnim,
              builder: (context, _) => LinearProgressIndicator(
                value: _xpAnim.value,
                minHeight: 10,
                backgroundColor: const Color(0xFF12162A),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00FF41)),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${widget.profile.currentXp} XP',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.5), fontSize: 11),
              ),
              Text(
                '${widget.profile.xpToNextLevel} XP',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.3), fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Stats grid ──────────────────────────────────────────────
  Widget _buildStatsGrid() {
    final stats = [
      _StatItem(
          label: 'Всего атак',
          value: '${widget.profile.totalAttacks}',
          icon: Icons.bug_report,
          color: const Color(0xFF00FF41)),
      _StatItem(
          label: 'Успешных',
          value: '${widget.profile.successfulAttacks}',
          icon: Icons.check_circle,
          color: const Color(0xFF00E5FF)),
      _StatItem(
          label: 'Заработано кредитов',
          value: _formatNum(widget.profile.creditsEarned),
          icon: Icons.monetization_on,
          color: const Color(0xFFFFD700)),
      _StatItem(
          label: 'Сетей уничтожено',
          value: '${widget.profile.networksDestroyed}',
          icon: Icons.power_off,
          color: const Color(0xFFFF0040)),
      _StatItem(
          label: 'Текущий рейтинг',
          value: '#${widget.profile.ranking}',
          icon: Icons.leaderboard,
          color: const Color(0xFF00FF41)),
      _StatItem(
          label: '% побед',
          value: widget.profile.totalAttacks > 0
              ? '${((widget.profile.successfulAttacks / widget.profile.totalAttacks) * 100).toStringAsFixed(1)}%'
              : '0%',
          icon: Icons.trending_up,
          color: const Color(0xFF00E5FF)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'СТАТИСТИКА',
          style: TextStyle(
            color: Color(0xFF00E5FF),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.8,
          children: stats.map((s) => _buildStatCard(s)).toList(),
        ),
      ],
    );
  }

  Widget _buildStatCard(_StatItem stat) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: stat.color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(stat.icon, color: stat.color, size: 20),
          const SizedBox(height: 6),
          Text(
            stat.value,
            style: TextStyle(
              color: stat.color,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              letterSpacing: 0.5,
            ),
          ),
          Text(
            stat.label,
            style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 10,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ── Achievements ────────────────────────────────────────────
  Widget _buildAchievements() {
    final unlocked = _achievements.where((a) => a.unlocked).toList();
    final locked = _achievements.where((a) => !a.unlocked).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ДОСТИЖЕНИЯ',
          style: TextStyle(
            color: Color(0xFF00E5FF),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
        Text(
          '${unlocked.length}/${_achievements.length} разблокировано',
          style: TextStyle(
              color: Colors.white.withOpacity(0.3), fontSize: 11),
        ),
        const SizedBox(height: 8),
        // Unlocked badges
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: unlocked
              .map((a) => _achievementBadge(a, unlocked: true))
              .toList(),
        ),
        if (locked.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            'ЗАБЛОКИРОВАНО',
            style: TextStyle(
              color: Colors.white24,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: locked
                .map((a) => _achievementBadge(a, unlocked: false))
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _achievementBadge(Achievement a, {required bool unlocked}) {
    return Tooltip(
      message: '${a.name}: ${a.description}',
      child: GestureDetector(
        onTap: () => _showAchievementDetail(a),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: unlocked
                ? const Color(0xFF1A1F2E)
                : const Color(0xFF12162A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: unlocked
                  ? const Color(0xFFFFD700).withOpacity(0.4)
                  : const Color(0xFF1E2340),
            ),
            boxShadow: unlocked
                ? [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withOpacity(0.15),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            a.icon,
            color: unlocked
                ? const Color(0xFFFFD700)
                : Colors.white24,
            size: 24,
          ),
        ),
      ),
    );
  }

  void _showAchievementDetail(Achievement a) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1F2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(a.icon,
                color: a.unlocked
                    ? const Color(0xFFFFD700)
                    : Colors.white24,
                size: 40),
            const SizedBox(height: 12),
            Text(
              a.name,
              style: TextStyle(
                color: a.unlocked
                    ? const Color(0xFFFFD700)
                    : Colors.white54,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              a.description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            if (a.unlocked && a.unlockedAt != null) ...[
              const SizedBox(height: 10),
              Text(
                'Разблокировано ${_formatDate(a.unlockedAt!)}',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.3), fontSize: 11),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ── Activity history ────────────────────────────────────────
  Widget _buildActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ПОСЛЕДНЯЯ АКТИВНОСТЬ',
          style: TextStyle(
            color: Color(0xFF00E5FF),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F2E),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF2A2F45)),
          ),
          child: Column(
            children: _activity.map((e) {
              final isLast = e == _activity.last;
              return Column(
                children: [
                  _activityTile(e),
                  if (!isLast)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      child: Divider(
                          color: Color(0xFF1E2340), height: 1),
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _activityTile(ActivityEntry entry) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: entry.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(entry.icon, color: entry.color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.description,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _timeAgo(entry.timestamp),
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.3), fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────
  String _formatNum(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  String _formatDate(DateTime d) =>
      '${d.day}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 60) return '${diff.inMinutes}м назад';
    if (diff.inHours < 24) return '${diff.inHours}ч назад';
    if (diff.inDays < 7) return '${diff.inDays}д назад';
    return _formatDate(t);
  }

  void _onEditProfile() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Редактирование профиля скоро будет доступно...'),
        backgroundColor: Color(0xFF00E5FF),
      ),
    );
  }
}

// ── Stat helper ────────────────────────────────────────────────

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
