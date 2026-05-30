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
    final events = eventProvider.activeEvents;

    return Scaffold(
      backgroundColor: const Color(0xFF0a0e17),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: events.isEmpty
              ? _buildNoEventsState()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                  itemCount: events.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) return _buildHeader();
                    return _EventCard(
                      event: events[index - 1],
                      participation: eventProvider.getParticipation(events[index - 1].id),
                      onJoin: () async {
                        final auth = context.read<AuthProvider>();
                        if (auth.userId == null) return;
                        final success = await eventProvider.joinEvent(auth.userId!, events[index - 1].id);
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
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(24),
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
          Row(
            children: [
              const Icon(Icons.calendar_today, color: Color(0xFF00e5ff), size: 26),
              const SizedBox(width: 12),
              const Text(
                'СОБЫТИЯ НЕДЕЛИ',
                style: TextStyle(
                  color: Color(0xFF00e5ff),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              const Spacer(),
              // Refresh button
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    final auth = context.read<AuthProvider>();
                    if (auth.userId != null) {
                      context.read<EventProvider>().refresh(auth.userId!);
                    }
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF1e293b)),
                    ),
                    child: const Icon(Icons.refresh, color: Color(0xFF4a5568), size: 20),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Участвуйте в событиях и получайте уникальные награды! Каждую неделю новые испытания.',
            style: TextStyle(color: Color(0xFF4a5568), fontSize: 13),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _eventTypeInfo(Icons.military_tech, 'Турнир', 'PvP', const Color(0xFFFF0040))),
              const SizedBox(width: 12),
              Expanded(child: _eventTypeInfo(Icons.local_offer, 'Распродажа', 'Скидки', const Color(0xFFFFD700))),
              const SizedBox(width: 12),
              Expanded(child: _eventTypeInfo(Icons.groups, 'Рейд', 'Клан', const Color(0xFF00ff41))),
              const SizedBox(width: 12),
              Expanded(child: _eventTypeInfo(Icons.bug_report, 'Охота', 'PvE', const Color(0xFFa855f7))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _eventTypeInfo(IconData icon, String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0d1220),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1e293b)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
              Text(subtitle, style: const TextStyle(color: Color(0xFF3a4060), fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoEventsState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.event_available, size: 72, color: Color(0xFF1e293b)),
          const SizedBox(height: 20),
          const Text('Нет активных событий', style: TextStyle(color: Color(0xFF4a5568), fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Новые события появляются каждую неделю. Следите за обновлениями!',
              style: TextStyle(color: Color(0xFF3a4060), fontSize: 13)),
        ],
      ),
    );
  }
}

class _EventCard extends StatefulWidget {
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

  @override
  State<_EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<_EventCard> {
  bool _isHovered = false;

  Color get _eventColor => switch (widget.event.eventType) {
    'pvp_tournament' => const Color(0xFFFF0040),
    'black_friday' => const Color(0xFFFFD700),
    'clan_raid' => const Color(0xFF00ff41),
    'bug_hunt' => const Color(0xFFa855f7),
    _ => const Color(0xFF00e5ff),
  };

  @override
  Widget build(BuildContext context) {
    final color = _eventColor;
    final isParticipating = widget.participation != null;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0d1220),
              color.withValues(alpha: 0.05),
            ],
          ),
          border: Border.all(
            color: color.withValues(alpha: isParticipating ? 0.4 : 0.15),
            width: isParticipating ? 1.5 : 0.5,
          ),
          boxShadow: isParticipating
              ? [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 20)]
              : null,
        ),
        child: Column(
          children: [
            // ── Header ──
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.06),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Center(child: Text(widget.event.typeIcon, style: const TextStyle(fontSize: 24))),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.event.name.toUpperCase(),
                          style: TextStyle(
                            color: color,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.event.typeLabel,
                          style: const TextStyle(color: Color(0xFF4a5568), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  // Time remaining badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.schedule, color: Colors.white54, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          widget.event.timeRemaining,
                          style: const TextStyle(color: Color(0xFF4a5568), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ──
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  if (widget.event.description.isNotEmpty)
                    Text(
                      widget.event.description,
                      style: const TextStyle(color: Color(0xFF4a5568), fontSize: 13),
                    ),
                  if (widget.event.description.isNotEmpty) const SizedBox(height: 14),

                  // Progress bar
                  Row(
                    children: [
                      const Text('ПРОГРЕСС', style: TextStyle(color: Color(0xFF3a4060), fontSize: 10, letterSpacing: 2)),
                      const Spacer(),
                      Text('${(widget.event.progressPercent * 100).toInt()}%', style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: widget.event.progressPercent,
                      minHeight: 8,
                      backgroundColor: const Color(0xFF111827),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Rewards row
                  Row(
                    children: [
                      if (widget.event.rewardCredits > 0) ...[
                        const Icon(Icons.monetization_on, color: Color(0xFFFFD700), size: 18),
                        const SizedBox(width: 6),
                        Text('${widget.event.rewardCredits} CR', style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(width: 20),
                      ],
                      if (widget.event.rewardXp > 0) ...[
                        const Icon(Icons.star, color: Color(0xFFa855f7), size: 18),
                        const SizedBox(width: 6),
                        Text('${widget.event.rewardXp} XP', style: const TextStyle(color: Color(0xFFa855f7), fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                      if (widget.event.isMarketDiscount) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.3)),
                          ),
                          child: const Text('СКИДКА -50%', style: TextStyle(color: Color(0xFFFFD700), fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),

                  // Player score if participating
                  if (isParticipating) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0a0e17),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF1e293b)),
                      ),
                      child: Row(
                        children: [
                          const Text('Ваш счёт:', style: TextStyle(color: Color(0xFF4a5568), fontSize: 12)),
                          const Spacer(),
                          Text('${widget.participation!.score}', style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
                          const SizedBox(width: 16),
                          Container(width: 1, height: 20, color: const Color(0xFF1e293b)),
                          const SizedBox(width: 16),
                          Text('Попыток: ${widget.participation!.attempts}', style: const TextStyle(color: Color(0xFF3a4060), fontSize: 11)),
                          const SizedBox(width: 16),
                          Container(width: 1, height: 20, color: const Color(0xFF1e293b)),
                          const SizedBox(width: 16),
                          Text('Лучший: ${widget.participation!.bestScore}', style: TextStyle(color: color.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],

                  // Join/Participating button
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
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
                                  Icon(Icons.check_circle, color: color.withValues(alpha: 0.6), size: 18),
                                  const SizedBox(width: 8),
                                  Text('ВЫ УЧАСТВУЕТЕ', style: TextStyle(color: color.withValues(alpha: 0.6), fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                                ],
                              ),
                            ),
                          )
                        : MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: widget.onJoin,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: _isHovered ? color.withValues(alpha: 0.2) : color.withValues(alpha: 0.12),
                                  border: Border.all(color: color.withValues(alpha: 0.4)),
                                ),
                                child: Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_circle_outline, color: color, size: 20),
                                      const SizedBox(width: 8),
                                      Text('УЧАСТВОВАТЬ', style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
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
      ),
    );
  }
}
