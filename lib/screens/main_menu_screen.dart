import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/game_provider.dart';
import '../config/game_config.dart';

// ─── Главное меню — Хаб стратегии в стиле Vikings ─────────────────────────

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
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF00ff41),
          onRefresh: () async {
            if (auth.userId != null) {
              await Future.wait([
                game.refreshResources(auth.userId!),
                game.refreshNetworkNodes(auth.userId!),
              ]);
            }
          },
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              const SizedBox(height: 4),

              // ── Карточка игрока ──────────────────────────────────────
              _PlayerCard(
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

              const SizedBox(height: 10),

              // ── Подсказка для новичков ──────────────────────────────
              if (totalNodes == 0) _NewPlayerHint(),

              // ── Быстрые уведомления ───────────────────────────────
              if (totalNodes > 0 && onlineNodes == 0)
                _OfflineNodesWarning(nodeCount: totalNodes),

              // ── Основные действия (самые частые) ───────────────────
              _sectionTitle('ПЕРВЫЕ ДЕЙСТВИЯ'),
              const SizedBox(height: 8),

              // Две главные кнопки: База и Атака — в стиле Vikings
              _buildPrimaryActions(game),

              const SizedBox(height: 12),

              // ── Второстепенные действия ─────────────────────────────
              _sectionTitle('ЗАДАЧИ'),
              const SizedBox(height: 8),
              _ActionGrid(children: [
                _ActionCard(
                  icon: Icons.storefront,
                  label: 'Чёрный рынок',
                  subtitle: 'Снаряжение и софт',
                  color: const Color(0xFFff9800),
                  onTap: () => context.go('/game/market'),
                ),
                _ActionCard(
                  icon: Icons.military_tech,
                  label: 'Миссии',
                  subtitle: 'PvE кампания',
                  color: const Color(0xFFFFD700),
                  onTap: () => context.go('/game/campaign'),
                ),
                _ActionCard(
                  icon: Icons.public,
                  label: 'Карта мира',
                  subtitle: 'Глобальная сеть',
                  color: const Color(0xFF00e5ff),
                  onTap: () => context.go('/game/map'),
                ),
                _ActionCard(
                  icon: Icons.person,
                  label: 'Профиль',
                  subtitle: 'Статистика',
                  color: const Color(0xFF78909c),
                  onTap: () => context.go('/profile'),
                ),
              ]),

              const SizedBox(height: 12),

              // ── Общение и клан ─────────────────────────────────────
              _sectionTitle('АЛЬЯНС'),
              const SizedBox(height: 8),
              _ActionGrid(children: [
                _ActionCard(
                  icon: Icons.chat_bubble,
                  label: 'Связь',
                  subtitle: 'Общий и клановый чат',
                  color: const Color(0xFF00e5ff),
                  badge: null,
                  onTap: () => context.go('/game/chat'),
                ),
                _ActionCard(
                  icon: Icons.groups,
                  label: 'Банда',
                  subtitle: 'Создай или вступи',
                  color: const Color(0xFFa855f7),
                  badge: null,
                  onTap: () => context.go('/game/clan'),
                ),
                _ActionCard(
                  icon: Icons.leaderboard,
                  label: 'Рейтинг',
                  subtitle: 'Лучшие хакеры мира',
                  color: const Color(0xFFe91e63),
                  badge: null,
                  onTap: () => context.go('/game/leaderboard'),
                ),
                _ActionCard(
                  icon: Icons.settings,
                  label: 'Настройки',
                  subtitle: 'Аккаунт и оформление',
                  color: const Color(0xFF4a5568),
                  badge: null,
                  onTap: () => context.go('/settings'),
                ),
              ]),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ── Primary Action Buttons (База + Атака) ──

  Widget _buildPrimaryActions(GameProvider game) {
    final onlineNodes = game.networkNodes.where((n) => n.isOnline).length;
    final totalNodes = game.networkNodes.length;

    return Row(
      children: [
        // Кнопка "Моя база" — зелёная, большая
        Expanded(
          child: _PrimaryActionCard(
            icon: Icons.account_tree,
            label: 'МОЯ БАЗА',
            subtitle: onlineNodes > 0
                ? '$onlineNodes/$totalNodes узлов'
                : 'Построй первый узел!',
            color: const Color(0xFF00ff41),
            glowColor: const Color(0xFF00ff41).withValues(alpha: 0.15),
            onTap: () => context.go('/game/network'),
          ),
        ),
        const SizedBox(width: 10),
        // Кнопка "Атаковать" — красная, большая
        Expanded(
          child: _PrimaryActionCard(
            icon: Icons.gps_fixed,
            label: 'АТАКА',
            subtitle: game.availableTargets.isNotEmpty
                ? '${game.availableTargets.length} целей'
                : 'Поиск целей...',
            color: const Color(0xFFFF0040),
            glowColor: const Color(0xFFFF0040).withValues(alpha: 0.15),
            onTap: () => context.go('/game/attack'),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF4a5568),
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
      ),
    );
  }
}

// ─── Primary Action Card (large button) ─────────────────────────────────────

class _PrimaryActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final Color glowColor;
  final VoidCallback onTap;

  const _PrimaryActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.glowColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF111827),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF111827),
                glowColor,
              ],
            ),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: glowColor,
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: color.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Карточка игрока ───────────────────────────────────────────────────────

class _PlayerCard extends StatelessWidget {
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

  const _PlayerCard({
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF111827), Color(0xFF0d1220)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00ff41).withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00ff41).withValues(alpha: 0.06),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        children: [
          // Аватар + имя + уровень + кредиты
          Row(
            children: [
              // Аватар
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [rankColor, rankColor.withValues(alpha: 0.5)],
                  ),
                  border: Border.all(
                    color: rankColor.withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    username.isNotEmpty
                        ? username.substring(0, min(2, username.length)).toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Color(0xFF0a0e17),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Информация
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username.isEmpty ? 'Хакер' : username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: rankColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'УР $level',
                            style: TextStyle(
                              color: rankColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          rankTitle,
                          style: TextStyle(
                            color: rankColor.withValues(alpha: 0.7),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Кредиты
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.monetization_on, color: Color(0xFFFFD700), size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '$credits',
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    income > 0 ? '+$income/30с' : 'кредитов',
                    style: TextStyle(
                      color: income > 0
                          ? const Color(0xFF00ff41).withValues(alpha: 0.6)
                          : const Color(0xFF4a5568),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Прогресс XP + узлы в одну строку
          Row(
            children: [
              // XP бар
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'ОПЫТ',
                          style: TextStyle(
                            color: Color(0xFF4a5568),
                            fontSize: 9,
                            letterSpacing: 1,
                          ),
                        ),
                        Text(
                          '$xp / $xpNeeded',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: xpPercent,
                        minHeight: 6,
                        backgroundColor: const Color(0xFF0d1117),
                        valueColor: AlwaysStoppedAnimation<Color>(
                            rankColor),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Узлы
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.dns,
                    color: onlineNodes > 0 ? const Color(0xFF00e5ff) : const Color(0xFF4a5568),
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$onlineNodes',
                    style: TextStyle(
                      color: onlineNodes > 0 ? const Color(0xFF00e5ff) : const Color(0xFF4a5568),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    ' / $totalNodes',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.25),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Подсказка для новичков ────────────────────────────────────────────────

class _NewPlayerHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFff9800).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFff9800).withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb, color: Color(0xFFff9800), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Добро пожаловать, хакер!',
                  style: TextStyle(
                    color: Color(0xFFff9800),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Начни с постройки базы — открой «Моя база» и разверни первый узел.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward,
                color: Color(0xFFff9800), size: 20),
            onPressed: () => context.go('/game/network'),
          ),
        ],
      ),
    );
  }
}

// ─── Предупреждение о офлайн узлах ─────────────────────────────────────────

class _OfflineNodesWarning extends StatelessWidget {
  final int nodeCount;

  const _OfflineNodesWarning({required this.nodeCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFF0040).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFF0040).withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning, color: Color(0xFFFF0040), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Все узлы офлайн!',
                  style: TextStyle(
                    color: Color(0xFFFF0040),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Доход приостановлен. Перезагрузите узлы в базе.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.power_settings_new,
                color: Color(0xFFFF0040), size: 20),
            onPressed: () => context.go('/game/network'),
          ),
        ],
      ),
    );
  }
}

// ─── Сетка действий ───────────────────────────────────────────────────────

class _ActionGrid extends StatelessWidget {
  final List<Widget> children;

  const _ActionGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.2,
      children: children,
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final String? badge;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF111827),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: color.withValues(alpha: 0.12),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
