import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/event_provider.dart';
import '../../providers/auth_provider.dart';

class DailyRewardScreen extends StatefulWidget {
  const DailyRewardScreen({super.key});

  @override
  State<DailyRewardScreen> createState() => _DailyRewardScreenState();
}

class _DailyRewardScreenState extends State<DailyRewardScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isClaiming = false;
  Map<String, dynamic>? _claimResult;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _claimReward() async {
    final auth = context.read<AuthProvider>();
    if (auth.userId == null) return;

    setState(() { _isClaiming = true; _claimResult = null; });

    final eventProvider = context.read<EventProvider>();
    final result = await eventProvider.claimDailyReward(auth.userId!);

    if (!mounted) return;
    setState(() {
      _isClaiming = false;
      _claimResult = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final eventProvider = context.watch<EventProvider>();
    final state = eventProvider.dailyRewardState;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ЕЖЕДНЕВНАЯ НАГРАДА'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_fire_department, color: Color(0xFFFFD700), size: 14),
                const SizedBox(width: 4),
                Text(
                  'Стрик ${state.currentStreak}',
                  style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header Card ──
            _buildHeaderCard(state, theme),
            const SizedBox(height: 20),

            // ── Week Calendar ──
            const Text('НЕДЕЛЯ', style: TextStyle(color: Color(0xFF4a5568), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(height: 12),
            _buildWeekCalendar(state, theme),
            const SizedBox(height: 20),

            // ── Streak Stats ──
            _buildStreakStats(state, theme),
            const SizedBox(height: 24),

            // ── Claim Button ──
            _buildClaimButton(state, theme),

            // ── Claim Result ──
            if (_claimResult != null) ...[
              const SizedBox(height: 16),
              _buildClaimResult(theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(DailyRewardState state, ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFFD700).withValues(alpha: 0.15),
            const Color(0xFFff9800).withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, _) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.4)),
                      ),
                      child: const Center(
                        child: Text('🎁', style: TextStyle(fontSize: 28)),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ЕЖЕДНЕВНАЯ НАГРАДА',
                      style: TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      state.canClaimToday
                          ? 'Награда за сегодня доступна!'
                          : 'Награда уже получена. Приходите завтра!',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeekCalendar(DailyRewardState state, ThemeData theme) {
    return Row(
      children: List.generate(7, (index) {
        final day = index + 1;
        final tier = DailyRewardTier.tiers[index];
        final isCurrentDay = DateTime.now().weekday == day;
        final isCompleted = day <= state.currentStreak;
        final isNextDay = isCurrentDay && state.canClaimToday;

        return Expanded(
          child: Container(
            margin: EdgeInsets.only(left: index == 0 ? 0 : 4, right: index == 6 ? 0 : 4),
            child: Column(
              children: [
                // Day label
                Text(
                  ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС'][index],
                  style: TextStyle(
                    color: isCurrentDay ? const Color(0xFFFFD700) : const Color(0xFF4a5568),
                    fontSize: 9,
                    fontWeight: isCurrentDay ? FontWeight.bold : FontWeight.normal,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                // Day box
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: isCompleted
                        ? const Color(0xFFFFD700).withValues(alpha: 0.15)
                        : isNextDay
                            ? const Color(0xFFFFD700).withValues(alpha: 0.08)
                            : const Color(0xFF111827),
                    border: Border.all(
                      color: isCompleted
                          ? const Color(0xFFFFD700).withValues(alpha: 0.5)
                          : isNextDay
                              ? const Color(0xFFFFD700).withValues(alpha: 0.3)
                              : const Color(0xFF1e293b),
                      width: isCurrentDay ? 1.5 : 0.5,
                    ),
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, color: Color(0xFFFFD700), size: 18)
                        : isNextDay
                            ? AnimatedBuilder(
                                animation: _pulseAnimation,
                                builder: (context, _) {
                                  return Icon(
                                    Icons.card_giftcard,
                                    color: const Color(0xFFFFD700)
                                        .withValues(alpha: 0.5 + _pulseAnimation.value * 0.5),
                                    size: 18,
                                  );
                                },
                              )
                            : Text(
                                '$day',
                                style: const TextStyle(color: Color(0xFF3a4060), fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                  ),
                ),
                const SizedBox(height: 4),
                // Credits
                Text(
                  '${tier.credits}',
                  style: TextStyle(
                    color: isCompleted ? const Color(0xFFFFD700) : const Color(0xFF4a5568),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildStreakStats(DailyRewardState state, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF111827),
        border: Border.all(color: const Color(0xFF1e293b)),
      ),
      child: Column(
        children: [
          const Text('СТАТИСТИКА СТРИКА', style: TextStyle(color: Color(0xFF4a5568), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _statItem('Текущий', '${state.currentStreak} дн.', const Color(0xFFFFD700)),
              ),
              Container(width: 1, height: 30, color: const Color(0xFF1e293b)),
              Expanded(
                child: _statItem('Лучший', '${state.bestStreak} дн.', const Color(0xFF00ff41)),
              ),
              Container(width: 1, height: 30, color: const Color(0xFF1e293b)),
              Expanded(
                child: _statItem('Всего', '${state.totalClaimed}', const Color(0xFF00e5ff)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Color(0xFF4a5568), fontSize: 10)),
      ],
    );
  }

  Widget _buildClaimButton(DailyRewardState state, ThemeData theme) {
    final canClaim = state.canClaimToday && !_isClaiming;

    return Center(
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: canClaim
                ? LinearGradient(colors: [
                    const Color(0xFFFFD700).withValues(alpha: 0.2),
                    const Color(0xFFff9800).withValues(alpha: 0.1),
                  ])
                : null,
            color: canClaim ? null : const Color(0xFF1a1f2e),
            border: Border.all(
              color: canClaim ? const Color(0xFFFFD700).withValues(alpha: 0.5) : const Color(0xFF2a2f40),
              width: canClaim ? 1.5 : 0.5,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: canClaim ? _claimReward : null,
              borderRadius: BorderRadius.circular(14),
              child: Center(
                child: _isClaiming
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Color(0xFFFFD700), strokeWidth: 2))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.card_giftcard,
                            color: canClaim ? const Color(0xFFFFD700) : const Color(0xFF4a5568),
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            canClaim ? 'ПОЛУЧИТЬ НАГРАДУ' : 'ПОЛУЧЕНО',
                            style: TextStyle(
                              color: canClaim ? const Color(0xFFFFD700) : const Color(0xFF4a5568),
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClaimResult(ThemeData theme) {
    final success = _claimResult?['success'] == true;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: success
            ? const Color(0xFF00ff41).withValues(alpha: 0.08)
            : const Color(0xFFFF0040).withValues(alpha: 0.08),
        border: Border.all(
          color: success
              ? const Color(0xFF00ff41).withValues(alpha: 0.3)
              : const Color(0xFFFF0040).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            success ? Icons.check_circle : Icons.error,
            color: success ? const Color(0xFF00ff41) : const Color(0xFFFF0040),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  success ? 'Награда получена!' : (_claimResult?['message'] ?? 'Ошибка'),
                  style: TextStyle(
                    color: success ? const Color(0xFF00ff41) : const Color(0xFFFF0040),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                if (success) ...[
                  const SizedBox(height: 4),
                  Text(
                    '+${_claimResult?['credits']} CR  +${_claimResult?['xp']} XP  |  Стрик: ${_claimResult?['streak']}',
                    style: const TextStyle(color: Color(0xFFFFD700), fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DailyRewardTier {
  final int day;
  final int credits;
  final int xp;

  const DailyRewardTier({required this.day, required this.credits, required this.xp});

  static const tiers = [
    DailyRewardTier(day: 1, credits: 100, xp: 10),
    DailyRewardTier(day: 2, credits: 200, xp: 20),
    DailyRewardTier(day: 3, credits: 300, xp: 30),
    DailyRewardTier(day: 4, credits: 500, xp: 50),
    DailyRewardTier(day: 5, credits: 800, xp: 80),
    DailyRewardTier(day: 6, credits: 1200, xp: 120),
    DailyRewardTier(day: 7, credits: 2000, xp: 250),
  ];
}
