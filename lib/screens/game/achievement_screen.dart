import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/event_provider.dart';
import '../../providers/auth_provider.dart';

class AchievementScreen extends StatefulWidget {
  const AchievementScreen({super.key});

  @override
  State<AchievementScreen> createState() => _AchievementScreenState();
}

class _AchievementScreenState extends State<AchievementScreen> {
  String _selectedCategory = 'Все';
  final List<String> _categories = ['Все', 'Сеть', 'Боевые', 'Экономика', 'Социальные', 'Особые'];

  @override
  Widget build(BuildContext context) {
    final eventProvider = context.watch<EventProvider>();
    final achievements = eventProvider.achievements;
    final completedCount = eventProvider.completedAchievements;

    final filtered = _selectedCategory == 'Все'
        ? achievements
        : achievements.where((a) => a.categoryLabel == _selectedCategory).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0a0e17),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            children: [
              // ── Header ──
              Container(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Row(
                  children: [
                    const Icon(Icons.emoji_events, color: Color(0xFFa855f7), size: 28),
                    const SizedBox(width: 12),
                    const Text(
                      'ДОСТИЖЕНИЯ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFa855f7).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFa855f7).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.emoji_events, color: Color(0xFFa855f7), size: 16),
                          const SizedBox(width: 6),
                          Text(
                            '$completedCount/${achievements.length}',
                            style: const TextStyle(color: Color(0xFFa855f7), fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Category Filter ──
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                child: Row(
                  children: List.generate(_categories.length, (index) {
                    final cat = _categories[index];
                    final isSelected = cat == _selectedCategory;
                    return Padding(
                      padding: EdgeInsets.only(left: index == 0 ? 0 : 8),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedCategory = cat),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFa855f7).withValues(alpha: 0.2) : const Color(0xFF0d1220),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? const Color(0xFFa855f7).withValues(alpha: 0.5) : const Color(0xFF1e293b),
                              ),
                            ),
                            child: Text(
                              cat,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? const Color(0xFFa855f7) : const Color(0xFF4a5568),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const Divider(height: 1, color: Color(0xFF1e293b)),

              // ── Achievement List ──
              Expanded(
                child: filtered.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final a = filtered[index];
                          return _AchievementCard(
                            achievement: a,
                            onClaim: a.isCompleted && !a.isClaimed
                                ? () async {
                                    final auth = context.read<AuthProvider>();
                                    if (auth.userId == null) return;
                                    await eventProvider.claimAchievement(auth.userId!, a.id);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Награда за достижение получена!'),
                                          backgroundColor: Color(0xFFa855f7),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  }
                                : null,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events_outlined, size: 72, color: Color(0xFF1e293b)),
          const SizedBox(height: 20),
          const Text('Нет достижений', style: TextStyle(color: Color(0xFF4a5568), fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Начните играть, чтобы открывать достижения!', style: TextStyle(color: Color(0xFF3a4060), fontSize: 13)),
        ],
      ),
    );
  }
}

class _AchievementCard extends StatefulWidget {
  final Achievement achievement;
  final VoidCallback? onClaim;

  const _AchievementCard({required this.achievement, this.onClaim});

  @override
  State<_AchievementCard> createState() => _AchievementCardState();
}

class _AchievementCardState extends State<_AchievementCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.achievement;

    final iconMap = {
      'dns': Icons.dns,
      'account_tree': Icons.account_tree,
      'hub': Icons.hub,
      'gps_fixed': Icons.gps_fixed,
      'flash_on': Icons.flash_on,
      'military_tech': Icons.military_tech,
      'monetization_on': Icons.monetization_on,
      'storefront': Icons.storefront,
      'groups': Icons.groups,
      'local_fire_department': Icons.local_fire_department,
      'star': Icons.star,
    };

    final categoryColors = {
      'network': const Color(0xFF00e5ff),
      'combat': const Color(0xFFFF0040),
      'economy': const Color(0xFFFFD700),
      'social': const Color(0xFF00ff41),
      'special': const Color(0xFFa855f7),
    };

    final color = categoryColors[a.category] ?? const Color(0xFF4a5568);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onClaim != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: a.isCompleted
              ? color.withValues(alpha: _isHovered ? 0.1 : 0.06)
              : const Color(0xFF0d1220),
          border: Border.all(
            color: a.isCompleted
                ? color.withValues(alpha: 0.3)
                : a.isClaimed
                    ? const Color(0xFF1e293b)
                    : const Color(0xFF111827),
            width: a.isCompleted ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: a.isCompleted
                    ? color.withValues(alpha: 0.15)
                    : const Color(0xFF111827),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: a.isCompleted ? color.withValues(alpha: 0.4) : const Color(0xFF1e293b),
                ),
              ),
              child: Icon(
                iconMap[a.icon] ?? Icons.star,
                color: a.isCompleted ? color : const Color(0xFF4a5568),
                size: 24,
              ),
            ),
            const SizedBox(width: 18),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        a.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: a.isCompleted ? color : Colors.white.withValues(alpha: 0.85),
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          a.categoryLabel,
                          style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    a.description,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (a.rewardCredits > 0) ...[
                        const Icon(Icons.monetization_on, color: Color(0xFFFFD700), size: 14),
                        const SizedBox(width: 4),
                        Text('+${a.rewardCredits}', style: const TextStyle(color: Color(0xFFFFD700), fontSize: 11, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 12),
                      ],
                      if (a.rewardXp > 0) ...[
                        const Icon(Icons.star, color: Color(0xFFa855f7), size: 14),
                        const SizedBox(width: 4),
                        Text('+${a.rewardXp} XP', style: const TextStyle(color: Color(0xFFa855f7), fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Status / Claim
            const SizedBox(width: 12),
            if (a.isClaimed)
              const Icon(Icons.check_circle, color: Color(0xFF00ff41), size: 28)
            else if (a.isCompleted && widget.onClaim != null)
              GestureDetector(
                onTap: widget.onClaim,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _isHovered ? color.withValues(alpha: 0.25) : color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withValues(alpha: 0.4)),
                  ),
                  child: Text('ЗАБРАТЬ', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              )
            else
              const Icon(Icons.lock_outline, color: Color(0xFF3a4060), size: 24),
          ],
        ),
      ),
    );
  }
}
