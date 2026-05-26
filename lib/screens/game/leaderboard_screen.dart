import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../providers/auth_provider.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Sort column maps to each tab
  final Map<int, String> _sortColumns = {
    0: 'successful_attacks',   // Top Hackers
    1: 'clan_score',           // Top Crews
    2: 'credits_earned',       // Richest
    3: 'total_damage',         // Most Destructive
  };

  String _currentSortColumn = 'successful_attacks';
  int _myRank = -1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    setState(() {
      _currentSortColumn = _sortColumns[_tabController.index] ?? 'successful_attacks';
      _myRank = -1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('LEADERBOARD'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'TOP HACKERS'),
            Tab(text: 'TOP CREWS'),
            Tab(text: 'RICHEST'),
            Tab(text: 'MOST DESTRUCTIVE'),
          ],
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            fontSize: 11,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.normal,
            letterSpacing: 0.5,
            fontSize: 11,
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      ),
      body: Column(
        children: [
          // ── Leaderboard List ──
          Expanded(
            child: FutureBuilder(
              future: context
                  .read<GameProvider>()
                  .getLeaderboard(limit: 50, offset: 0),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline,
                            size: 48, color: theme.colorScheme.error),
                        const SizedBox(height: 12),
                        Text('Failed to load leaderboard',
                            style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  );
                }

                final entries = snapshot.data ?? <Map<String, dynamic>>[];

                if (entries.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.leaderboard,
                            size: 64,
                            color: theme.colorScheme.outline.withValues(alpha: 0.4)),
                        const SizedBox(height: 16),
                        Text('No leaderboard data yet',
                            style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.outline)),
                        const SizedBox(height: 8),
                        Text('Start hacking to claim your spot!',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline.withValues(alpha: 0.7))),
                      ],
                    ),
                  );
                }

                // Find current user's rank
                _myRank = entries.indexWhere(
                    (e) => e['player_id'] == auth.userId);

                return _buildLeaderboardList(entries, auth.userId, theme);
              },
            ),
          ),

          // ── Your Rank Sticky Footer ──
          if (_myRank >= 0 && _myRank < 50) _buildYourRankFooter(auth, theme),
        ],
      ),
    );
  }

  Widget _buildLeaderboardList(
    List<Map<String, dynamic>> entries,
    String? userId,
    ThemeData theme,
  ) {
    // Top 3 podium at top, rest as normal list
    final topThree = entries.take(3).toList();
    final rest = entries.skip(3).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      children: [
        // ── Top 3 Podium ──
        if (topThree.length >= 3) _buildPodium(topThree, userId, theme),
        if (topThree.length >= 3) const SizedBox(height: 16),

        // ── Rest of the list ──
        ...rest.asMap().entries.map((entry) {
          final index = entry.key + 3; // Offset for top 3
          final data = entry.value;
          return _buildAnimatedEntry(data, index, userId, theme);
        }),
        const SizedBox(height: 80), // Space for sticky footer
      ],
    );
  }

  Widget _buildPodium(
    List<Map<String, dynamic>> topThree,
    String? userId,
    ThemeData theme,
  ) {
    // Order: [1st center, 2nd left, 3rd right]
    final second = topThree[1];
    final first = topThree[0];
    final third = topThree[2];

    return SizedBox(
      height: 200,
      child: Stack(
        children: [
          // 2nd place — left
          Positioned(
            left: 8,
            bottom: 0,
            child: _buildPodiumCard(
              data: second,
              rank: 2,
              userId: userId,
              theme: theme,
              width: MediaQuery.of(context).size.width * 0.3 - 16,
              color: const Color(0xFFC0C0C0),
              glowColor: const Color(0xFFC0C0C0).withValues(alpha: 0.3),
              height: 120,
            ),
          ),
          // 1st place — center
          Positioned(
            left: MediaQuery.of(context).size.width * 0.35,
            bottom: 0,
            child: _buildPodiumCard(
              data: first,
              rank: 1,
              userId: userId,
              theme: theme,
              width: MediaQuery.of(context).size.width * 0.3,
              color: const Color(0xFFFFD700),
              glowColor: const Color(0xFFFFD700).withValues(alpha: 0.4),
              height: 150,
            ),
          ),
          // 3rd place — right
          Positioned(
            right: 8,
            bottom: 0,
            child: _buildPodiumCard(
              data: third,
              rank: 3,
              userId: userId,
              theme: theme,
              width: MediaQuery.of(context).size.width * 0.3 - 16,
              color: const Color(0xFFCD7F32),
              glowColor: const Color(0xFFCD7F32).withValues(alpha: 0.3),
              height: 100,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumCard({
    required Map<String, dynamic> data,
    required int rank,
    required String? userId,
    required ThemeData theme,
    required double width,
    required Color color,
    required Color glowColor,
    required double height,
  }) {
    final profiles = data['profiles'] as Map?;
    final username = profiles?['username'] as String? ?? 'Unknown';
    final level = profiles?['level'] as int? ?? 1;
    final isMe = data['player_id'] == userId;
    final statValue = _getStatValue(data);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.15),
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border.all(
          color: isMe ? theme.colorScheme.primary : color.withValues(alpha: 0.5),
          width: isMe ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(color: isMe ? theme.colorScheme.primary.withValues(alpha: 0.3) : glowColor, blurRadius: 16),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Rank badge
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
              boxShadow: [BoxShadow(color: glowColor, blurRadius: 8)],
            ),
            alignment: Alignment.center,
            child: Text(
              '$rank',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Avatar
          CircleAvatar(
            radius: rank == 1 ? 22 : 18,
            backgroundColor: color.withValues(alpha: 0.3),
            child: Text(
              username.isNotEmpty ? username[0].toUpperCase() : '?',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: rank == 1 ? 18 : 15,
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Username
          Text(
            username,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isMe ? theme.colorScheme.primary : theme.colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            'LVL $level',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _formatStatValue(statValue),
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedEntry(
    Map<String, dynamic> data,
    int index,
    String? userId,
    ThemeData theme,
  ) {
    final profiles = data['profiles'] as Map?;
    final username = profiles?['username'] as String? ?? 'Unknown';
    final level = profiles?['level'] as int? ?? 1;
    final isMe = data['player_id'] == userId;
    final statValue = _getStatValue(data);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 40).clamp(0, 600)),
      curve: Curves.easeOut,
      builder: (context, anim, child) {
        return Opacity(
          opacity: anim,
          child: Transform.translate(
            offset: Offset(0, (1.0 - anim) * 20),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isMe
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.2)
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.08),
          border: Border.all(
            color: isMe
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.12),
            width: isMe ? 1.5 : 0.5,
          ),
          boxShadow: isMe
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    blurRadius: 12,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: _rankColor(index).withValues(alpha: 0.15),
              border: Border.all(
                color: _rankColor(index).withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _rankColor(index),
                fontSize: 14,
              ),
            ),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  username,
                  style: TextStyle(
                    fontWeight: isMe ? FontWeight.bold : FontWeight.w600,
                    color: isMe ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isMe) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'YOU',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Text(
            'Lv.$level • ${_formatStatValue(statValue)}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.trending_up, size: 14, color: _rankColor(index).withValues(alpha: 0.6)),
              const SizedBox(width: 4),
              Text(
                _formatStatValue(statValue),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: _rankColor(index),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildYourRankFooter(AuthProvider auth, ThemeData theme) {
    if (_myRank < 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
        border: Border.all(
          color: theme.colorScheme.primary,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.2),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: theme.colorScheme.primary.withValues(alpha: 0.2),
              border: Border.all(color: theme.colorScheme.primary),
            ),
            alignment: Alignment.center,
            child: Text(
              '#${_myRank + 1}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'YOUR RANK',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary.withValues(alpha: 0.8),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  fontSize: 10,
                ),
              ),
              Text(
                auth.displayName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'TOP ${(_myRank + 1)}%',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _rankColor(int index) {
    return switch (index) {
      0 => const Color(0xFFFFD700),
      1 => const Color(0xFFC0C0C0),
      2 => const Color(0xFFCD7F32),
      _ => Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
    };
  }

  int _getStatValue(Map<String, dynamic> entry) {
    return switch (_currentSortColumn) {
      'successful_attacks' => (entry['successful_attacks'] as num?)?.toInt() ?? 0,
      'clan_score' => (entry['clan_score'] as num?)?.toInt() ?? 0,
      'credits_earned' => (entry['credits_earned'] as num?)?.toInt() ?? 0,
      'total_damage' => (entry['total_damage'] as num?)?.toInt() ?? 0,
      _ => (entry['successful_attacks'] as num?)?.toInt() ?? 0,
    };
  }

  String _formatStatValue(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return '$value';
  }
}
