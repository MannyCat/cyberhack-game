import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../providers/auth_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// LeaderboardScreen — PC Desktop
// ═══════════════════════════════════════════════════════════════════════════════
// Wide layout inside game_shell (sidebar + resource bar already present).
// • Category toggle (Хакеры / Богатые / Разрушители / Банды) as header buttons
// • Top 3 players highlighted in special podium cards
// • Table-like layout for remaining entries with columns:
//   Rank, Player, Level, Credits, Clan, Status
// • MouseRegion hover on all rows
// • "Your rank" footer bar
// • Clan tab with clan table layout
// • Dark cyberpunk on Color(0xFF0a0e17), all Russian text
// • All game logic, Provider usage, sort/filter preserved
// ═══════════════════════════════════════════════════════════════════════════════

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  // ── Sort columns for each category ──
  final Map<int, String> _sortColumns = {
    0: 'successful_attacks',   // Лучшие хакеры
    1: 'credits_earned',       // Богатейшие
    2: 'total_damage',         // Разрушительные
  };

  String _currentSortColumn = 'successful_attacks';
  int _activeTabIndex = 0; // 0=Хакеры, 1=Богатые, 2=Разрушители, 3=Банды
  int _myRank = -1;

  Future<List<Map<String, dynamic>>>? _leaderboardFuture;
  Future<List<Map<String, dynamic>>>? _clanLeaderboardFuture;
  String? _lastSortColumn;

  // ── Category config ──
  static const List<_LeaderboardTab> _tabs = [
    _LeaderboardTab(label: 'ХАКЕРЫ', icon: Icons.hack_rounded, color: Color(0xFF39FF14)),
    _LeaderboardTab(label: 'БОГАТЫЕ', icon: Icons.monetization_on_rounded, color: Color(0xFFFFD700)),
    _LeaderboardTab(label: 'РАЗРУШИТЕЛИ', icon: Icons.bug_report_rounded, color: Color(0xFFFF0040)),
    _LeaderboardTab(label: 'БАНДЫ', icon: Icons.groups_rounded, color: Color(0xFFa855f7)),
  ];

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

  void _onTabChanged(int index) {
    if (index == _activeTabIndex) return;
    setState(() => _activeTabIndex = index);

    if (index == 3) {
      // Clan tab — refresh clan leaderboard
      setState(() {
        _clanLeaderboardFuture = context.read<GameProvider>().getClanLeaderboard(limit: 50);
      });
    } else {
      // Player tab
      _currentSortColumn = _sortColumns[index] ?? 'successful_attacks';
      _refreshLeaderboard();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshLeaderboard());
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: title + tab toggles + refresh ──
          _buildHeader(),
          const SizedBox(height: 20),

          // ── Content ──
          Expanded(
            child: _activeTabIndex == 3
                ? _buildClanContent(auth)
                : _buildPlayerContent(auth),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // Header
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _buildHeader() {
    return Row(
      children: [
        // ── Title ──
        const Text(
          'РЕЙТИНГ',
          style: TextStyle(
            color: Color(0xFFe91e63),
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 3,
            fontFamily: 'monospace',
            shadows: [Shadow(color: Color(0x80e91e63), blurRadius: 12)],
          ),
        ),

        const SizedBox(width: 20),

        // ── Tab toggle buttons ──
        ...List.generate(_tabs.length, (index) {
          if (index > 0) const SizedBox(width: 8);
          return Padding(
            padding: const EdgeInsets.only(right: index < _tabs.length - 1 ? 8 : 0),
            child: _TabToggle(
              tab: _tabs[index],
              isSelected: _activeTabIndex == index,
              onTap: () => _onTabChanged(index),
            ),
          );
        }),

        const Spacer(),

        // ── Refresh button ──
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: _refreshLeaderboard,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF00F0FF).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF00F0FF).withValues(alpha: 0.25)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh_rounded, color: Color(0xFF00F0FF), size: 16),
                  SizedBox(width: 6),
                  Text(
                    'ОБНОВИТЬ',
                    style: TextStyle(
                      color: Color(0xFF00F0FF),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // Player content
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _buildPlayerContent(AuthProvider auth) {
    return FutureBuilder(
      future: _leaderboardFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFe91e63)),
          );
        }

        if (snapshot.hasError) {
          return _buildErrorState('Не удалось загрузить рейтинг', _refreshLeaderboard);
        }

        final entries = snapshot.data ?? <Map<String, dynamic>>[];

        if (entries.isEmpty) {
          return _buildEmptyState(
            Icons.leaderboard_rounded,
            'Данных пока нет',
            'Начните игру, чтобы занять место!',
          );
        }

        _myRank = entries.indexWhere((e) => e['player_id'] == auth.userId);

        return Column(
          children: [
            // ── Top 3 podium ──
            if (entries.length >= 3) _buildPodium(entries.take(3).toList(), auth.userId),
            if (entries.length >= 3) const SizedBox(height: 20),

            // ── Table header ──
            if (entries.length > 3) _buildTableHeader(),

            // ── Table rows ──
            if (entries.length > 3)
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: entries.length - 3,
                  itemBuilder: (context, index) {
                    final data = entries[index + 3];
                    return _LeaderboardRow(
                      data: data,
                      rank: index + 4,
                      userId: auth.userId,
                      sortColumn: _currentSortColumn,
                    );
                  },
                ),
              ),

            // ── Your rank footer ──
            if (_myRank >= 0 && _myRank < 50)
              _buildYourRankFooter(auth),
          ],
        );
      },
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // Top 3 podium
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _buildPodium(List<Map<String, dynamic>> topThree, String? userId) {
    // Order: 2nd | 1st | 3rd
    final first = topThree[0];
    final second = topThree[1];
    final third = topThree[2];

    return Row(
      children: [
        Expanded(child: _PodiumCard(data: first, rank: 1, userId: userId)),
        const SizedBox(width: 12),
        Expanded(child: _PodiumCard(data: second, rank: 2, userId: userId)),
        const SizedBox(width: 12),
        Expanded(child: _PodiumCard(data: third, rank: 3, userId: userId)),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // Table header
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF0d1220),
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
        border: Border(
          bottom: BorderSide(color: Color(0xFF1a2030), width: 1),
        ),
      ),
      child: const Row(
        children: [
          SizedBox(width: 60, child: Text('РАНГ', style: _tableHeaderStyle)),
          SizedBox(width: 20),
          Expanded(flex: 3, child: Text('ИГРОК', style: _tableHeaderStyle)),
          SizedBox(width: 20),
          SizedBox(width: 70, child: Text('УРОВЕНЬ', style: _tableHeaderStyle)),
          SizedBox(width: 20),
          SizedBox(width: 120, child: Text('КРЕДИТЫ', style: _tableHeaderStyle, textAlign: TextAlign.right)),
          SizedBox(width: 20),
          Expanded(flex: 2, child: Text('БАНДА', style: _tableHeaderStyle)),
          SizedBox(width: 20),
          SizedBox(width: 100, child: Text('СТАТУС', style: _tableHeaderStyle, textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // Your rank footer
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _buildYourRankFooter(AuthProvider auth) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF00F0FF).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF00F0FF).withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00F0FF).withValues(alpha: 0.1),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFF00F0FF).withValues(alpha: 0.12),
              border: Border.all(color: const Color(0xFF00F0FF).withValues(alpha: 0.4)),
            ),
            alignment: Alignment.center,
            child: Text(
              '#${_myRank + 1}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF00F0FF),
                fontSize: 16,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ВАШ РАНГ',
                style: TextStyle(
                  color: Color(0xFF00F0FF),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  fontSize: 9,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                auth.displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFe0e6ed),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF00F0FF).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '#${_myRank + 1} из 50',
              style: const TextStyle(
                color: Color(0xFF00F0FF),
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // Clan content
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _buildClanContent(AuthProvider auth) {
    return FutureBuilder(
      future: _clanLeaderboardFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFa855f7)),
          );
        }

        if (snapshot.hasError) {
          return _buildErrorState('Не удалось загрузить банды', _refreshLeaderboard);
        }

        final clans = snapshot.data ?? <Map<String, dynamic>>[];

        if (clans.isEmpty) {
          return _buildEmptyState(
            Icons.groups_rounded,
            'Банд пока нет',
            'Создайте первую банду!',
          );
        }

        return Column(
          children: [
            // ── Clan table header ──
            _buildClanTableHeader(),
            const SizedBox(height: 2),
            // ── Clan rows ──
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: clans.length,
                itemBuilder: (context, index) {
                  return _ClanRow(
                    data: clans[index],
                    rank: index + 1,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildClanTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF0d1220),
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
        border: Border(
          bottom: BorderSide(color: Color(0xFF1a2030), width: 1),
        ),
      ),
      child: const Row(
        children: [
          SizedBox(width: 60, child: Text('РАНГ', style: _tableHeaderStyle)),
          SizedBox(width: 20),
          SizedBox(width: 70, child: Text('ТЕГ', style: _tableHeaderStyle)),
          SizedBox(width: 20),
          Expanded(flex: 3, child: Text('БАНДА', style: _tableHeaderStyle)),
          SizedBox(width: 20),
          SizedBox(width: 100, child: Text('УЧАСТНИКИ', style: _tableHeaderStyle, textAlign: TextAlign.right)),
          SizedBox(width: 20),
          Expanded(flex: 2, child: Text('ЛИДЕР', style: _tableHeaderStyle)),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // Shared states
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _buildErrorState(String message, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 56, color: Color(0xFFFF0040)),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: Color(0xFFe0e6ed), fontSize: 15)),
          const SizedBox(height: 16),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onRetry,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF0040).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFF0040).withValues(alpha: 0.3)),
                ),
                child: const Text(
                  'ПОВТОРИТЬ',
                  style: TextStyle(
                    color: Color(0xFFFF0040),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: const Color(0xFF3a4555)),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF6a7080),
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF3a4555), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Table header text style (as static const for reuse)
// ═══════════════════════════════════════════════════════════════════════════════

const _tableHeaderStyle = TextStyle(
  color: Color(0xFF5a6578),
  fontSize: 11,
  fontWeight: FontWeight.bold,
  letterSpacing: 1.5,
  fontFamily: 'monospace',
);

// ═══════════════════════════════════════════════════════════════════════════════
// Tab toggle config
// ═══════════════════════════════════════════════════════════════════════════════

class _LeaderboardTab {
  final String label;
  final IconData icon;
  final Color color;
  const _LeaderboardTab({required this.label, required this.icon, required this.color});
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tab toggle button (replaces TabBar)
// ═══════════════════════════════════════════════════════════════════════════════

class _TabToggle extends StatefulWidget {
  final _LeaderboardTab tab;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabToggle({
    required this.tab,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_TabToggle> createState() => _TabToggleState();
}

class _TabToggleState extends State<_TabToggle> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? widget.tab.color.withValues(alpha: 0.12)
                : (_isHovered
                    ? widget.tab.color.withValues(alpha: 0.05)
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isSelected
                  ? widget.tab.color.withValues(alpha: 0.4)
                  : widget.tab.color.withValues(alpha: (_isHovered ? 0.2 : 0.08)),
            ),
            boxShadow: widget.isSelected
                ? [BoxShadow(color: widget.tab.color.withValues(alpha: 0.2), blurRadius: 12)]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.tab.icon,
                size: 16,
                color: widget.isSelected ? widget.tab.color : const Color(0xFF5a6578),
              ),
              const SizedBox(width: 8),
              Text(
                widget.tab.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  fontFamily: 'monospace',
                  color: widget.isSelected ? widget.tab.color : const Color(0xFF6a7080),
                  shadows: widget.isSelected
                      ? [Shadow(color: widget.tab.color.withValues(alpha: 0.5), blurRadius: 8)]
                      : [],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Top 3 podium card
// ═══════════════════════════════════════════════════════════════════════════════

class _PodiumCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final int rank;
  final String? userId;

  const _PodiumCard({
    required this.data,
    required this.rank,
    required this.userId,
  });

  @override
  State<_PodiumCard> createState() => _PodiumCardState();
}

class _PodiumCardState extends State<_PodiumCard> {
  bool _isHovered = false;

  Color get _medalColor {
    return switch (widget.rank) {
      1 => const Color(0xFFFFD700),
      2 => const Color(0xFFC0C0C0),
      3 => const Color(0xFFCD7F32),
      _ => const Color(0xFF5a6578),
    };
  }

  @override
  Widget build(BuildContext context) {
    final profiles = widget.data['profiles'] as Map?;
    final username = profiles?['username'] as String? ?? 'Неизвестно';
    final level = profiles?['level'] as int? ?? 1;
    final credits = (widget.data['credits_earned'] as num?)?.toInt() ?? 0;
    final isMe = widget.data['player_id'] == widget.userId;
    final color = _medalColor;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: _isHovered ? 0.18 : 0.1),
              const Color(0xFF0d1220),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isMe
                ? const Color(0xFF00F0FF).withValues(alpha: 0.6)
                : color.withValues(alpha: _isHovered ? 0.6 : 0.35),
            width: isMe || _isHovered ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isMe
                  ? const Color(0xFF00F0FF).withValues(alpha: 0.2)
                  : color.withValues(alpha: _isHovered ? 0.3 : 0.15),
              blurRadius: _isHovered ? 20 : 12,
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Rank badge ──
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 10)],
              ),
              alignment: Alignment.center,
              child: Text(
                '${widget.rank}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 18,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Avatar ──
            CircleAvatar(
              radius: 24,
              backgroundColor: color.withValues(alpha: 0.2),
              child: Text(
                username.isNotEmpty ? username[0].toUpperCase() : '?',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ── Username ──
            Text(
              username,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isMe ? const Color(0xFF00F0FF) : const Color(0xFFe0e6ed),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            // ── "ВЫ" badge ──
            if (isMe) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF00F0FF).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF00F0FF).withValues(alpha: 0.3)),
                ),
                child: const Text(
                  'ВЫ',
                  style: TextStyle(
                    color: Color(0xFF00F0FF),
                    fontWeight: FontWeight.bold,
                    fontSize: 9,
                    letterSpacing: 1,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],

            const SizedBox(height: 8),

            // ── Level + Credits ──
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'УР $level',
                  style: const TextStyle(
                    color: Color(0xFF5a6578),
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.monetization_on_rounded, color: Color(0xFFFFD700), size: 12),
                    const SizedBox(width: 3),
                    Text(
                      _formatNumber(credits),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Leaderboard table row (Rank, Player, Level, Credits, Clan, Status)
// ═══════════════════════════════════════════════════════════════════════════════

class _LeaderboardRow extends StatefulWidget {
  final Map<String, dynamic> data;
  final int rank;
  final String? userId;
  final String sortColumn;

  const _LeaderboardRow({
    required this.data,
    required this.rank,
    required this.userId,
    required this.sortColumn,
  });

  @override
  State<_LeaderboardRow> createState() => _LeaderboardRowState();
}

class _LeaderboardRowState extends State<_LeaderboardRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final profiles = widget.data['profiles'] as Map?;
    final username = profiles?['username'] as String? ?? 'Неизвестно';
    final level = profiles?['level'] as int? ?? 1;
    final credits = (widget.data['credits_earned'] as num?)?.toInt() ?? 0;
    final clanName = (widget.data['clan_name'] as String?) ?? '—';
    final online = widget.data['online'] as bool? ?? false;
    final isMe = widget.data['player_id'] == widget.userId;
    final rankColor = _rankColor(widget.rank - 1);

    final bgColor = isMe
        ? const Color(0xFF00F0FF).withValues(alpha: 0.06)
        : (_isHovered
            ? const Color(0xFF111827)
            : Colors.transparent);

    final borderColor = isMe
        ? const Color(0xFF00F0FF).withValues(alpha: 0.3)
        : (_isHovered
            ? const Color(0xFF2a3a4a)
            : const Color(0xFF1a2030));

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 250 + ((widget.rank - 4) * 25).clamp(0, 500)),
      curve: Curves.easeOut,
      builder: (context, anim, child) {
        return Opacity(
          opacity: anim,
          child: Transform.translate(
            offset: Offset(0, (1.0 - anim) * 10),
            child: child,
          ),
        );
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Container(
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            border: Border.all(color: borderColor, width: 0.5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              // ── Rank ──
              SizedBox(
                width: 60,
                child: Container(
                  width: 36,
                  height: 28,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: rankColor.withValues(alpha: 0.12),
                    border: Border.all(color: rankColor.withValues(alpha: 0.35)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${widget.rank}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: rankColor,
                      fontSize: 13,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),

              // ── Player ──
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    // Avatar initial
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: (isMe
                            ? const Color(0xFF00F0FF)
                            : const Color(0xFF3a4555)).withValues(alpha: 0.2),
                        border: Border.all(
                          color: isMe
                              ? const Color(0xFF00F0FF).withValues(alpha: 0.4)
                              : const Color(0xFF3a4555).withValues(alpha: 0.3),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        username.isNotEmpty ? username[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: isMe ? const Color(0xFF00F0FF) : const Color(0xFF8a95a5),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        username,
                        style: TextStyle(
                          fontWeight: isMe ? FontWeight.bold : FontWeight.w600,
                          color: isMe ? const Color(0xFF00F0FF) : const Color(0xFFe0e6ed),
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00F0FF).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: const Color(0xFF00F0FF).withValues(alpha: 0.3)),
                        ),
                        child: const Text(
                          'ВЫ',
                          style: TextStyle(
                            color: Color(0xFF00F0FF),
                            fontWeight: FontWeight.bold,
                            fontSize: 8,
                            letterSpacing: 0.5,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 20),

              // ── Level ──
              SizedBox(
                width: 70,
                child: Text(
                  'УР $level',
                  style: const TextStyle(
                    color: Color(0xFF8a95a5),
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(width: 20),

              // ── Credits ──
              SizedBox(
                width: 120,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Icon(Icons.monetization_on_rounded, color: Color(0xFFFFD700), size: 13),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _formatNumber(credits),
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),

              // ── Clan ──
              Expanded(
                flex: 2,
                child: Text(
                  clanName,
                  style: TextStyle(
                    color: clanName == '—'
                        ? const Color(0xFF3a4555)
                        : const Color(0xFFa855f7),
                    fontSize: 12,
                    fontWeight: clanName == '—' ? FontWeight.normal : FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 20),

              // ── Status ──
              SizedBox(
                width: 100,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: online
                            ? const Color(0xFF39FF14)
                            : const Color(0xFF5a6578),
                        shape: BoxShape.circle,
                        boxShadow: online
                            ? [BoxShadow(color: const Color(0xFF39FF14).withValues(alpha: 0.5), blurRadius: 6)]
                            : [],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      online ? 'В СЕТИ' : 'ОФФЛАЙН',
                      style: TextStyle(
                        color: online ? const Color(0xFF39FF14) : const Color(0xFF5a6578),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Clan table row
// ═══════════════════════════════════════════════════════════════════════════════

class _ClanRow extends StatefulWidget {
  final Map<String, dynamic> data;
  final int rank;

  const _ClanRow({
    required this.data,
    required this.rank,
  });

  @override
  State<_ClanRow> createState() => _ClanRowState();
}

class _ClanRowState extends State<_ClanRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final name = widget.data['name'] as String? ?? 'Безымянная';
    final tag = widget.data['tag'] as String? ?? '???';
    final memberCount = widget.data['member_count'] as int? ?? 0;
    final leaderName = widget.data['leader_username'] as String? ?? 'Неизвестен';
    final description = widget.data['description'] as String? ?? '';
    final isTop = widget.rank <= 3;
    final rankColor = _rankColor(widget.rank - 1);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 250 + ((widget.rank - 1) * 25).clamp(0, 500)),
      curve: Curves.easeOut,
      builder: (context, anim, child) {
        return Opacity(
          opacity: anim,
          child: Transform.translate(
            offset: Offset(0, (1.0 - anim) * 8),
            child: child,
          ),
        );
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Container(
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _isHovered
                ? const Color(0xFF111827)
                : (isTop
                    ? const Color(0xFFa855f7).withValues(alpha: 0.03)
                    : Colors.transparent),
            border: Border.all(
              color: isTop
                  ? const Color(0xFFa855f7).withValues(alpha: _isHovered ? 0.35 : 0.15)
                  : (_isHovered
                      ? const Color(0xFF2a3a4a)
                      : const Color(0xFF1a2030)),
              width: 0.5,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              // ── Rank ──
              SizedBox(
                width: 60,
                child: Container(
                  width: 36,
                  height: 28,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: rankColor.withValues(alpha: 0.12),
                    border: Border.all(color: rankColor.withValues(alpha: 0.35)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${widget.rank}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: rankColor,
                      fontSize: 13,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),

              // ── Tag ──
              SizedBox(
                width: 70,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFa855f7).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFa855f7).withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    '[$tag]',
                    style: const TextStyle(
                      color: Color(0xFFa855f7),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      fontFamily: 'monospace',
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(width: 20),

              // ── Clan name + description ──
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Color(0xFFe0e6ed),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (description.isNotEmpty)
                      Text(
                        description,
                        style: const TextStyle(
                          color: Color(0xFF5a6578),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 20),

              // ── Members ──
              SizedBox(
                width: 100,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Icon(Icons.person_rounded, color: Color(0xFF5a6578), size: 13),
                    const SizedBox(width: 4),
                    Text(
                      '$memberCount',
                      style: const TextStyle(
                        color: Color(0xFF8a95a5),
                        fontSize: 12,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),

              // ── Leader ──
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Color(0xFFFFD700), size: 13),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        leaderName,
                        style: const TextStyle(
                          color: Color(0xFF8a95a5),
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Helper functions (top-level, no context dependency)
// ═══════════════════════════════════════════════════════════════════════════════

Color _rankColor(int index) {
  return switch (index) {
    0 => const Color(0xFFFFD700),
    1 => const Color(0xFFC0C0C0),
    2 => const Color(0xFFCD7F32),
    _ => const Color(0xFF5a6578),
  };
}

String _formatNumber(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return '$value';
}
