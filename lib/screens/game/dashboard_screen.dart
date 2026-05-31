import 'dart:async';
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
const _cyanSecondary = Color(0xFF00d4ff);
const _goldAccent = Color(0xFFFFD700);
const _dangerRed = Color(0xFFff4444);

// ── Dashboard Screen ─────────────────────────────────────────────────────

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Timer? _countdownTimer;
  final _supabase = Supabase.instance.client;

  // Track which operations are currently completing (to avoid double-clicks)
  final Set<String> _completingOps = {};

  @override
  void initState() {
    super.initState();
    // Tick every second so countdowns update in real time
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _opTypeRu(String type) {
    switch (type) {
      case 'data_theft':
        return 'Кража данных';
      case 'ddos':
        return 'DDoS-атака';
      case 'ransomware':
        return 'Вымогательство';
      case 'espionage':
        return 'Шпионаж';
      case 'crypto_mining':
        return 'Крипто-майнинг';
      case 'identity_theft':
        return 'Кража личности';
      default:
        return type;
    }
  }

  /// Returns a human-readable countdown string for an active operation.
  String _timeRemaining(Map<String, dynamic> op) {
    final completesAt = op['completes_at'] as String?;
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

  /// Whether an operation's timer has expired and can be completed.
  bool _isReady(Map<String, dynamic> op) {
    final completesAt = op['completes_at'] as String?;
    if (completesAt == null) return false;
    return DateTime.now().toUtc().isAfter(DateTime.parse(completesAt));
  }

  String _formatCredits(dynamic value) {
    final v = (value as num?)?.toInt() ?? 0;
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toString();
  }

  String _formatTimestamp(String? iso) {
    if (iso == null) return '—';
    final dt = DateTime.parse(iso).toLocal();
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _completeOperation(Map<String, dynamic> op) async {
    if (_completingOps.contains(op['id'])) return;
    setState(() => _completingOps.add(op['id']));
    try {
      await _supabase.rpc('complete_operation', params: {'p_op_id': op['id']});
      await ref.read(gameProvider.notifier).loadAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Операция завершена: ${_opTypeRu(op['op_type'] ?? '')}'),
            backgroundColor: _greenPrimary,
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
      if (mounted) setState(() => _completingOps.remove(op['id']));
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(gameProvider);

    if (game.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _greenPrimary),
      );
    }

    final profile = game.profile;
    final username = profile?['username'] as String? ?? 'Хакер';
    final level = (profile?['level'] as num?)?.toInt() ?? 1;
    final credits = (profile?['credits'] as num?)?.toInt() ?? 0;
    final power = (profile?['power'] as num?)?.toInt() ?? 0;
    final maxPower = (profile?['max_power'] as num?)?.toInt() ?? 200;
    final reputation = (profile?['reputation'] as num?)?.toInt() ?? 0;
    final heat = (profile?['heat'] as num?)?.toInt() ?? 0;

    final activeOps =
        game.operations.where((o) => o['status'] == 'active').toList();
    final recentOps = game.operations
        .where((o) => o['status'] == 'completed' || o['status'] == 'failed')
        .take(5)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Welcome Header ──────────────────────────────────────────────
          _buildWelcomeHeader(username, level),
          const SizedBox(height: 24),

          // ── Stats Cards ───────────────────────────────────────────────
          _buildStatsCards(
            credits: credits,
            power: power,
            maxPower: maxPower,
            reputation: reputation,
            heat: heat,
          ),
          const SizedBox(height: 28),

          // ── Active Operations ─────────────────────────────────────────
          _buildActiveOperations(activeOps),
          const SizedBox(height: 28),

          // ── Quick Actions ─────────────────────────────────────────────
          _buildQuickActions(),
          const SizedBox(height: 28),

          // ── Recent Activity ─────────────────────────────────────────────
          _buildRecentActivity(recentOps),
        ],
      ),
    );
  }

  // ── Welcome Header ───────────────────────────────────────────────────────

  Widget _buildWelcomeHeader(String username, int level) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ДОБРО ПОЖАЛОВАТЬ,',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '$username!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _greenPrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _greenPrimary.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    'УР. $level',
                    style: const TextStyle(
                      color: _greenPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ── Stats Cards ─────────────────────────────────────────────────────────

  Widget _buildStatsCards({
    required int credits,
    required int power,
    required int maxPower,
    required int reputation,
    required int heat,
  }) {
    return Row(
      children: [
        _StatCard(
          icon: Icons.attach_money,
          label: 'Кредиты',
          value: _formatCredits(credits),
          iconColor: _greenPrimary,
          valueColor: _greenPrimary,
        ),
        const SizedBox(width: 16),
        _StatCard(
          icon: Icons.bolt,
          label: 'Энергия',
          value: '$power/$maxPower',
          iconColor: _cyanSecondary,
          valueColor: _cyanSecondary,
        ),
        const SizedBox(width: 16),
        _StatCard(
          icon: Icons.star,
          label: 'Репутация',
          value: _formatCredits(reputation),
          iconColor: _goldAccent,
          valueColor: _goldAccent,
        ),
        const SizedBox(width: 16),
        _StatCard(
          icon: Icons.local_fire_department,
          label: 'Теплота',
          value: '$heat',
          iconColor: const Color(0xFFFF8C00),
          valueColor: const Color(0xFFFF8C00),
        ),
      ],
    );
  }

  // ── Active Operations ───────────────────────────────────────────────────

  Widget _buildActiveOperations(List<Map<String, dynamic>> activeOps) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'АКТИВНЫЕ ОПЕРАЦИИ', icon: Icons.explore_outlined),
        const SizedBox(height: 12),
        if (activeOps.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _surfaceVariant),
            ),
            child: const Column(
              children: [
                Icon(Icons.hourglass_empty, color: Colors.grey, size: 40),
                SizedBox(height: 12),
                Text(
                  'Нет активных операций. Начните операцию на вкладке \'Операции\'.',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ...activeOps.map((op) => _buildOperationCard(op)),
      ],
    );
  }

  Widget _buildOperationCard(Map<String, dynamic> op) {
    final ready = _isReady(op);
    final isCompleting = _completingOps.contains(op['id']);

    // Extract joined data
    final target = op['targets'] as Map<String, dynamic>?;
    final targetName = target?['name'] as String? ?? 'Неизвестная цель';
    final server = op['player_servers'] as Map<String, dynamic>?;
    final serverName = server?['name'] as String? ?? '—';
    final expectedReward = (op['expected_reward'] as num?)?.toInt() ?? 0;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: ready
              ? _greenPrimary.withValues(alpha: 0.4)
              : _surfaceVariant,
        ),
      ),
      child: Row(
        children: [
          // Left side: operation info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _cyanSecondary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _opTypeRu(op['op_type'] as String? ?? ''),
                        style: const TextStyle(
                          color: _cyanSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      targetName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.dns_outlined,
                        color: Colors.grey.shade500, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Сервер: $serverName',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.attach_money,
                        color: _greenPrimary.withValues(alpha: 0.6), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Награда: ${_formatCredits(expectedReward)}',
                      style: TextStyle(
                        color: _greenPrimary.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Right side: countdown + button
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                ready ? '✅ Готово' : _timeRemaining(op),
                style: TextStyle(
                  color: ready ? _greenPrimary : Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 8),
              ready
                  ? CyberButton(
                      text: 'ЗАВЕРШИТЬ',
                      variant: CyberButtonVariant.primary,
                      height: 34,
                      isLoading: isCompleting,
                      onPressed: () => _completeOperation(op),
                    )
                  : const SizedBox(
                      width: 120,
                      height: 34,
                      child: Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _cyanSecondary,
                          ),
                        ),
                      ),
                    ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Quick Actions ───────────────────────────────────────────────────────

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'БЫСТРЫЕ ДЕЙСТВИЯ', icon: Icons.flash_on),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: CyberButton(
                text: 'Новая операция',
                icon: Icons.explore,
                variant: CyberButtonVariant.primary,
                height: 48,
                onPressed: () => context.go('/game/operations'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: CyberButton(
                text: 'Купить сервер',
                icon: Icons.dns_outlined,
                variant: CyberButtonVariant.secondary,
                height: 48,
                onPressed: () => context.go('/game/servers'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: CyberButton(
                text: 'Нанять агента',
                icon: Icons.person_add,
                variant: CyberButtonVariant.secondary,
                height: 48,
                onPressed: () => context.go('/game/agents'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Recent Activity ─────────────────────────────────────────────────────

  Widget _buildRecentActivity(List<Map<String, dynamic>> recentOps) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'ПОСЛЕДНЯЯ АКТИВНОСТЬ', icon: Icons.history),
        const SizedBox(height: 12),
        if (recentOps.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _surfaceVariant),
            ),
            child: const Center(
              child: Text(
                'Ещё нет завершённых операций.',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),
          )
        else
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _surfaceVariant),
            ),
            child: Column(
              children: recentOps.asMap().entries.map((entry) {
                final idx = entry.key;
                final op = entry.value;
                final isCompleted = op['status'] == 'completed';
                final actualReward =
                    (op['actual_reward'] as num?)?.toInt() ?? 0;

                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: idx < recentOps.length - 1
                        ? const Border(
                            bottom: BorderSide(color: _surfaceVariant),
                          )
                        : null,
                  ),
                  child: Row(
                    children: [
                      // Status icon
                      Icon(
                        isCompleted ? Icons.check_circle : Icons.cancel,
                        color: isCompleted ? _greenPrimary : _dangerRed,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      // Operation info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _opTypeRu(op['op_type'] as String? ?? ''),
                              style: TextStyle(
                                color: isCompleted
                                    ? Colors.white
                                    : Colors.grey.shade400,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatTimestamp(op['completed_at'] as String?),
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Result
                      isCompleted
                          ? Text(
                              '+${_formatCredits(actualReward)}',
                              style: const TextStyle(
                                color: _greenPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : const Text(
                              'Провалено',
                              style: TextStyle(
                                color: _dangerRed,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

// ── Stat Card Widget ──────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;
  final Color valueColor;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: MouseRegion(
        cursor: SystemMouseCursors.basic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 100,
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: iconColor.withValues(alpha: 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: iconColor.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: iconColor, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    fontFeatures: const [FontFeature.tabularFigures()],
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

// ── Section Header ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _greenPrimary, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 1,
            color: _surfaceVariant,
          ),
        ),
      ],
    );
  }
}
