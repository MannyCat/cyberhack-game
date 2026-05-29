import 'dart:async';
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
    with TickerProviderStateMixin {
  late TabController _tabController;

  // Player sort columns for each tab
  final Map<int, String> _sortColumns = {
    0: 'successful_attacks',   // Лучшие хакеры
    1: 'credits_earned',       // Богачейшие
    2: 'total_damage',         // Разрушительные
  };

  String _currentSortColumn = 'successful_attacks';
  int _myRank = -1;

  Future<List<Map<String, dynamic>>>? _leaderboardFuture;
  Future<List<Map<String, dynamic>>>? _clanLeaderboardFuture;
  String? _lastSortColumn;

  void _refreshLeaderboard() {
    final game = context.read<GameProvider>();
    setState(() {
      _myRank = -1;
      _lastSortColumn = _currentSortColumn;
      _leaderboardFuture = game.getLeaderboard(
        limit: 50,
        offset: 0,
        sortColumn: _currentSortColumn,
      );
      _clanLeaderboardFuture = game.getClanLeaderboard(limit: 50);
    });
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshLeaderboard());
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (_tabController.index == 3) {
      // Clan tab — refresh clan leaderboard
      setState(() {
        _clanLeaderboardFuture = context.read<GameProvider>().getClanLeaderboard(limit: 50);
      });
    } else {
      // Player tab
      _currentSortColumn = _sortColumns[_tabController.index] ?? 'successful_attacks';
      _refreshLeaderboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('РЕЙТИНГ'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'ХАКЕРЫ'),
            Tab(text: 'БОГАТЫЕ'),
            Tab(text: 'РАЗРУШИТЕЛИ'),
            Tab(text: 'БАНДЫ'),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Обновить',
            onPressed: _refreshLeaderboard,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPlayerTab(0, auth, theme),
          _buildPlayerTab(1, auth, theme),
          _buildPlayerTab(2, auth, theme),
          _buildClanTab(theme),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Player Tab
  // ═══════════════════════════════════════════════════════════

  Widget _buildPlayerTab(int tabIndex, AuthProvider auth, ThemeData theme) {
    // Only rebuild FutureBuilder if the tab matches current index
    if (_tabController.index != tabIndex && _leaderboardFuture != null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder(
      future: _leaderboardFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildErrorState(theme, 'Не удалось загрузить рейтинг', _refreshLeaderboard);
        }

        final entries = snapshot.data ?? <Map<String, dynamic>>[];

        if (entries.isEmpty) {
          return _buildEmptyState(theme, Icons.leaderboard, 'Данных пока нет', 'Начните игру, чтобы занять место!');
        }

        _myRank = entries.indexWhere((e) => e['player_id'] == auth.userId);

        return Column(
          children: [
            Expanded(
              child: _buildPlayerList(entries, auth.userId, theme),
            ),
            if (_myRank >= 0 && _myRank < 50)
              _buildYourRankFooter(auth, theme),
          ],
        );
      },
    );
  }

  Widget _buildPlayerList(
    List<Map<String, dynamic>> entries,
    String? userId,
    ThemeData theme,
  ) {
    final topThree = entries.take(3).toList();
    final rest = entries.skip(3).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      children: [
        if (topThree.length >= 3) _buildPodium(topThree, userId, theme),
        if (topThree.length >= 3) const SizedBox(height: 16),
        ...rest.asMap().entries.map((entry) {
          final index = entry.key + 3;
          final data = entry.value;
          return _buildAnimatedEntry(data, index, userId, theme);
        }),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildPodium(
    List<Map<String, dynamic>> topThree,
    String? userId,
    ThemeData theme,
  ) {
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
    final username = profiles?['username'] as String? ?? 'Неизвестно';
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
            'УР $level',
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
    final username = profiles?['username'] as String? ?? 'Неизвестно';
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
                    'ВЫ',
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
            'Ур.$level · ${_formatStatValue(statValue)}',
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

  // ═══════════════════════════════════════════════════════════
  // Clan Tab
  // ═══════════════════════════════════════════════════════════

  Widget _buildClanTab(ThemeData theme) {
    return FutureBuilder(
      future: _clanLeaderboardFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildErrorState(theme, 'Не удалось загрузить банды', _refreshLeaderboard);
        }

        final clans = snapshot.data ?? <Map<String, dynamic>>[];

        if (clans.isEmpty) {
          return _buildEmptyState(theme, Icons.groups, 'Банд пока нет', 'Создайте первую банду!');
        }

        return RefreshIndicator(
          color: theme.colorScheme.primary,
          onRefresh: () {
            setState(() {
              _clanLeaderboardFuture = context.read<GameProvider>().getClanLeaderboard(limit: 50);
            });
            return _clanLeaderboardFuture!;
          },
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            itemCount: clans.length,
            itemBuilder: (context, index) {
              final clan = clans[index];
              return _buildClanEntry(clan, index, theme);
            },
          ),
        );
      },
    );
  }

  Widget _buildClanEntry(Map<String, dynamic> clan, int index, ThemeData theme) {
    final name = clan['name'] as String? ?? 'Безымянная';
    final tag = clan['tag'] as String? ?? '???';
    final description = clan['description'] as String? ?? '';
    final memberCount = clan['member_count'] as int? ?? 0;
    final leaderName = clan['leader_username'] as String? ?? 'Неизвестен';
    final isTop = index < 3;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 30).clamp(0, 500)),
      curve: Curves.easeOut,
      builder: (context, anim, child) {
        return Opacity(
          opacity: anim,
          child: Transform.translate(
            offset: Offset(0, (1.0 - anim) * 15),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
          border: Border.all(
            color: isTop
                ? theme.colorScheme.tertiary.withValues(alpha: 0.3)
                : theme.colorScheme.outline.withValues(alpha: 0.12),
            width: isTop ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          children: [
            // Rank badge
            Container(
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
            const SizedBox(width: 12),
            // Clan icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.tertiary.withValues(alpha: 0.25),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '[$tag]',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.tertiary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  fontSize: 10,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (description.isNotEmpty)
                    Text(
                      description,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.person, size: 12, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 3),
                      Text(
                        '$memberCount уч.',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(Icons.star, size: 12, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 3),
                      Text(
                        leaderName,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 10,
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
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Shared Components
  // ═══════════════════════════════════════════════════════════

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
                'ВАШ РАНГ',
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
              '#${(_myRank + 1)}',
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

  Widget _buildErrorState(ThemeData theme, String message, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(message, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('ПОВТОРИТЬ')),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: theme.colorScheme.outline.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.outline)),
            const SizedBox(height: 8),
            Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline.withValues(alpha: 0.7))),
          ],
        ),
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
