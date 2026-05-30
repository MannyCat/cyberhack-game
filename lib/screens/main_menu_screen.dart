import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/game_provider.dart';
import '../providers/event_provider.dart';
import '../providers/tutorial_provider.dart';
import '../config/game_config.dart';

// ═══════════════════════════════════════════════════════════════════════════
// CYBERHACK — Главное меню (PC Desktop Layout)
// Wide layout · maxWidth 1100 · Cyberpunk aesthetic · Russian UI
// ═══════════════════════════════════════════════════════════════════════════

const _bgDark = Color(0xFF0a0e17);
const _bgCard = Color(0xFF111827);
const _neonCyan = Color(0xFF00F0FF);
const _neonGreen = Color(0xFF00ff41);
const _neonRed = Color(0xFFFF0040);
const _neonPurple = Color(0xFFa855f7);
const _neonGold = Color(0xFFFFD700);
const _neonOrange = Color(0xFFff9800);
const _neonPink = Color(0xFFe91e63);
const _muted = Color(0xFF4a5568);

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.userId != null) {
        context.read<GameProvider>().init(auth.userId!);
      }
    });
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _rankTitle(int level) {
    if (level >= 50) return 'Легенда';
    if (level >= 40) return 'Мастер';
    if (level >= 30) return 'Ветеран';
    if (level >= 20) return 'Оперативник';
    if (level >= 10) return 'Специалист';
    return 'Новичок';
  }

  Color _rankColor(int level) {
    if (level >= 50) return _neonGold;
    if (level >= 40) return _neonCyan;
    if (level >= 30) return _neonPurple;
    if (level >= 20) return _neonGreen;
    if (level >= 10) return _neonOrange;
    return _muted;
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final game = context.watch<GameProvider>();

    final username = auth.displayName;
    final level = game.level;
    final credits = game.credits;
    final xp = game.xp;
    final xpNeeded = ProgressionConfig.xpRequiredForLevel(level);
    final xpPercent =
        xpNeeded > 0 ? (xp / xpNeeded).clamp(0.0, 1.0) : 0.0;
    final onlineNodes =
        game.networkNodes.where((n) => n.isOnline).length;
    final totalNodes = game.networkNodes.length;
    final income = game.passiveIncomePerTick;

    return Scaffold(
      backgroundColor: _bgDark,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              children: [
                // ═══ HERO SECTION ═══════════════════════════════════════════
                _HeroSection(glowAnimation: _glowAnimation),

                const SizedBox(height: 20),

                // ═══ HINTS / WARNINGS ══════════════════════════════════════
                if (totalNodes == 0)
                  _NewPlayerHint()
                else if (onlineNodes == 0)
                  _OfflineNodesWarning(nodeCount: totalNodes),

                // ═══ MAIN TWO-COLUMN LAYOUT ════════════════════════════════
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── LEFT: Menu Buttons (wide, ~68%) ──────────────────
                    Expanded(
                      flex: 7,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Primary actions (2 wide cards side by side)
                          _sectionLabel('ОПЕРАЦИИ'),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _MenuButton(
                                  icon: Icons.dns_rounded,
                                  label: 'МОЯ БАЗА',
                                  subtitle: onlineNodes > 0
                                      ? '$onlineNodes / $totalNodes узлов онлайн'
                                      : 'Построй первый узел!',
                                  color: _neonGreen,
                                  onTap: () =>
                                      context.go('/game/network'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _MenuButton(
                                  icon: Icons.gps_fixed_rounded,
                                  label: 'АТАКА',
                                  subtitle:
                                      game.availableTargets.isNotEmpty
                                          ? '${game.availableTargets.length} целей доступно'
                                          : 'Поиск целей...',
                                  color: _neonRed,
                                  onTap: () =>
                                      context.go('/game/attack'),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),
                          _sectionLabel('ЗАДАЧИ И МИР'),
                          const SizedBox(height: 10),

                          // Wide cards stacked vertically
                          _MenuButton(
                            icon: Icons.card_giftcard_rounded,
                            label: 'ЕЖЕДНЕВНАЯ НАГРАДА',
                            subtitle: 'Забирайте награду — стрик-бонусы растут',
                            color: _neonGold,
                            onTap: () => context.go('/game/daily-reward'),
                          ),
                          const SizedBox(height: 10),
                          _MenuButton(
                            icon: Icons.military_tech_rounded,
                            label: 'МИССИИ',
                            subtitle: 'PvE кампания — пройди все уровни',
                            color: _neonGold,
                            onTap: () => context.go('/game/campaign'),
                          ),
                          const SizedBox(height: 10),
                          _MenuButton(
                            icon: Icons.public_rounded,
                            label: 'КАРТА МИРА',
                            subtitle: 'Глобальная сеть — исследуй территорию',
                            color: _neonCyan,
                            onTap: () => context.go('/game/map'),
                          ),

                          const SizedBox(height: 20),
                          _sectionLabel('АЛЬЯНС И КОММУНИКАЦИЯ'),
                          const SizedBox(height: 10),

                          _MenuButton(
                            icon: Icons.groups_rounded,
                            label: 'БАНДА',
                            subtitle: 'Создай или вступи в клан',
                            color: _neonPurple,
                            onTap: () => context.go('/game/clan'),
                          ),
                          const SizedBox(height: 10),
                          _MenuButton(
                            icon: Icons.chat_bubble_rounded,
                            label: 'ЧАТ',
                            subtitle: 'Общий и клановый чат',
                            color: _neonCyan,
                            onTap: () => context.go('/game/chat'),
                          ),
                          const SizedBox(height: 10),
                          _MenuButton(
                            icon: Icons.emoji_events_rounded,
                            label: 'РЕЙТИНГ',
                            subtitle: 'Лучшие хакеры мира',
                            color: _neonPink,
                            onTap: () =>
                                context.go('/game/leaderboard'),
                          ),

                          const SizedBox(height: 20),
                          _sectionLabel('РЫНОК И УТИЛИТЫ'),
                          const SizedBox(height: 10),

                          _MenuButton(
                            icon: Icons.storefront_rounded,
                            label: 'ЧЁРНЫЙ РЫНОК',
                            subtitle: 'Снаряжение, софт и апгрейды',
                            color: _neonOrange,
                            onTap: () => context.go('/game/market'),
                          ),
                          const SizedBox(height: 10),
                          _MenuButton(
                            icon: Icons.shield_rounded,
                            label: 'ОБОРОНА СЕТИ',
                            subtitle: 'Защита и мониторинг базы',
                            color: _neonRed,
                            onTap: () => context.go('/game/network'),
                          ),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),

                    const SizedBox(width: 24),

                    // ── RIGHT: Side Panel (~32%) ────────────────────────────
                    Expanded(
                      flex: 3,
                      child: _SidePanel(
                        username: username,
                        level: level,
                        rankTitle: _rankTitle(level),
                        rankColor: _rankColor(level),
                        xpPercent: xpPercent,
                        xp: xp,
                        xpNeeded: xpNeeded,
                        credits: credits,
                        onlineNodes: onlineNodes,
                        totalNodes: totalNodes,
                        income: income,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ═══ FOOTER ROW: Tutorial + Events Banners ═════════════════
                Row(
                  children: [
                    Expanded(child: _TutorialBanner()),
                    const SizedBox(width: 12),
                    Expanded(child: _ActiveEventsBanner()),
                  ],
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Section Label ─────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: _muted,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 2.5,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HERO SECTION — Animated glow title
// ═══════════════════════════════════════════════════════════════════════════

class _HeroSection extends StatelessWidget {
  final Animation<double> glowAnimation;
  const _HeroSection({required this.glowAnimation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: glowAnimation,
      builder: (context, child) {
        final glowOpacity = glowAnimation.value;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 40),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_bgCard, Color(0xFF0d1220)],
            ),
            border: Border.all(
              color: _neonCyan.withValues(alpha: 0.15 + glowOpacity * 0.15),
            ),
            boxShadow: [
              BoxShadow(
                color: _neonCyan.withValues(alpha: 0.04 + glowOpacity * 0.08),
                blurRadius: 40 + glowOpacity * 20,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: _neonPurple.withValues(alpha: glowOpacity * 0.05),
                blurRadius: 60,
                spreadRadius: -10,
              ),
            ],
          ),
          child: Column(
            children: [
              // Scanline decoration
              Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      _neonCyan.withValues(alpha: 0.3 + glowOpacity * 0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Title
              ShaderMask(
                shaderCallback: (bounds) {
                  return LinearGradient(
                    colors: [
                      _neonCyan,
                      _neonCyan.withValues(alpha: 0.6 + glowOpacity * 0.4),
                      _neonPurple.withValues(alpha: 0.8),
                    ],
                  ).createShader(bounds);
                },
                child: const Text(
                  'CYBERHACK',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 52,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Subtitle
              Text(
                'КОМАНДНЫЙ ЦЕНТР ХАКЕРА',
                style: TextStyle(
                  color: _neonCyan.withValues(alpha: 0.35 + glowOpacity * 0.2),
                  fontSize: 14,
                  letterSpacing: 4,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              // Tagline
              Text(
                'Взламывай. Строй. Завоевывай.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.25),
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
              // Bottom scanline
              const SizedBox(height: 24),
              Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      _neonPurple.withValues(alpha: 0.15 + glowOpacity * 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SIDE PANEL — Player quick info + quick actions
// ═══════════════════════════════════════════════════════════════════════════

class _SidePanel extends StatelessWidget {
  final String username;
  final int level;
  final String rankTitle;
  final Color rankColor;
  final double xpPercent;
  final int xp;
  final int xpNeeded;
  final int credits;
  final int onlineNodes;
  final int totalNodes;
  final int income;

  const _SidePanel({
    required this.username,
    required this.level,
    required this.rankTitle,
    required this.rankColor,
    required this.xpPercent,
    required this.xp,
    required this.xpNeeded,
    required this.credits,
    required this.onlineNodes,
    required this.totalNodes,
    required this.income,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Player Card ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_bgCard, Color(0xFF0d1220)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: rankColor.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: rankColor.withValues(alpha: 0.06),
                blurRadius: 24,
              ),
            ],
          ),
          child: Column(
            children: [
              // Avatar
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [rankColor, rankColor.withValues(alpha: 0.4)],
                  ),
                  border:
                      Border.all(color: rankColor.withValues(alpha: 0.5), width: 2),
                ),
                child: Center(
                  child: Text(
                    username.isNotEmpty
                        ? username
                            .substring(0, min(2, username.length))
                            .toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: _bgDark,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Name
              Text(
                username.isEmpty ? 'Хакер' : username,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              // Level + Rank
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: rankColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'УР $level',
                      style: TextStyle(
                        color: rankColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    rankTitle,
                    style: TextStyle(
                      color: rankColor.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // XP bar
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ОПЫТ',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 10,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        '$xp / $xpNeeded',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: xpPercent,
                      minHeight: 8,
                      backgroundColor: const Color(0xFF0d1117),
                      valueColor: AlwaysStoppedAnimation<Color>(rankColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // Divider
              Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      rankColor.withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Credits
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.monetization_on, color: _neonGold, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    '$credits',
                    style: const TextStyle(
                      color: _neonGold,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'КРЕДИТОВ',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 10,
                  letterSpacing: 1.5,
                ),
              ),
              if (income > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '+$income / 30с',
                  style: TextStyle(
                    color: _neonGreen.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              // Nodes
              Container(
                height: 1,
                color: Colors.white.withValues(alpha: 0.04),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.dns_rounded,
                    color:
                        onlineNodes > 0 ? _neonCyan : _muted,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$onlineNodes / $totalNodes',
                    style: TextStyle(
                      color: onlineNodes > 0 ? _neonCyan : _muted,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              const Text(
                'УЗЛОВ',
                style: TextStyle(
                  color: _muted,
                  fontSize: 10,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Quick Action: Profile ──
        _SideButton(
          icon: Icons.person_rounded,
          label: 'ПРОФИЛЬ',
          subtitle: 'Статистика и достижения',
          color: const Color(0xFF78909c),
          onTap: () => context.go('/profile'),
        ),
        const SizedBox(height: 10),

        // ── Quick Action: Settings ──
        _SideButton(
          icon: Icons.settings_rounded,
          label: 'НАСТРОЙКИ',
          subtitle: 'Аккаунт и оформление',
          color: _muted,
          onTap: () => context.go('/settings'),
        ),
        const SizedBox(height: 10),

        // ── Quick Action: Tutorial ──
        _SideButton(
          icon: Icons.school_rounded,
          label: 'ОБУЧЕНИЕ',
          subtitle: 'Как играть',
          color: _neonCyan,
          onTap: () => context.go('/tutorial'),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SIDE BUTTON — Compact vertical button for the side panel
// ═══════════════════════════════════════════════════════════════════════════

class _SideButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _SideButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  State<_SideButton> createState() => _SideButtonState();
}

class _SideButtonState extends State<_SideButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: _hover
                ? widget.color.withValues(alpha: 0.08)
                : const Color(0xFF111827),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.color.withValues(alpha: _hover ? 0.35 : 0.12),
              width: _hover ? 1.5 : 1,
            ),
            boxShadow: _hover
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.1),
                      blurRadius: 12,
                    )
                  ]
                : [],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: _hover ? 0.18 : 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: widget.color.withValues(alpha: _hover ? 0.4 : 0.15),
                  ),
                ),
                child: Icon(widget.icon, color: widget.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: TextStyle(
                        color: widget.color.withValues(alpha: 0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: widget.color.withValues(alpha: _hover ? 0.7 : 0.25),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MENU BUTTON — Wide horizontal card for the main menu area
// ═══════════════════════════════════════════════════════════════════════════

class _MenuButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _bgCard,
                _hover
                    ? widget.color.withValues(alpha: 0.08)
                    : const Color(0xFF0d1220),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.color.withValues(alpha: _hover ? 0.5 : 0.15),
              width: _hover ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: _hover ? 0.15 : 0.03),
                blurRadius: _hover ? 24 : 8,
                spreadRadius: _hover ? 3 : 1,
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color:
                      widget.color.withValues(alpha: _hover ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color:
                        widget.color.withValues(alpha: _hover ? 0.5 : 0.2),
                    width: 1.5,
                  ),
                ),
                child: Icon(widget.icon, color: widget.color, size: 26),
              ),
              const SizedBox(width: 18),
              // Label + Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: TextStyle(
                        color: widget.color,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Arrow indicator
              AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: _hover ? 0.8 : 0.2,
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: widget.color,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TUTORIAL BANNER
// ═══════════════════════════════════════════════════════════════════════════

class _TutorialBanner extends StatefulWidget {
  @override
  State<_TutorialBanner> createState() => _TutorialBannerState();
}

class _TutorialBannerState extends State<_TutorialBanner> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final tutorial = context.watch<TutorialProvider>();
    if (tutorial.isCompleted) return const SizedBox.shrink();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => context.go('/tutorial'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _neonCyan.withValues(alpha: _hover ? 0.12 : 0.08),
                _neonGreen.withValues(alpha: 0.03),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _neonCyan.withValues(alpha: _hover ? 0.5 : 0.25),
            ),
            boxShadow: _hover
                ? [
                    BoxShadow(
                      color: _neonCyan.withValues(alpha: 0.12),
                      blurRadius: 20,
                    )
                  ]
                : [],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _neonCyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _neonCyan.withValues(alpha: 0.3)),
                ),
                child:
                    const Icon(Icons.school_rounded, color: _neonCyan, size: 22),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ПРОЙДИТЕ ОБУЧЕНИЕ',
                      style: TextStyle(
                        color: _neonCyan,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      'Узнайте как строить базу, атаковать и зарабатывать кредиты.',
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: _neonCyan.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: _neonCyan.withValues(alpha: 0.35)),
                ),
                child: const Text(
                  'НАЧАТЬ',
                  style: TextStyle(
                    color: _neonCyan,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ACTIVE EVENTS BANNER
// ═══════════════════════════════════════════════════════════════════════════

class _ActiveEventsBanner extends StatefulWidget {
  @override
  State<_ActiveEventsBanner> createState() => _ActiveEventsBannerState();
}

class _ActiveEventsBannerState extends State<_ActiveEventsBanner> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final eventProvider = context.watch<EventProvider>();
    final eventCount = eventProvider.activeEvents.length;
    if (eventCount == 0) return const SizedBox.shrink();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => context.go('/game/events'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _neonCyan.withValues(alpha: _hover ? 0.12 : 0.08),
                _neonPurple.withValues(alpha: 0.03),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _neonCyan.withValues(alpha: _hover ? 0.5 : 0.25),
            ),
            boxShadow: _hover
                ? [
                    BoxShadow(
                      color: _neonCyan.withValues(alpha: 0.12),
                      blurRadius: 20,
                    )
                  ]
                : [],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _neonCyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _neonCyan.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.event_rounded, color: _neonCyan, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'СОБЫТИЯ НЕДЕЛИ',
                          style: TextStyle(
                            color: _neonCyan,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: _neonRed.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$eventCount активно',
                            style: const TextStyle(
                              color: _neonRed,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      eventCount == 1
                          ? 'Текущее: ${eventProvider.activeEvents.first.typeLabel}'
                          : '$eventCount события ждут вашего участия',
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: _neonCyan.withValues(alpha: _hover ? 0.7 : 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HINTS — New Player & Offline Nodes
// ═══════════════════════════════════════════════════════════════════════════

class _NewPlayerHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => context.go('/game/network'),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            decoration: BoxDecoration(
              color: _neonOrange.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _neonOrange.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_rounded, color: _neonOrange, size: 22),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Добро пожаловать, хакер!',
                        style: TextStyle(
                          color: _neonOrange,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Начни с постройки базы — открой «Моя база» и разверни первый узел.',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: _neonOrange.withValues(alpha: 0.6),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OfflineNodesWarning extends StatelessWidget {
  final int nodeCount;
  const _OfflineNodesWarning({required this.nodeCount});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => context.go('/game/network'),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            decoration: BoxDecoration(
              color: _neonRed.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _neonRed.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_rounded, color: _neonRed, size: 22),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Все узлы офлайн!',
                        style: TextStyle(
                          color: _neonRed,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Доход приостановлен. Перезагрузите узлы в базе.',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.power_settings_new_rounded,
                  color: _neonRed.withValues(alpha: 0.6),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


