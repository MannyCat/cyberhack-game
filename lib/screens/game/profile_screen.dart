import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/game_provider.dart';
import '../../providers/auth_provider.dart';
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
const _orangeAccent = Color(0xFFFF8C00);

// ── Profile Screen ──────────────────────────────────────────────────────

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _supabase = Supabase.instance.client;

  // ── Helpers ────────────────────────────────────────────────────────────

  String _formatCredits(dynamic value) {
    final v = (value as num?)?.toInt() ?? 0;
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toString();
  }

  /// XP needed to reach the next level (exponential curve).
  int _xpForLevel(int level) {
    return (100 * level * 1.5).round();
  }

  String _getLevelTitle(int level) {
    if (level >= 50) return 'ЛЕГЕНДА';
    if (level >= 40) return 'ЭЛИТА';
    if (level >= 30) return 'МАСТЕР';
    if (level >= 20) return 'ЭКСПЕРТ';
    if (level >= 10) return 'СПЕЦИАЛИСТ';
    if (level >= 5) return 'НОВИЧОК+';
    return 'НОВИЧОК';
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(gameProvider);

    if (game.isLoading || game.profile == null) {
      return const Center(
        child: CircularProgressIndicator(color: _greenPrimary),
      );
    }

    final profile = game.profile!;
    final username = profile['username'] as String? ?? 'Хакер';
    final email = profile['email'] as String? ?? '';
    final level = (profile['level'] as num?)?.toInt() ?? 1;
    final experience = (profile['experience'] as num?)?.toInt() ?? 0;
    final credits = (profile['credits'] as num?)?.toInt() ?? 0;
    final power = (profile['power'] as num?)?.toInt() ?? 0;
    final maxPower = (profile['max_power'] as num?)?.toInt() ?? 200;
    final heat = (profile['heat'] as num?)?.toInt() ?? 0;
    final reputation = (profile['reputation'] as num?)?.toInt() ?? 0;
    final totalEarnings = (profile['total_earnings'] as num?)?.toInt() ?? 0;
    final cpu = (profile['cpu'] as num?)?.toInt() ?? 0;
    final bandwidth = (profile['bandwidth'] as num?)?.toInt() ?? 0;
    final clanId = profile['clan_id'] as String?;

    final nextXp = _xpForLevel(level);
    final xpInLevel = experience % nextXp;
    final progress = (xpInLevel / nextXp).clamp(0.0, 1.0);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Profile Header ──────────────────────────────────────────
              _buildProfileHeader(username, email, level),
              const SizedBox(height: 28),

              // ── Stats Grid ──────────────────────────────────────────────
              const _SectionHeader(title: 'СТАТИСТИКА', icon: Icons.bar_chart),
              const SizedBox(height: 14),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  _buildStatCard(
                    icon: Icons.attach_money,
                    label: 'Кредиты',
                    value: _formatCredits(credits),
                    color: _greenPrimary,
                  ),
                  _buildStatCard(
                    icon: Icons.military_tech,
                    label: 'Уровень',
                    value: '$level',
                    color: _goldAccent,
                  ),
                  _buildStatCard(
                    icon: Icons.star_outline,
                    label: 'Опыт',
                    value: _formatCredits(experience),
                    color: _cyanSecondary,
                  ),
                  _buildStatCard(
                    icon: Icons.bolt,
                    label: 'Энергия',
                    value: '$power / $maxPower',
                    color: _cyanSecondary,
                  ),
                  _buildStatCard(
                    icon: Icons.local_fire_department,
                    label: 'Теплота',
                    value: '$heat',
                    color: _orangeAccent,
                  ),
                  _buildStatCard(
                    icon: Icons.emoji_events_outlined,
                    label: 'Репутация',
                    value: _formatCredits(reputation),
                    color: _goldAccent,
                  ),
                  _buildStatCard(
                    icon: Icons.trending_up,
                    label: 'Общий доход',
                    value: _formatCredits(totalEarnings),
                    color: _greenPrimary,
                  ),
                  _buildStatCard(
                    icon: Icons.memory,
                    label: 'CPU',
                    value: _formatCredits(cpu),
                    color: _cyanSecondary,
                  ),
                  _buildStatCard(
                    icon: Icons.speed,
                    label: 'Пропускная способность',
                    value: _formatCredits(bandwidth),
                    color: _cyanSecondary,
                  ),
                  _buildStatCard(
                    icon: Icons.groups,
                    label: 'Клан',
                    value: clanId != null ? 'В клане' : 'Нет',
                    color: _greenPrimary,
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ── Progress Section ─────────────────────────────────────────
              const _SectionHeader(title: 'ПРОГРЕСС', icon: Icons.auto_graph),
              const SizedBox(height: 14),
              _buildProgressSection(level, xpInLevel, nextXp, progress),
              const SizedBox(height: 28),

              // ── Heat Section (if heat > 0) ──────────────────────────────
              if (heat > 0) ...[
                const _SectionHeader(
                  title: 'ТЕПЛОТА',
                  icon: Icons.local_fire_department,
                ),
                const SizedBox(height: 14),
                _buildHeatSection(heat),
                const SizedBox(height: 28),
              ],

              // ── Logout Button ────────────────────────────────────────────
              CyberButton(
                text: 'ВЫХОД ИЗ АККАУНТА',
                variant: CyberButtonVariant.danger,
                width: double.infinity,
                height: 48,
                onPressed: () async {
                  await ref.read(authProvider.notifier).logout();
                  if (mounted) context.go('/auth/login');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Profile Header ────────────────────────────────────────────────────

  Widget _buildProfileHeader(String username, String email, int level) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _greenPrimary.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: _greenPrimary.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          MouseRegion(
            cursor: SystemMouseCursors.basic,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [_greenPrimary, _greenDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _greenPrimary.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  username.isNotEmpty ? username[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: _bgDark,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ПРОФИЛЬ ОПЕРАТОРА',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  username,
                  style: const TextStyle(
                    color: _greenPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: _goldAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _goldAccent.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        'УР. $level',
                        style: const TextStyle(
                          color: _goldAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _cyanSecondary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _cyanSecondary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        _getLevelTitle(level),
                        style: const TextStyle(
                          color: _cyanSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Stat Card (300x80) ─────────────────────────────────────────────────

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 300,
        height: 80,
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: TextStyle(
                        color: color,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Progress Section ────────────────────────────────────────────────────

  Widget _buildProgressSection(
      int level, int xp, int nextXp, double progress) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _surfaceVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Уровень $level',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Уровень ${level + 1}',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 16,
              child: Stack(
                children: [
                  // Background track
                  Container(
                    decoration: BoxDecoration(
                      color: _surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  // Filled portion
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOut,
                    width: MediaQuery.of(context).size.width * progress,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_greenPrimary, _cyanSecondary],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: _greenPrimary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // XP text
          Center(
            child: Text(
              '$xp / $nextXp до следующего уровня',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Heat Section ───────────────────────────────────────────────────────

  Widget _buildHeatSection(int heat) {
    final heatPercent = (heat / 100.0).clamp(0.0, 1.0);
    Color heatColor;
    if (heat >= 75) {
      heatColor = _dangerRed;
    } else if (heat >= 50) {
      heatColor = _orangeAccent;
    } else {
      heatColor = Colors.amber.shade600;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: heatColor.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: heatColor.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Heat meter with danger zones
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 20,
              child: Stack(
                children: [
                  // Danger zone backgrounds
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: const LinearGradient(
                        stops: [0.0, 0.5, 0.75, 1.0],
                        colors: [
                          Color(0xFF1a2332),
                          Color(0xFF2a1a10),
                          Color(0xFF3a1515),
                          Color(0xFF4a1010),
                        ],
                      ),
                    ),
                  ),
                  // Fill bar
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOut,
                    width: MediaQuery.of(context).size.width * heatPercent,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.amber.shade600,
                          heat >= 50 ? _orangeAccent : Colors.amber.shade700,
                          heat >= 75 ? _dangerRed : _orangeAccent,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  // Zone markers
                  Positioned(
                    left: MediaQuery.of(context).size.width * 0.5 - 1,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 2,
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  Positioned(
                    left: MediaQuery.of(context).size.width * 0.75 - 1,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 2,
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Heat value
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Текущая теплота: $heat / 100',
                style: TextStyle(
                  color: heatColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '-1 каждые 60 секунд',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          // Warning
          if (heat > 50) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _dangerRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _dangerRed.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: _dangerRed, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'ОСТОРОЖНО! Высокий розыск. Более частые провалы!',
                      style: const TextStyle(
                        color: _dangerRed,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
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
