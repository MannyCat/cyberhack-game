import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/game_provider.dart';
import '../../widgets/cyber_button.dart';

// ── Color Constants ──────────────────────────────────────────────────────

const _bgDark = Color(0xFF0a0e17);
const _surface = Color(0xFF111827);
const _surfaceVariant = Color(0xFF1a2332);
const _greenPrimary = Color(0xFF00ff88);
const _greenDark = Color(0xFF00cc6a);
const _cyanSecondary = Color(0xFF00d4ff);
const _goldAccent = Color(0xFFFFD700);
const _dangerRed = Color(0xFFff4444);
const _purpleAccent = Color(0xFFa855f7);

// ── Target Class Data ───────────────────────────────────────────────────

class TargetClassInfo {
  final String key;
  final String labelRu;
  final IconData icon;
  final Color color;

  const TargetClassInfo({
    required this.key,
    required this.labelRu,
    required this.icon,
    required this.color,
  });
}

const _targetClasses = [
  TargetClassInfo(key: 'all', labelRu: 'Все', icon: Icons.grid_view, color: Colors.grey),
  TargetClassInfo(key: 'bank', labelRu: 'Банки', icon: Icons.account_balance, color: _goldAccent),
  TargetClassInfo(key: 'tech', labelRu: 'Технологии', icon: Icons.memory, color: _cyanSecondary),
  TargetClassInfo(key: 'energy', labelRu: 'Энергетика', icon: Icons.bolt, color: const Color(0xFFFFD700)),
  TargetClassInfo(key: 'logistics', labelRu: 'Логистика', icon: Icons.local_shipping, color: const Color(0xFFf97316)),
  TargetClassInfo(key: 'retail', labelRu: 'Ритейл', icon: Icons.shopping_cart, color: const Color(0xFFec4899)),
  TargetClassInfo(key: 'pharma', labelRu: 'Фармацевтика', icon: Icons.medical_services, color: const Color(0xFF22d3ee)),
  TargetClassInfo(key: 'media', labelRu: 'Медиа', icon: Icons.tv, color: const Color(0xFFa855f7)),
  TargetClassInfo(key: 'gov', labelRu: 'Правительство', icon: Icons.security, color: _dangerRed),
];

// ── Targets Screen ───────────────────────────────────────────────────────

class TargetsScreen extends ConsumerStatefulWidget {
  const TargetsScreen({super.key});

  @override
  ConsumerState<TargetsScreen> createState() => _TargetsScreenState();
}

class _TargetsScreenState extends ConsumerState<TargetsScreen> {
  final _supabase = Supabase.instance.client;

  // ── State ───────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _targets = [];
  bool _isLoading = true;
  String _selectedClass = 'all';

  @override
  void initState() {
    super.initState();
    _loadTargets();
  }

  // ── Data Loading ──────────────────────────────────────────────────────

  Future<void> _loadTargets() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('targets')
          .select()
          .eq('is_active', true)
          .order('difficulty');
      if (mounted) {
        setState(() {
          _targets = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  String _targetClassRu(String cls) {
    switch (cls) {
      case 'bank':
        return 'Банк';
      case 'tech':
        return 'Технологии';
      case 'energy':
        return 'Энергетика';
      case 'logistics':
        return 'Логистика';
      case 'retail':
        return 'Ритейл';
      case 'pharma':
        return 'Фармацевтика';
      case 'media':
        return 'Медиа';
      case 'gov':
        return 'Правительство';
      default:
        return cls;
    }
  }

  IconData _targetClassIcon(String? cls) {
    for (final c in _targetClasses) {
      if (c.key == cls) return c.icon;
    }
    return Icons.public;
  }

  Color _targetClassColor(String? cls) {
    for (final c in _targetClasses) {
      if (c.key == cls) return c.color;
    }
    return Colors.grey;
  }

  Color _securityColor(int security) {
    if (security < 30) return _greenPrimary;
    if (security < 60) return _goldAccent;
    if (security < 80) return const Color(0xFFFF8C00);
    return _dangerRed;
  }

  String _securityLabel(int security) {
    if (security < 30) return 'Низкая';
    if (security < 60) return 'Средняя';
    if (security < 80) return 'Высокая';
    return 'Макс.';
  }

  Color _difficultyColor(int difficulty) {
    if (difficulty <= 3) return _greenPrimary;
    if (difficulty <= 5) return _goldAccent;
    if (difficulty <= 7) return const Color(0xFFFF8C00);
    return _dangerRed;
  }

  String _formatCredits(dynamic value) {
    final v = (value as num?)?.toInt() ?? 0;
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toString();
  }

  // ── Filtering ──────────────────────────────────────────────────────────

  List<Map<String, dynamic>> get _filteredTargets {
    if (_selectedClass == 'all') return _targets;
    return _targets.where((t) => t['class'] == _selectedClass).toList();
  }

  // ── Navigate to Operations ────────────────────────────────────────────

  void _goToOperations(Map<String, dynamic> target) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Цель "${target['name']}" выбрана. Перейдите на вкладку Операции для начала.',
        ),
        backgroundColor: _cyanSecondary,
        foregroundColor: _bgDark,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'ПЕРЕЙТИ',
          textColor: _bgDark,
          onPressed: () => context.go('/game/operations'),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _greenPrimary),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Page Header ───────────────────────────────────────────────
          const Row(
            children: [
              Icon(Icons.my_location, color: _cyanSecondary, size: 22),
              SizedBox(width: 8),
              Text(
                'КАТАЛОГ ЦЕЛЕЙ',
                style: TextStyle(
                  color: _cyanSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Divider(color: _surfaceVariant, height: 1),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Filter Chips ──────────────────────────────────────────────
          _buildFilterChips(),
          const SizedBox(height: 20),

          // ── Target Grid ───────────────────────────────────────────────
          _filteredTargets.isEmpty
              ? _buildEmptyState()
              : Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: _filteredTargets
                      .map((t) => _buildTargetCard(t))
                      .toList(),
                ),
        ],
      ),
    );
  }

  // ── Filter Chips ───────────────────────────────────────────────────────

  Widget _buildFilterChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _targetClasses.map((cls) {
        final isSelected = _selectedClass == cls.key;
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => setState(() => _selectedClass = cls.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? cls.color.withValues(alpha: 0.15)
                    : const Color(0xFF0d1420),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? cls.color.withValues(alpha: 0.5)
                      : _surfaceVariant,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    cls.icon,
                    color: isSelected ? cls.color : Colors.grey.shade500,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    cls.labelRu,
                    style: TextStyle(
                      color: isSelected ? cls.color : Colors.grey.shade400,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  // Count badge
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: cls.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      cls.key == 'all'
                          ? '${_targets.length}'
                          : '${_targets.where((t) => t['class'] == cls.key).length}',
                      style: TextStyle(
                        color: cls.color.withValues(alpha: 0.6),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Target Card ────────────────────────────────────────────────────────

  Widget _buildTargetCard(Map<String, dynamic> target) {
    final name = target['name'] as String? ?? '—';
    final corp = target['corporation'] as String? ?? '';
    final targetClass = target['class'] as String? ?? '';
    final difficulty = (target['difficulty'] as num?)?.toInt() ?? 1;
    final security = (target['security_level'] as num?)?.toInt() ?? 0;
    final baseReward = (target['base_reward'] as num?)?.toInt() ?? 0;
    final region = target['region'] as String? ?? '';
    final classColor = _targetClassColor(targetClass);

    return _TargetCardWidget(
      name: name,
      corporation: corp,
      targetClass: targetClass,
      targetClassRu: _targetClassRu(targetClass),
      classIcon: _targetClassIcon(targetClass),
      classColor: classColor,
      difficulty: difficulty,
      difficultyColor: _difficultyColor(difficulty),
      security: security,
      securityColor: _securityColor(security),
      securityLabel: _securityLabel(security),
      baseReward: baseReward,
      region: region,
      onTap: () => _goToOperations(target),
    );
  }

  // ── Empty State ────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 80),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.public_off_outlined, color: Colors.grey.shade600, size: 56),
            const SizedBox(height: 16),
            const Text(
              'Нет целей в этой категории.',
              style: TextStyle(color: Colors.grey, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Target Card Widget (stateful for hover) ─────────────────────────────

class _TargetCardWidget extends StatefulWidget {
  final String name;
  final String corporation;
  final String targetClass;
  final String targetClassRu;
  final IconData classIcon;
  final Color classColor;
  final int difficulty;
  final Color difficultyColor;
  final int security;
  final Color securityColor;
  final String securityLabel;
  final int baseReward;
  final String region;
  final VoidCallback onTap;

  const _TargetCardWidget({
    required this.name,
    required this.corporation,
    required this.targetClass,
    required this.targetClassRu,
    required this.classIcon,
    required this.classColor,
    required this.difficulty,
    required this.difficultyColor,
    required this.security,
    required this.securityColor,
    required this.securityLabel,
    required this.baseReward,
    required this.region,
    required this.onTap,
  });

  @override
  State<_TargetCardWidget> createState() => _TargetCardWidgetState();
}

class _TargetCardWidgetState extends State<_TargetCardWidget> {
  bool _isHovered = false;

  String _formatCredits(dynamic value) {
    final v = (value as num?)?.toInt() ?? 0;
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: 280,
          transform:
              _isHovered ? (Matrix4.identity()..scale(1.02)) : Matrix4.identity(),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isHovered
                  ? widget.classColor.withValues(alpha: 0.5)
                  : _surfaceVariant,
              width: _isHovered ? 1.5 : 1,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: widget.classColor.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header: Class Icon + Name + Corp ────────────────────
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: widget.classColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        widget.classIcon,
                        color: widget.classColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.corporation.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.corporation,
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // ── Class Badge + Region Tag ─────────────────────────────
                Row(
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: widget.classColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: widget.classColor.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Text(
                        widget.targetClassRu,
                        style: TextStyle(
                          color: widget.classColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (widget.region.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_on_outlined,
                                color: Colors.grey.shade500, size: 12),
                            const SizedBox(width: 3),
                            Text(
                              widget.region,
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),

                // ── Difficulty Stars ─────────────────────────────────────
                Row(
                  children: [
                    const Text(
                      'СЛОЖНОСТЬ',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Row(
                        children: List.generate(10, (i) {
                          final filled = i < widget.difficulty;
                          return Padding(
                            padding: const EdgeInsets.only(right: 1),
                            child: Icon(
                              filled
                                  ? Icons.circle
                                  : Icons.circle_outlined,
                              color: filled
                                  ? widget.difficultyColor
                                  : Colors.grey.shade700,
                              size: 8,
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.difficulty}/10',
                      style: TextStyle(
                        color: widget.difficultyColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // ── Security Bar ────────────────────────────────────────
                Row(
                  children: [
                    const Text(
                      'ЗАЩИТА',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (widget.security / 100.0).clamp(0.0, 1.0),
                          backgroundColor: _surfaceVariant,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              widget.securityColor),
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.securityLabel,
                      style: TextStyle(
                        color: widget.securityColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Base Reward ──────────────────────────────────────────
                Row(
                  children: [
                    const Icon(Icons.attach_money,
                        color: _greenPrimary, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${_formatCredits(widget.baseReward)} кредитов',
                      style: const TextStyle(
                        color: _greenPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Action Button ────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: CyberButton(
                    text: 'НАЧАТЬ ОПЕРАЦИЮ',
                    icon: Icons.play_arrow,
                    variant: CyberButtonVariant.secondary,
                    height: 36,
                    onPressed: widget.onTap,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
