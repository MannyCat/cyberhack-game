import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/game_provider.dart';
import '../../widgets/cyber_button.dart';

// ── Color Constants ──────────────────────────────────────────────────────

const _bgDark = Color(0xFF0a0e17);
const _surface = Color(0xFF111827);
const _surfaceVariant = Color(0xFF1a2332);
const _greenPrimary = Color(0xFF00ff88);
const _cyanSecondary = Color(0xFF00d4ff);
const _goldAccent = Color(0xFFFFD700);
const _dangerRed = Color(0xFFff4444);
const _purpleAccent = Color(0xFFa855f7);

// ── Category Data ──────────────────────────────────────────────────────

enum ResearchCategory {
  all('Все', Icons.grid_view, Colors.grey),
  offense('Атака', Icons.gavel, _dangerRed),
  defense('Защита', Icons.shield, _cyanSecondary),
  economy('Экономика', Icons.coins, _goldAccent),
  infrastructure('Инфраструктура', Icons.dns_outlined, _cyanSecondary),
  stealth('Стелс', Icons.visibility_off_outlined, _purpleAccent);

  const ResearchCategory(this.labelRu, this.icon, this.color);
  final String labelRu;
  final IconData icon;
  final Color color;
}

// ── Research Screen ─────────────────────────────────────────────────────

class ResearchScreen extends ConsumerStatefulWidget {
  const ResearchScreen({super.key});

  @override
  ConsumerState<ResearchScreen> createState() => _ResearchScreenState();
}

class _ResearchScreenState extends ConsumerState<ResearchScreen> {
  final _supabase = Supabase.instance.client;
  Timer? _countdownTimer;

  // ── State ───────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _research = [];
  List<Map<String, dynamic>> _playerResearch = [];
  bool _isLoading = true;
  ResearchCategory _selectedCategory = ResearchCategory.all;

  // Track research items currently being started (avoid double-click)
  final Set<String> _startingIds = {};

  @override
  void initState() {
    super.initState();
    _loadData();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  // ── Data Loading ──────────────────────────────────────────────────────

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      final results = await Future.wait([
        _supabase.from('research').select().eq('is_active', true).order('tier'),
        if (userId != null)
          _supabase.from('player_research').select().eq('player_id', userId),
      ]);
      if (mounted) {
        setState(() {
          _research = List<Map<String, dynamic>>.from(results[0]);
          _playerResearch = results.length > 1
              ? List<Map<String, dynamic>>.from(results[1])
              : [];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  String _catRu(String cat) {
    switch (cat) {
      case 'offense':
        return 'Атака';
      case 'defense':
        return 'Защита';
      case 'economy':
        return 'Экономика';
      case 'infrastructure':
        return 'Инфраструктура';
      case 'stealth':
        return 'Стелс';
      default:
        return cat;
    }
  }

  Color _catColor(String cat) {
    switch (cat) {
      case 'offense':
        return _dangerRed;
      case 'defense':
        return _cyanSecondary;
      case 'economy':
        return _goldAccent;
      case 'infrastructure':
        return _cyanSecondary;
      case 'stealth':
        return _purpleAccent;
      default:
        return Colors.grey;
    }
  }

  IconData _catIcon(String cat) {
    switch (cat) {
      case 'offense':
        return Icons.gavel;
      case 'defense':
        return Icons.shield;
      case 'economy':
        return Icons.coins;
      case 'infrastructure':
        return Icons.dns_outlined;
      case 'stealth':
        return Icons.visibility_off;
      default:
        return Icons.science;
    }
  }

  String _formatCredits(dynamic value) {
    final v = (value as num?)?.toInt() ?? 0;
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toString();
  }

  String _formatHours(dynamic value) {
    final v = (value as num?)?.toInt() ?? 0;
    if (v >= 24) return '${v ~/ 24}д ${v % 24}ч';
    return '${v}ч';
  }

  /// Returns research status for a given research item:
  /// 'completed', 'researching', 'available', or 'locked'.
  String _getStatus(Map<String, dynamic> item) {
    // Check if completed
    final isCompleted =
        _playerResearch.any((pr) => pr['research_id'] == item['id'] && pr['status'] == 'completed');
    if (isCompleted) return 'completed';

    // Check if currently researching
    final active = _playerResearch.any((pr) => pr['research_id'] == item['id'] && pr['status'] == 'active');
    if (active) return 'researching';

    // Check if prerequisite met
    final prereqId = item['prerequisite_id'] as String?;
    if (prereqId != null) {
      final prereqMet = _playerResearch.any(
          (pr) => pr['research_id'] == prereqId && pr['status'] == 'completed');
      if (!prereqMet) return 'locked';
    }

    return 'available';
  }

  /// Find the prerequisite research name for a locked item.
  String _getPrereqName(Map<String, dynamic> item) {
    final prereqId = item['prerequisite_id'] as String?;
    if (prereqId == null) return '';
    final prereq =
        _research.firstWhere((r) => r['id'] == prereqId, orElse: () => {});
    return prereq['name'] as String? ?? '';
  }

  /// Time remaining for a researching item.
  String _timeRemaining(Map<String, dynamic> playerItem) {
    final completesAt = playerItem['completes_at'] as String?;
    if (completesAt == null) return '—';
    final end = DateTime.parse(completesAt);
    final diff = end.difference(DateTime.now().toUtc());
    if (diff.isNegative) return 'Готово';
    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60);
    final s = diff.inSeconds.remainder(60);
    if (h > 0) return '${h}ч ${m.toString().padLeft(2, '0')}м ${s.toString().padLeft(2, '0')}с';
    if (m > 0) return '${m}м ${s.toString().padLeft(2, '0')}с';
    return '${s}с';
  }

  /// Progress 0..1 for a researching item.
  double _researchProgress(Map<String, dynamic> playerItem) {
    final startsAt = playerItem['started_at'] as String?;
    final completesAt = playerItem['completes_at'] as String?;
    if (startsAt == null || completesAt == null) return 0.0;
    final start = DateTime.parse(startsAt);
    final end = DateTime.parse(completesAt);
    final total = end.difference(start).inSeconds;
    final elapsed = DateTime.now().toUtc().difference(start).inSeconds;
    if (total <= 0) return 1.0;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  /// Parse effect_json into a display string.
  String _effectDescription(Map<String, dynamic> item) {
    final raw = item['effect_json'];
    if (raw == null) return '';
    try {
      final map = raw is String ? jsonDecode(raw) as Map<String, dynamic> : raw;
      return map.entries
          .map((e) => '+${e.value} ${_effectKeyRu(e.key)}')
          .join(', ');
    } catch (_) {
      return raw.toString();
    }
  }

  String _effectKeyRu(String key) {
    switch (key) {
      case 'attack_power':
        return 'атаки';
      case 'defense_power':
        return 'защиты';
      case 'income_bonus':
        return 'дохода';
      case 'power_capacity':
        return 'энергии';
      case 'stealth_bonus':
        return 'стелса';
      case 'research_speed':
        return 'скор. исслед.';
      case 'operation_speed':
        return 'скор. операций';
      default:
        return key;
    }
  }

  // ── Actions ────────────────────────────────────────────────────────────

  Future<void> _startResearch(Map<String, dynamic> item) async {
    final credits = ref.read(gameProvider).credits ?? 0;
    final cost = (item['cost_credits'] as num?)?.toInt() ?? 0;
    if (credits < cost) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Недостаточно кредитов (нужно ${_formatCredits(cost)}, есть ${_formatCredits(credits)})'),
            backgroundColor: _dangerRed,
          ),
        );
      }
      return;
    }

    setState(() => _startingIds.add(item['id'] as String));
    try {
      await _supabase.rpc('start_research', params: {
        'p_research_id': item['id'],
      });
      await ref.read(gameProvider.notifier).loadAllData();
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Исследование начато!'),
            backgroundColor: _greenPrimary,
            foregroundColor: _bgDark,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: _dangerRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _startingIds.remove(item['id'] as String));
    }
  }

  // ── Filtering ──────────────────────────────────────────────────────────

  List<Map<String, dynamic>> get _filteredResearch {
    if (_selectedCategory == ResearchCategory.all) return _research;
    return _research
        .where((r) => r['category'] == _selectedCategory.name)
        .toList();
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _greenPrimary),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Left Sidebar: Category Tabs ──────────────────────────────────
        _buildSidebar(),
        // ── Main Area: Research Tree Grid ───────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _filteredResearch.isEmpty
                ? _buildEmptyState()
                : Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: _filteredResearch.map(_buildResearchCard).toList(),
                  ),
          ),
        ),
      ],
    );
  }

  // ── Sidebar ───────────────────────────────────────────────────────────

  Widget _buildSidebar() {
    return Container(
      width: 200,
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(right: BorderSide(color: _surfaceVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Row(
              children: [
                Icon(Icons.science, color: _greenPrimary, size: 20),
                SizedBox(width: 8),
                Text(
                  'ИССЛЕДОВАНИЯ',
                  style: TextStyle(
                    color: _greenPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: _surfaceVariant, height: 1),
          const SizedBox(height: 8),
          ...ResearchCategory.values.map((cat) => _buildCategoryTab(cat)),
        ],
      ),
    );
  }

  Widget _buildCategoryTab(ResearchCategory cat) {
    final isSelected = _selectedCategory == cat;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => setState(() => _selectedCategory = cat),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? cat.color.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? cat.color.withValues(alpha: 0.4)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isSelected ? cat.color : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  cat.icon,
                  color: isSelected ? cat.color : Colors.grey.shade500,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    cat.labelRu,
                    style: TextStyle(
                      color: isSelected ? cat.color : Colors.grey.shade400,
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                // Count badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: cat.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    cat == ResearchCategory.all
                        ? '${_research.length}'
                        : '${_research.where((r) => r['category'] == cat.name).length}',
                    style: TextStyle(
                      color: cat.color.withValues(alpha: 0.7),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Research Card ─────────────────────────────────────────────────────

  Widget _buildResearchCard(Map<String, dynamic> item) {
    final status = _getStatus(item);
    final name = item['name'] as String? ?? '—';
    final category = item['category'] as String? ?? '';
    final tier = (item['tier'] as num?)?.toInt() ?? 1;
    final description = item['description'] as String? ?? '';
    final costCredits = (item['cost_credits'] as num?)?.toInt() ?? 0;
    final costHours = (item['cost_hours'] as num?)?.toInt() ?? 0;
    final catColor = _catColor(category);

    return SizedBox(
      width: 360,
      child: _ResearchCardWidget(
        name: name,
        category: category,
        categoryRu: _catRu(category),
        categoryColor: catColor,
        categoryIcon: _catIcon(category),
        tier: tier,
        description: description,
        costCredits: costCredits,
        costHours: costHours,
        effectDescription: _effectDescription(item),
        status: status,
        prereqName: _getPrereqName(item),
        playerItem: _playerResearch
            .where((pr) => pr['research_id'] == item['id'])
            .firstOrNull,
        isStarting: _startingIds.contains(item['id']),
        timeRemainingFn: _timeRemaining,
        progressFn: _researchProgress,
        onStart: () => _startResearch(item),
      ),
    );
  }

  // ── Empty State ────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.science_outlined, color: Colors.grey.shade600, size: 56),
          const SizedBox(height: 16),
          const Text(
            'Нет исследований в этой категории.',
            style: TextStyle(color: Colors.grey, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

// ── Research Card Widget (stateful for hover) ────────────────────────────

class _ResearchCardWidget extends StatefulWidget {
  final String name;
  final String category;
  final String categoryRu;
  final Color categoryColor;
  final IconData categoryIcon;
  final int tier;
  final String description;
  final int costCredits;
  final int costHours;
  final String effectDescription;
  final String status;
  final String prereqName;
  final Map<String, dynamic>? playerItem;
  final bool isStarting;
  final String Function(Map<String, dynamic>) timeRemainingFn;
  final double Function(Map<String, dynamic>) progressFn;
  final VoidCallback? onStart;

  const _ResearchCardWidget({
    required this.name,
    required this.category,
    required this.categoryRu,
    required this.categoryColor,
    required this.categoryIcon,
    required this.tier,
    required this.description,
    required this.costCredits,
    required this.costHours,
    required this.effectDescription,
    required this.status,
    required this.prereqName,
    this.playerItem,
    required this.isStarting,
    required this.timeRemainingFn,
    required this.progressFn,
    this.onStart,
  });

  @override
  State<_ResearchCardWidget> createState() => _ResearchCardWidgetState();
}

class _ResearchCardWidgetState extends State<_ResearchCardWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isLocked = widget.status == 'locked';
    final isCompleted = widget.status == 'completed';
    final isResearching = widget.status == 'researching';
    final opacity = isLocked ? 0.5 : 1.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: isLocked ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: _isHovered && !isLocked
            ? (Matrix4.identity()..scale(1.02))
            : Matrix4.identity(),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isHovered && !isLocked
                ? widget.categoryColor.withValues(alpha: 0.5)
                : _surfaceVariant,
            width: _isHovered && !isLocked ? 1.5 : 1,
          ),
          boxShadow: _isHovered && !isLocked
              ? [
                  BoxShadow(
                    color: widget.categoryColor.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Opacity(
          opacity: opacity,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header: Name + Category Badge + Tier ─────────────────
                Row(
                  children: [
                    // Category icon
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: widget.categoryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        widget.categoryIcon,
                        color: widget.categoryColor,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Name
                    Expanded(
                      child: Text(
                        widget.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Tier indicator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _surfaceVariant,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Ур. ${widget.tier}',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // ── Category Badge ───────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: widget.categoryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: widget.categoryColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    widget.categoryRu,
                    style: TextStyle(
                      color: widget.categoryColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // ── Description ──────────────────────────────────────────
                if (widget.description.isNotEmpty)
                  Text(
                    widget.description,
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 12,
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (widget.description.isNotEmpty) const SizedBox(height: 10),

                // ── Effect Description ───────────────────────────────────
                if (widget.effectDescription.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(Icons.trending_up, color: _greenPrimary, size: 14),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.effectDescription,
                          style: const TextStyle(
                            color: _greenPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],

                // ── Cost ──────────────────────────────────────────────────
                if (!isCompleted)
                  Row(
                    children: [
                      Icon(Icons.attach_money, color: _goldAccent, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${_formatCredits(widget.costCredits)} кредитов',
                        style: const TextStyle(
                          color: _goldAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.schedule, color: _cyanSecondary, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${_formatHours(widget.costHours)}',
                        style: const TextStyle(
                          color: _cyanSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                if (!isCompleted) const SizedBox(height: 12),

                // ── Status Area ──────────────────────────────────────────
                if (isCompleted)
                  _buildCompletedBadge()
                else if (isResearching)
                  _buildProgressBar()
                else if (isLocked)
                  _buildLockedInfo()
                else
                  _buildStartButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompletedBadge() {
    return Row(
      children: [
        const Icon(Icons.check_circle, color: _greenPrimary, size: 16),
        const SizedBox(width: 6),
        const Text(
          'ЗАВЕРШЕНО',
          style: TextStyle(
            color: _greenPrimary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar() {
    final progress =
        widget.playerItem != null ? widget.progressFn(widget.playerItem!) : 0.0;
    final remaining = widget.playerItem != null
        ? widget.timeRemainingFn(widget.playerItem!)
        : '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.hourglass_top, color: _cyanSecondary, size: 14),
            const SizedBox(width: 4),
            Text(
              'Исследуется — $remaining',
              style: const TextStyle(
                color: _cyanSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: _surfaceVariant,
            valueColor: const AlwaysStoppedAnimation<Color>(_cyanSecondary),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildLockedInfo() {
    return Row(
      children: [
        Icon(Icons.lock, color: Colors.grey.shade500, size: 14),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Требуется: ${widget.prereqName}',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStartButton() {
    return SizedBox(
      width: double.infinity,
      child: CyberButton(
        text: 'НАЧАТЬ',
        icon: Icons.play_arrow,
        variant: CyberButtonVariant.primary,
        height: 36,
        isLoading: widget.isStarting,
        onPressed: widget.onStart,
      ),
    );
  }
}

// ── Shared formatting ────────────────────────────────────────────────────

String _formatCredits(dynamic value) {
  final v = (value as num?)?.toInt() ?? 0;
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
  return v.toString();
}

String _formatHours(dynamic value) {
  final v = (value as num?)?.toInt() ?? 0;
  if (v >= 24) return '${v ~/ 24}д ${v % 24}ч';
  return '${v}ч';
}
