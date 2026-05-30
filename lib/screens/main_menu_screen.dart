import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/game_provider.dart';
import '../providers/event_provider.dart';
import '../config/game_config.dart';

// ─── PC Layout — Командный центр в стиле Vikings ────────────────────────────

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.userId != null) {
        context.read<GameProvider>().init(auth.userId!);
      }
    });
  }

  String _rankTitle(int level) {
    if (level >= 50) return 'Легенда';
    if (level >= 40) return 'Мастер';
    if (level >= 30) return 'Ветеран';
    if (level >= 20) return 'Оперативник';
    if (level >= 10) return 'Специалист';
    return 'Новичок';
  }

  Color _rankColor(int level) {
    if (level >= 50) return const Color(0xFFFFD700);
    if (level >= 40) return const Color(0xFF00F0FF);
    if (level >= 30) return const Color(0xFFa855f7);
    if (level >= 20) return const Color(0xFF00ff41);
    if (level >= 10) return const Color(0xFFff9800);
    return const Color(0xFF4a5568);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final game = context.watch<GameProvider>();

    final username = auth.displayName;
    final level = game.level;
    final credits = game.credits;
    final xp = game.xp;
    final xpNeeded = ProgressionConfig.xpRequiredForLevel(level);
    final xpPercent = xpNeeded > 0 ? (xp / xpNeeded).clamp(0.0, 1.0) : 0.0;
    final onlineNodes = game.networkNodes.where((n) => n.isOnline).length;
    final totalNodes = game.networkNodes.length;
    final income = game.passiveIncomePerTick;

    return Scaffold(
      backgroundColor: const Color(0xFF0a0e17),
      body: Container(
        constraints: const BoxConstraints(minWidth: 900),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Title ──
              const Text('КОМАНДНЫЙ ЦЕНТР',
                style: TextStyle(color: Color(0xFF00F0FF), fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 4, fontFamily: 'monospace')),
              const SizedBox(height: 4),
              Text('Управление сетью и операциями',
                style: TextStyle(color: const Color(0xFF00F0FF).withValues(alpha: 0.4), fontSize: 13, letterSpacing: 1)),
              const SizedBox(height: 20),

              // ── Wide Player Card ──
              _PCPlayerCard(
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

              const SizedBox(height: 12),

              // ── Hints ──
              if (totalNodes == 0) _NewPlayerHint(),
              if (totalNodes > 0 && onlineNodes == 0) _OfflineNodesWarning(nodeCount: totalNodes),

              // ── Primary Actions Row: Моя база + Атака ──
              const SizedBox(height: 20),
              _sectionTitle('ОПЕРАЦИИ'),
              const SizedBox(height: 12),
              _buildPrimaryActions(game),

              // ── Banners ──
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _DailyRewardBanner()),
                  const SizedBox(width: 12),
                  Expanded(child: _ActiveEventsBanner()),
                ],
              ),

              // ── Action Grid (4 columns) ──
              const SizedBox(height: 24),
              _sectionTitle('ЗАДАЧИ'),
              const SizedBox(height: 12),
              _PCActionGrid(children: [
                _PCActionCard(icon: Icons.card_giftcard, label: 'Ежедневная награда', subtitle: 'Стрик-бонусы', color: const Color(0xFFFFD700), onTap: () => context.go('/game/daily-reward')),
                _PCActionCard(icon: Icons.military_tech, label: 'Миссии', subtitle: 'PvE кампания', color: const Color(0xFFFFD700), onTap: () => context.go('/game/campaign')),
                _PCActionCard(icon: Icons.public, label: 'Карта мира', subtitle: 'Глобальная сеть', color: const Color(0xFF00e5ff), onTap: () => context.go('/game/map')),
                _PCActionCard(icon: Icons.person, label: 'Профиль', subtitle: 'Статистика', color: const Color(0xFF78909c), onTap: () => context.go('/profile')),
              ]),

              const SizedBox(height: 12),
              _sectionTitle('АЛЬЯНС'),
              const SizedBox(height: 12),
              _PCActionGrid(children: [
                _PCActionCard(icon: Icons.event, label: 'События недели', subtitle: 'Турниры и рейды', color: const Color(0xFF00e5ff), onTap: () => context.go('/game/events')),
                _PCActionCard(icon: Icons.emoji_events, label: 'Достижения', subtitle: 'Награды за прогресс', color: const Color(0xFFa855f7), onTap: () => context.go('/game/achievements')),
                _PCActionCard(icon: Icons.chat_bubble, label: 'Связь', subtitle: 'Общий и клановый чат', color: const Color(0xFF00e5ff), onTap: () => context.go('/game/chat')),
                _PCActionCard(icon: Icons.groups, label: 'Банда', subtitle: 'Создай или вступи', color: const Color(0xFFa855f7), onTap: () => context.go('/game/clan')),
              ]),

              const SizedBox(height: 12),
              _PCActionGrid(children: [
                _PCActionCard(icon: Icons.leaderboard, label: 'Рейтинг', subtitle: 'Лучшие хакеры мира', color: const Color(0xFFe91e63), onTap: () => context.go('/game/leaderboard')),
                _PCActionCard(icon: Icons.storefront, label: 'Чёрный рынок', subtitle: 'Снаряжение и софт', color: const Color(0xFFff9800), onTap: () => context.go('/game/market')),
                _PCActionCard(icon: Icons.shield, label: 'Оборона', subtitle: 'Защита базы', color: const Color(0xFFFF0040), onTap: () => context.go('/game/network')),
                _PCActionCard(icon: Icons.settings, label: 'Настройки', subtitle: 'Аккаунт и оформление', color: const Color(0xFF4a5568), onTap: () => context.go('/settings')),
              ]),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryActions(GameProvider game) {
    final onlineNodes = game.networkNodes.where((n) => n.isOnline).length;
    final totalNodes = game.networkNodes.length;

    return Row(
      children: [
        Expanded(
          child: _PCPrimaryActionCard(
            icon: Icons.account_tree,
            label: 'МОЯ БАЗА',
            subtitle: onlineNodes > 0 ? '$onlineNodes/$totalNodes узлов онлайн' : 'Построй первый узел!',
            color: const Color(0xFF00ff41),
            glowColor: const Color(0xFF00ff41).withValues(alpha: 0.15),
            onTap: () => context.go('/game/network'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _PCPrimaryActionCard(
            icon: Icons.gps_fixed,
            label: 'АТАКА',
            subtitle: game.availableTargets.isNotEmpty ? '${game.availableTargets.length} целей доступно' : 'Поиск целей...',
            color: const Color(0xFFFF0040),
            glowColor: const Color(0xFFFF0040).withValues(alpha: 0.15),
            onTap: () => context.go('/game/attack'),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Text(text,
      style: const TextStyle(color: Color(0xFF4a5568), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 2),
    );
  }
}

// ─── PC Primary Action Card (wide horizontal button) ──────────────────────

class _PCPrimaryActionCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final Color glowColor;
  final VoidCallback onTap;

  const _PCPrimaryActionCard({
    required this.icon, required this.label, required this.subtitle,
    required this.color, required this.glowColor, required this.onTap,
  });

  @override
  State<_PCPrimaryActionCard> createState() => _PCPrimaryActionCardState();
}

class _PCPrimaryActionCardState extends State<_PCPrimaryActionCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF111827),
                _hover ? widget.glowColor.withValues(alpha: 0.25) : widget.glowColor,
              ],
            ),
            border: Border.all(color: widget.color.withValues(alpha: _hover ? 0.6 : 0.3), width: _hover ? 2 : 1.5),
            boxShadow: [
              BoxShadow(
                color: widget.glowColor,
                blurRadius: _hover ? 30.0 : 20.0,
                spreadRadius: _hover ? 4.0 : 2.0,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: _hover ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: widget.color.withValues(alpha: _hover ? 0.5 : 0.3), width: 1.5),
                ),
                child: Icon(widget.icon, color: widget.color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.label,
                      style: TextStyle(color: widget.color, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 2)),
                    const SizedBox(height: 4),
                    Text(widget.subtitle,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: widget.color.withValues(alpha: _hover ? 0.8 : 0.3), size: 28),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── PC Player Card (wide horizontal) ───────────────────────────────────────

class _PCPlayerCard extends StatelessWidget {
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

  const _PCPlayerCard({
    required this.username, required this.level, required this.rankTitle,
    required this.rankColor, required this.xpPercent, required this.xp,
    required this.xpNeeded, required this.credits, required this.onlineNodes,
    required this.totalNodes, required this.income,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF111827), Color(0xFF0d1220)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00ff41).withValues(alpha: 0.15)),
        boxShadow: [BoxShadow(color: const Color(0xFF00ff41).withValues(alpha: 0.06), blurRadius: 24)],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [rankColor, rankColor.withValues(alpha: 0.5)]),
              border: Border.all(color: rankColor.withValues(alpha: 0.5), width: 2),
            ),
            child: Center(
              child: Text(
                username.isNotEmpty ? username.substring(0, min(2, username.length)).toUpperCase() : '?',
                style: const TextStyle(color: Color(0xFF0a0e17), fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 20),
          // Name + Rank
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(username.isEmpty ? 'Хакер' : username,
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: rankColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                      child: Text('УР $level', style: TextStyle(color: rankColor, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Text(rankTitle, style: TextStyle(color: rankColor.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                // XP Bar
                Row(
                  children: [
                    const Text('ОПЫТ', style: TextStyle(color: Color(0xFF4a5568), fontSize: 10, letterSpacing: 1)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: xpPercent, minHeight: 8,
                          backgroundColor: const Color(0xFF0d1117),
                          valueColor: AlwaysStoppedAnimation<Color>(rankColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('$xp / $xpNeeded', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          // Credits
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.monetization_on, color: Color(0xFFFFD700), size: 20),
                  const SizedBox(width: 6),
                  Text('$credits', style: const TextStyle(color: Color(0xFFFFD700), fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
              Text(income > 0 ? '+$income/30с' : 'кредитов',
                style: TextStyle(color: income > 0 ? const Color(0xFF00ff41).withValues(alpha: 0.6) : const Color(0xFF4a5568), fontSize: 11)),
            ],
          ),
          const SizedBox(width: 24),
          // Nodes
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.dns, color: onlineNodes > 0 ? const Color(0xFF00e5ff) : const Color(0xFF4a5568), size: 24),
              const SizedBox(height: 4),
              Text('$onlineNodes / $totalNodes', style: TextStyle(
                color: onlineNodes > 0 ? const Color(0xFF00e5ff) : const Color(0xFF4a5568),
                fontSize: 18, fontWeight: FontWeight.bold)),
              const Text('УЗЛОВ', style: TextStyle(color: Color(0xFF4a5568), fontSize: 10, letterSpacing: 1)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── PC Action Grid (4 columns) ──────────────────────────────────────────

class _PCActionGrid extends StatelessWidget {
  final List<Widget> children;
  const _PCActionGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(children.length, (i) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: i > 0 ? 8 : 0),
            child: children[i],
          ),
        );
      }),
    );
  }
}

class _PCActionCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _PCActionCard({
    required this.icon, required this.label, required this.subtitle,
    required this.color, required this.onTap,
  });

  @override
  State<_PCActionCard> createState() => _PCActionCardState();
}

class _PCActionCardState extends State<_PCActionCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: widget.color.withValues(alpha: _hover ? 0.4 : 0.12), width: _hover ? 1.5 : 1),
            boxShadow: _hover
                ? [BoxShadow(color: widget.color.withValues(alpha: 0.15), blurRadius: 16, spreadRadius: 2)]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: _hover ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: widget.color.withValues(alpha: _hover ? 0.4 : 0.15)),
                ),
                child: Icon(widget.icon, color: widget.color, size: 22),
              ),
              const SizedBox(height: 12),
              Text(widget.label,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14, fontWeight: FontWeight.bold),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(widget.subtitle,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Hints ─────────────────────────────────────────────────────────────────

class _NewPlayerHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFff9800).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFff9800).withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb, color: Color(0xFFff9800), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Добро пожаловать, хакер!', style: TextStyle(color: Color(0xFFff9800), fontSize: 14, fontWeight: FontWeight.bold)),
                SizedBox(height: 2),
                Text('Начни с постройки базы — открой «Моя база» и разверни первый узел.',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.arrow_forward, color: Color(0xFFff9800), size: 22), onPressed: () => context.go('/game/network')),
        ],
      ),
    );
  }
}

class _OfflineNodesWarning extends StatelessWidget {
  final int nodeCount;
  const _OfflineNodesWarning({required this.nodeCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFF0040).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF0040).withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning, color: Color(0xFFFF0040), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Все узлы офлайн!', style: TextStyle(color: Color(0xFFFF0040), fontSize: 14, fontWeight: FontWeight.bold)),
                SizedBox(height: 2),
                Text('Доход приостановлен. Перезагрузите узлы в базе.', style: TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.power_settings_new, color: Color(0xFFFF0040), size: 22), onPressed: () => context.go('/game/network')),
        ],
      ),
    );
  }
}

// ─── Banners ────────────────────────────────────────────────────────────────

class _DailyRewardBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/game/daily-reward'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [const Color(0xFFFFD700).withValues(alpha: 0.12), const Color(0xFFff9800).withValues(alpha: 0.04)]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.3)),
              ),
              child: const Center(child: Text('🎁', style: TextStyle(fontSize: 26))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('ЕЖЕДНЕВНАЯ НАГРАДА', style: TextStyle(color: Color(0xFFFFD700), fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  Text('Забирайте награду каждый день — стрик растёт!', style: TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: const Color(0xFFFFD700).withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}

class _ActiveEventsBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final eventProvider = context.watch<EventProvider>();
    final eventCount = eventProvider.activeEvents.length;
    if (eventCount == 0) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => context.go('/game/events'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [const Color(0xFF00e5ff).withValues(alpha: 0.12), const Color(0xFFa855f7).withValues(alpha: 0.04)]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF00e5ff).withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF00e5ff).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF00e5ff).withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.event, color: Color(0xFF00e5ff), size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('СОБЫТИЯ НЕДЕЛИ', style: TextStyle(color: Color(0xFF00e5ff), fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1)),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: const Color(0xFFFF0040).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                        child: Text('$eventCount активно', style: const TextStyle(color: Color(0xFFFF0040), fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  Text(eventCount == 1
                      ? 'Текущее: ${eventProvider.activeEvents.first.typeLabel}'
                      : '$eventCount события ждут вашего участия',
                    style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: const Color(0xFF00e5ff).withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}

