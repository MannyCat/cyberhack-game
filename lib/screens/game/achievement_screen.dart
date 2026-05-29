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
    final theme = Theme.of(context);
    final achievements = eventProvider.achievements;
    final completedCount = eventProvider.completedAchievements;

    final filtered = _selectedCategory == 'Все'
        ? achievements
        : achievements.where((a) => a.categoryLabel == _selectedCategory).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('ДОСТИЖЕНИЯ'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFa855f7).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFa855f7).withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.emoji_events, color: Color(0xFFa855f7), size: 14),
                const SizedBox(width: 4),
                Text(
                  '$completedCount/${achievements.length}',
                  style: const TextStyle(color: Color(0xFFa855f7), fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Category Filter ──
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = cat == _selectedCategory;
                return FilterChip(
                  label: Text(cat, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                    color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface)),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _selectedCategory = cat),
                  selectedColor: theme.colorScheme.primary,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  side: BorderSide(color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline.withValues(alpha: 0.3)),
                  showCheckmark: false,
                );
              },
            ),
          ),
          const Divider(height: 1),

          // ── Achievement List ──
          Expanded(
            child: filtered.isEmpty
                ? _buildEmptyState(theme)
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      return _AchievementCard(
                        achievement: filtered[index],
                        onClaim: filtered[index].isCompleted && !filtered[index].isClaimed
                            ? () async {
                                final auth = context.read<AuthProvider>();
                                if (auth.userId == null) return;
                                await eventProvider.claimAchievement(auth.userId!, filtered[index].id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Награда за достижение получена!'),
                                    backgroundColor: Color(0xFFa855f7),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events_outlined, size: 56, color: theme.colorScheme.outline.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text('Нет достижений', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.outline)),
            const SizedBox(height: 8),
            Text('Начните играть, чтобы открывать достижения!', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline.withValues(alpha: 0.7))),
          ],
        ),
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final Achievement achievement;
  final VoidCallback? onClaim;

  const _AchievementCard({required this.achievement, this.onClaim});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = achievement;

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

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: a.isCompleted
            ? color.withValues(alpha: 0.06)
            : const Color(0xFF111827),
        border: Border.all(
          color: a.isCompleted
              ? color.withValues(alpha: 0.3)
              : a.isClaimed
                  ? const Color(0xFF2a2f40)
                  : const Color(0xFF1e293b),
          width: a.isCompleted ? 1.5 : 0.5,
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: a.isCompleted
                  ? color.withValues(alpha: 0.15)
                  : const Color(0xFF1a1f2e),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: a.isCompleted ? color.withValues(alpha: 0.4) : const Color(0xFF2a2f40),
              ),
            ),
            child: Icon(
              iconMap[a.icon] ?? Icons.star,
              color: a.isCompleted ? color : const Color(0xFF4a5568),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
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
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        a.categoryLabel,
                        style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  a.description,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (a.rewardCredits > 0) ...[
                      const Icon(Icons.monetization_on, color: Color(0xFFFFD700), size: 12),
                      const SizedBox(width: 2),
                      Text('+${a.rewardCredits}', style: const TextStyle(color: Color(0xFFFFD700), fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                    ],
                    if (a.rewardXp > 0) ...[
                      const Icon(Icons.star, color: Color(0xFFa855f7), size: 12),
                      const SizedBox(width: 2),
                      Text('+${a.rewardXp} XP', style: const TextStyle(color: Color(0xFFa855f7), fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Status / Claim
          if (a.isClaimed)
            const Icon(Icons.check_circle, color: Color(0xFF00ff41), size: 24)
          else if (a.isCompleted && onClaim != null)
            GestureDetector(
              onTap: onClaim,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Text('ЗАБРАТЬ', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            )
          else
            const Icon(Icons.lock_outline, color: Color(0xFF3a4060), size: 20),
        ],
      ),
    );
  }
}
