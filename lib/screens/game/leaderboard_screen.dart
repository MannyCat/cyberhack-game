import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/game_provider.dart';

// ── Color Constants ──────────────────────────────────────────────────────

const _bgDark = Color(0xFF0a0e17);
const _surface = Color(0xFF111827);
const _surfaceVariant = Color(0xFF1a2332);
const _greenPrimary = Color(0xFF00ff88);
const _cyanSecondary = Color(0xFF00d4ff);
const _goldAccent = Color(0xFFFFD700);
const _silverColor = Color(0xFFC0C0C0);
const _bronzeColor = Color(0xFFCD7F32);

// ── Leaderboard Tab ─────────────────────────────────────────────────────

enum _LeaderboardTab {
  level('По уровню', 'level'),
  income('По доходу', 'total_earnings'),
  reputation('По репутации', 'reputation');

  const _LeaderboardTab(this.label, this.column);
  final String label;
  final String column;
}

// ── Leaderboard Screen ──────────────────────────────────────────────────

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  final _supabase = Supabase.instance.client;

  _LeaderboardTab _selectedTab = _LeaderboardTab.level;
  List<Map<String, dynamic>> _players = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  // ── Data Loading ──────────────────────────────────────────────────────

  Future<void> _loadLeaderboard() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .order(_selectedTab.column, ascending: false)
          .limit(50);
      if (mounted) {
        setState(() {
          _players = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  String _formatValue(dynamic value) {
    final v = (value as num?)?.toInt() ?? 0;
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toString();
  }

  Color _rankColor(int rank) {
    switch (rank) {
      case 1:
        return _goldAccent;
      case 2:
        return _silverColor;
      case 3:
        return _bronzeColor;
      default:
        return Colors.white;
    }
  }

  IconData _rankIcon(int rank) {
    switch (rank) {
      case 1:
        return Icons.emoji_events;
      case 2:
        return Icons.emoji_events;
      case 3:
        return Icons.emoji_events;
      default:
        return Icons.remove;
    }
  }

  bool _isCurrentPlayer(Map<String, dynamic> player) {
    final userId = _supabase.auth.currentUser?.id;
    return player['id'] == userId;
  }

  String _valueLabel(_LeaderboardTab tab) {
    switch (tab) {
      case _LeaderboardTab.level:
        return 'УР.';
      case _LeaderboardTab.income:
        return 'КРЕДИТЫ';
      case _LeaderboardTab.reputation:
        return 'РЕП.';
    }
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(gameProvider);

    if (game.isLoading || _isLoading) {
      return const Center(child: CircularProgressIndicator(color: _greenPrimary));
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────
          const Row(
            children: [
              Icon(Icons.leaderboard, color: _goldAccent, size: 28),
              SizedBox(width: 12),
              Text(
                'ТАБЛИЦА ЛИДЕРОВ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Filter Tabs ──────────────────────────────────────────
          _buildFilterTabs(),
          const SizedBox(height: 20),

          // ── Column Headers ──────────────────────────────────────
          _buildColumnHeaders(),
          const SizedBox(height: 8),

          // ── Player List ─────────────────────────────────────────
          Expanded(child: _buildPlayerList()),
        ],
      ),
    );
  }

  // ── Filter Tabs ──────────────────────────────────────────────────────

  Widget _buildFilterTabs() {
    return Row(
      children: _LeaderboardTab.values.map((tab) {
        final isSelected = tab == _selectedTab;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                if (tab != _selectedTab) {
                  setState(() => _selectedTab = tab);
                  _loadLeaderboard();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _greenPrimary.withValues(alpha: 0.12)
                      : _surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? _greenPrimary.withValues(alpha: 0.4)
                        : _surfaceVariant,
                  ),
                ),
                child: Text(
                  tab.label,
                  style: TextStyle(
                    color: isSelected ? _greenPrimary : Colors.grey.shade400,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Column Headers ──────────────────────────────────────────────────

  Widget _buildColumnHeaders() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Rank
          const SizedBox(
            width: 60,
            child: Text(
              '#',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Player name
          const Expanded(
            child: Text(
              'ИГРОК',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
          ),
          // Value
          SizedBox(
            width: 150,
            child: Text(
              _valueLabel(_selectedTab),
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Player List ──────────────────────────────────────────────────────

  Widget _buildPlayerList() {
    if (_players.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.leaderboard, color: Colors.grey.shade700, size: 48),
            const SizedBox(height: 16),
            Text(
              'Нет данных для отображения.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _players.length,
      itemBuilder: (context, index) {
        final player = _players[index];
        final rank = index + 1;
        return _buildPlayerRow(player, rank);
      },
    );
  }

  Widget _buildPlayerRow(Map<String, dynamic> player, int rank) {
    final isMe = _isCurrentPlayer(player);
    final username = player['username'] as String? ?? 'Хакер';
    final value = player[_selectedTab.column] as dynamic;
    final isTop3 = rank <= 3;

    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isMe ? _greenPrimary.withValues(alpha: 0.06) : _surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isMe
                ? _greenPrimary.withValues(alpha: 0.3)
                : isTop3
                    ? _rankColor(rank).withValues(alpha: 0.15)
                    : _surfaceVariant,
          ),
        ),
        child: Row(
          children: [
            // Rank column (60px)
            SizedBox(
              width: 60,
              child: isTop3
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _rankIcon(rank),
                          color: _rankColor(rank),
                          size: rank == 1 ? 24 : 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$rank',
                          style: TextStyle(
                            color: _rankColor(rank),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    )
                  : Center(
                      child: Text(
                        '$rank',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 12),

            // Player name (Expanded)
            Expanded(
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: _rankColor(rank).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _rankColor(rank).withValues(alpha: 0.25),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        username.isNotEmpty
                            ? username[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: isTop3
                              ? _rankColor(rank)
                              : Colors.grey.shade400,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Name
                  Flexible(
                    child: Text(
                      username,
                      style: TextStyle(
                        color: isMe
                            ? _greenPrimary
                            : isTop3
                                ? Colors.white
                                : Colors.grey.shade300,
                        fontSize: 14,
                        fontWeight:
                            isMe || isTop3 ? FontWeight.bold : FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _greenPrimary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'ВЫ',
                        style: TextStyle(
                          color: _greenPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Value column (150px)
            SizedBox(
              width: 150,
              child: Text(
                _formatValue(value),
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: isTop3
                      ? _rankColor(rank)
                      : Colors.grey.shade400,
                  fontSize: 15,
                  fontWeight: isTop3 ? FontWeight.bold : FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
