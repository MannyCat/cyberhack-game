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

    return Scaffold(
      backgroundColor: const Color(0xFF0a0e17),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Page Title ──
                Row(
                  children: [
                    const Icon(Icons.card_giftcard, color: Color(0xFFFFD700), size: 28),
                    const SizedBox(width: 12),
                    const Text(
                      'ЕЖЕДНЕВНАЯ НАГРАДА',
                      style: TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_fire_department, color: Color(0xFFFFD700), size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Стрик ${state.currentStreak}',
                            style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // ── Header Card ──
                _buildHeaderCard(state),
                const SizedBox(height: 28),

                // ── Week Calendar ──
                const Text('НЕДЕЛЯ', style: TextStyle(color: Color(0xFF4a5568), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 3)),
                const SizedBox(height: 14),
                _buildWeekCalendar(state),
                const SizedBox(height: 28),

                // ── Streak Stats ──
                _buildStreakStats(state),
                const SizedBox(height: 28),

                // ── Claim Button ──
                _buildClaimButton(state),

                // ── Claim Result ──
                if (_claimResult != null) ...[
                  const SizedBox(height: 20),
                  _buildClaimResult(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(DailyRewardState state) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, _) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.4)),
                  ),
                  child: const Center(
                    child: Text('\u{1F381}', style: TextStyle(fontSize: 32)),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ЕЖЕДНЕВНАЯ НАГРАДА',
                  style: TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  state.canClaimToday
                      ? 'Награда за сегодня доступна!'
                      : 'Награда уже получена. Приходите завтра!',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekCalendar(DailyRewardState state) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFF0d1220),
        border: Border.all(color: const Color(0xFF1e293b)),
      ),
      child: Row(
        children: List.generate(7, (index) {
          final day = index + 1;
          final tier = DailyRewardTier.tiers[index];
          final isCurrentDay = DateTime.now().weekday == day;
          final isCompleted = day <= state.currentStreak;
          final isNextDay = isCurrentDay && state.canClaimToday;

          return Expanded(
            child: Column(
              children: [
                // Day label
                Text(
                  ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС'][index],
                  style: TextStyle(
                    color: isCurrentDay ? const Color(0xFFFFD700) : const Color(0xFF4a5568),
                    fontSize: 11,
                    fontWeight: isCurrentDay ? FontWeight.bold : FontWeight.normal,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 10),
                // Day box
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
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
                        ? const Icon(Icons.check, color: Color(0xFFFFD700), size: 22)
                        : isNextDay
                            ? AnimatedBuilder(
                                animation: _pulseAnimation,
                                builder: (context, _) {
                                  return Icon(
                                    Icons.card_giftcard,
                                    color: const Color(0xFFFFD700)
                                        .withValues(alpha: 0.5 + _pulseAnimation.value * 0.5),
                                    size: 22,
                                  );
                                },
                              )
                            : Text(
                                '$day',
                                style: const TextStyle(color: Color(0xFF3a4060), fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                  ),
                ),
                const SizedBox(height: 8),
                // Credits
                Text(
                  '${tier.credits}',
                  style: TextStyle(
                    color: isCompleted ? const Color(0xFFFFD700) : const Color(0xFF4a5568),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${tier.xp} XP',
                  style: TextStyle(
                    color: isCompleted ? const Color(0xFFFFD700).withValues(alpha: 0.6) : const Color(0xFF3a4060),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStreakStats(DailyRewardState state) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFF0d1220),
        border: Border.all(color: const Color(0xFF1e293b)),
      ),
      child: Column(
        children: [
          const Text('СТАТИСТИКА СТРИКА', style: TextStyle(color: Color(0xFF4a5568), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 3)),
          const SizedBox(height: 16),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(child: _statItem('Текущий', '${state.currentStreak} дн.', const Color(0xFFFFD700))),
                VerticalDivider(width: 1, color: const Color(0xFF1e293b), thickness: 1),
                Expanded(child: _statItem('Лучший', '${state.bestStreak} дн.', const Color(0xFF00ff41))),
                VerticalDivider(width: 1, color: const Color(0xFF1e293b), thickness: 1),
                Expanded(child: _statItem('Всего', '${state.totalClaimed}', const Color(0xFF00e5ff))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 26, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Color(0xFF4a5568), fontSize: 12)),
      ],
    );
  }

  Widget _buildClaimButton(DailyRewardState state) {
    final canClaim = state.canClaimToday && !_isClaiming;

    return MouseRegion(
      cursor: canClaim ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: canClaim ? _claimReward : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: canClaim
                ? LinearGradient(colors: [
                    const Color(0xFFFFD700).withValues(alpha: 0.2),
                    const Color(0xFFff9800).withValues(alpha: 0.1),
                  ])
                : null,
            color: canClaim ? null : const Color(0xFF0d1220),
            border: Border.all(
              color: canClaim ? const Color(0xFFFFD700).withValues(alpha: 0.5) : const Color(0xFF1e293b),
              width: canClaim ? 1.5 : 0.5,
            ),
          ),
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
                      const SizedBox(width: 10),
                      Text(
                        canClaim ? 'ПОЛУЧИТЬ НАГРАДУ' : 'ПОЛУЧЕНО',
                        style: TextStyle(
                          color: canClaim ? const Color(0xFFFFD700) : const Color(0xFF4a5568),
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildClaimResult() {
    final success = _claimResult?['success'] == true;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
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
            size: 28,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  success ? 'Награда получена!' : (_claimResult?['message'] ?? 'Ошибка'),
                  style: TextStyle(
                    color: success ? const Color(0xFF00ff41) : const Color(0xFFFF0040),
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                if (success) ...[
                  const SizedBox(height: 6),
                  Text(
                    '+${_claimResult?['credits']} CR  +${_claimResult?['xp']} XP  |  Стрик: ${_claimResult?['streak']}',
                    style: const TextStyle(color: Color(0xFFFFD700), fontSize: 13),
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
