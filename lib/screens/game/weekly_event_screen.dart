import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/event_provider.dart';
import '../../providers/auth_provider.dart';

class WeeklyEventScreen extends StatefulWidget {
  const WeeklyEventScreen({super.key});

  @override
  State<WeeklyEventScreen> createState() => _WeeklyEventScreenState();
}

class _WeeklyEventScreenState extends State<WeeklyEventScreen> with TickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _glowAnimation = Tween<double>(begin: 0.4, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    _glowController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eventProvider = context.watch<EventProvider>();
    final theme = Theme.of(context);
    final events = eventProvider.activeEvents;

    return Scaffold(
      appBar: AppBar(
        title: const Text('СОБЫТИЯ НЕДЕЛИ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Обновить',
            onPressed: () {
              final auth = context.read<AuthProvider>();
              if (auth.userId != null) {
                eventProvider.refresh(auth.userId!);
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () {
          final auth = context.read<AuthProvider>();
          return eventProvider.refresh(auth.userId!);
        },
        child: events.isEmpty
            ? _buildNoEventsState(theme)
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: events.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildHeader(theme);
                  }
                  return _EventCard(
                    event: events[index - 1],
                    participation: eventProvider.getParticipation(events[index - 1].id),
                    onJoin: () async {
                      final auth = context.read<AuthProvider>();
                      if (auth.userId == null) return;
                      final success = await eventProvider.joinEvent(
                        auth.userId!,
                        events[index - 1].id,
                      );
                      if (!context.mounted) return;
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Вы участвуете в событии!'),
                            backgroundColor: Color(0xFF00ff41),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    glowAnimation: _glowAnimation,
                  );
                },
              ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF00e5ff).withValues(alpha: 0.1),
            const Color(0xFFa855f7).withValues(alpha: 0.05),
          ],
        ),
        border: Border.all(color: const Color(0xFF00e5ff).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.calendar_today, color: Color(0xFF00e5ff), size: 22),
              SizedBox(width: 10),
              Text(
                'СОБЫТИЯ НЕДЕЛИ',
                style: TextStyle(
                  color: Color(0xFF00e5ff),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Участвуйте в событиях и получайте уникальные награды! Каждую неделю новые испытания.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _eventTypeInfo('military_tech', 'Турнир', 'PvP', const Color(0xFFFF0040)),
              const SizedBox(width: 16),
              _eventTypeInfo('local_offer', 'Распродажа', 'Скидки', const Color(0xFFFFD700)),
              const SizedBox(width: 16),
              _eventTypeInfo('groups', 'Рейд', 'Клан', const Color(0xFF00ff41)),
              const SizedBox(width: 16),
              _eventTypeInfo('bug_report', 'Охота', 'PvE', const Color(0xFFa855f7)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _eventTypeInfo(String icon, String title, String subtitle, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Center(child: Text(icon, style: TextStyle(fontSize: 16))),
          ),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
          Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 9)),
        ],
      ),
    );
  }

  Widget _buildNoEventsState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_available, size: 64, color: theme.colorScheme.outline.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text('Нет активных событий', style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.outline)),
            const SizedBox(height: 8),
            Text('Новые события появляются каждую неделю. Следите за обновлениями!',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline.withValues(alpha: 0.7))),
          ],
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final WeeklyEvent event;
  final EventParticipation? participation;
  final VoidCallback onJoin;
  final Animation<double> glowAnimation;

  const _EventCard({
    required this.event,
    this.participation,
    required this.onJoin,
    required this.glowAnimation,
  });

  Color get _eventColor => switch (event.eventType) {
    'pvp_tournament' => const Color(0xFFFF0040),
    'black_friday' => const Color(0xFFFFD700),
    'clan_raid' => const Color(0xFF00ff41),
    'bug_hunt' => const Color(0xFFa855f7),
    _ => const Color(0xFF00e5ff),
  };

  @override
  Widget build(BuildContext context) {
    final color = _eventColor;
    final isParticipating = participation != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF111827),
            color.withValues(alpha: 0.05),
          ],
        ),
        border: Border.all(
          color: color.withValues(alpha: isParticipating ? 0.4 : 0.15),
          width: isParticipating ? 1.5 : 0.5,
        ),
        boxShadow: isParticipating
            ? [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 16)]
            : null,
      ),
      child: Column(
        children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Center(child: Text(event.typeIcon, style: TextStyle(fontSize: 22))),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.name.toUpperCase(),
                        style: TextStyle(
                          color: color,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        event.typeLabel,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                // Time remaining badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: color.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule, color: Colors.white54, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        event.timeRemaining,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Body ──
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (event.description.isNotEmpty)
                  Text(
                    event.description,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                  ),
                if (event.description.isNotEmpty) const SizedBox(height: 12),

                // Progress bar
                Row(
                  children: [
                    Text('ПРОГРЕСС', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 9, letterSpacing: 1.5)),
                    const Spacer(),
                    Text('${(event.progressPercent * 100).toInt()}%', style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: event.progressPercent,
                    minHeight: 6,
                    backgroundColor: const Color(0xFF1a1f2e),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),

                const SizedBox(height: 16),

                // Rewards row
                Row(
                  children: [
                    if (event.rewardCredits > 0) ...[
                      const Icon(Icons.monetization_on, color: Color(0xFFFFD700), size: 16),
                      const SizedBox(width: 4),
                      Text('${event.rewardCredits} CR', style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(width: 16),
                    ],
                    if (event.rewardXp > 0) ...[
                      const Icon(Icons.star, color: Color(0xFFa855f7), size: 16),
                      const SizedBox(width: 4),
                      Text('${event.rewardXp} XP', style: const TextStyle(color: Color(0xFFa855f7), fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                    if (event.isMarketDiscount) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.3)),
                        ),
                        child: const Text('СКИДКА -50%', style: TextStyle(color: Color(0xFFFFD700), fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),

                // Player score if participating
                if (isParticipating) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0d1220),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Text('Ваш счёт:', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
                        const Spacer(),
                        Text('${participation!.score}', style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
                        const SizedBox(width: 4),
                        Text('| Попыток: ${participation!.attempts}', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10)),
                        const SizedBox(width: 8),
                        Text('| Лучший: ${participation!.bestScore}', style: TextStyle(color: color.withValues(alpha: 0.6), fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],

                // Join/Participating button
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: isParticipating
                      ? Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: color.withValues(alpha: 0.08),
                            border: Border.all(color: color.withValues(alpha: 0.2)),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle, size: 16),
                                const SizedBox(width: 6),
                                Text('ВЫ УЧАСТВУЕТЕ', style: TextStyle(color: color.withValues(alpha: 0.6), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                              ],
                            ),
                          ),
                        )
                      : Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: onJoin,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: color.withValues(alpha: 0.12),
                                border: Border.all(color: color.withValues(alpha: 0.4)),
                              ),
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_circle_outline, color: color, size: 18),
                                    const SizedBox(width: 6),
                                    Text('УЧАСТВОВАТЬ', style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
