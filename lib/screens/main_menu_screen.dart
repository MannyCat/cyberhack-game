import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/game_provider.dart';
import '../config/game_config.dart';

// ─── Главное меню — Мобильный хаб стратегии ───────────────────────────────

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
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 8),

              // ── Карточка игрока ──────────────────────────────────────
              _PlayerCard(
                username: username,
                level: level,
                rankTitle: _rankTitle(level),
                xpPercent: xpPercent,
                xp: xp,
                xpNeeded: xpNeeded,
                credits: credits,
                onlineNodes: onlineNodes,
                totalNodes: totalNodes,
              ),

              const SizedBox(height: 12),

              // ── Подсказка для новичков ──────────────────────────────
              if (totalNodes == 0) _NewPlayerHint(),

              const SizedBox(height: 12),

              // ── Основные действия ────────────────────────────────────
              _sectionTitle('ОСНОВНЫЕ ДЕЙСТВИЯ'),
              const SizedBox(height: 8),
              _ActionGrid(children: [
                _ActionCard(
                  icon: Icons.account_tree,
                  label: 'Моя база',
                  subtitle: onlineNodes > 0
                      ? '$onlineNodes узлов онлайн'
                      : 'Построй первый узел!',
                  color: const Color(0xFF00ff41),
                  onTap: () => context.go('/game/network'),
                ),
                _ActionCard(
                  icon: Icons.gps_fixed,
                  label: 'Атаковать',
                  subtitle: 'Выбери цель и атакуй',
                  color: const Color(0xFFff4444),
                  onTap: () => context.go('/game/attack'),
                ),
                _ActionCard(
                  icon: Icons.storefront,
                  label: 'Магазин',
                  subtitle: 'Купи снаряжение',
                  color: const Color(0xFFff9800),
                  onTap: () => context.go('/game/market'),
                ),
                _ActionCard(
                  icon: Icons.public,
                  label: 'Карта мира',
                  subtitle: 'Глобальная карта',
                  color: const Color(0xFF00e5ff),
                  onTap: () => context.go('/game/map'),
                ),
              ]),

              const SizedBox(height: 20),

              // ── Общение и рейтинг ────────────────────────────────────
              _sectionTitle('ОБЩЕНИЕ'),
              const SizedBox(height: 8),
              _ActionGrid(children: [
                _ActionCard(
                  icon: Icons.chat_bubble,
                  label: 'Чат',
                  subtitle: 'Глобальный и клановый',
                  color: const Color(0xFF00e5ff),
                  onTap: () => context.go('/game/chat'),
                ),
                _ActionCard(
                  icon: Icons.groups,
                  label: 'Клан',
                  subtitle: 'Создай или вступи',
                  color: const Color(0xFFa855f7),
                  onTap: () => context.go('/game/clan'),
                ),
                _ActionCard(
                  icon: Icons.leaderboard,
                  label: 'Рейтинг',
                  subtitle: 'Лучшие хакеры',
                  color: const Color(0xFFe91e63),
                  onTap: () => context.go('/game/leaderboard'),
                ),
                _ActionCard(
                  icon: Icons.person,
                  label: 'Профиль',
                  subtitle: 'Статистика',
                  color: const Color(0xFF78909c),
                  onTap: () => context.go('/profile'),
                ),
              ]),

              const SizedBox(height: 20),

              // ── Нижняя кнопка ────────────────────────────────────────
              _BottomActions(),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF4a5568),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
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
  final double xpPercent;
  final int xp;
  final int xpNeeded;
  final int credits;
  final int onlineNodes;
  final int totalNodes;

  const _PlayerCard({
    required this.username,
    required this.level,
    required this.rankTitle,
    required this.xpPercent,
    required this.xp,
    required this.xpNeeded,
    required this.credits,
    required this.onlineNodes,
    required this.totalNodes,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF111827), Color(0xFF0d1220)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00ff41).withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00ff41).withValues(alpha: 0.08),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        children: [
          // Аватар + имя + уровень
          Row(
            children: [
              // Аватар
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00ff41), Color(0xFF00e5ff)],
                  ),
                  border: Border.all(
                    color: const Color(0xFF00ff41).withValues(alpha: 0.5),
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
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Информация
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username.isEmpty ? 'Хакер' : username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00ff41)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Уровень $level',
                            style: const TextStyle(
                              color: Color(0xFF00ff41),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          rankTitle,
                          style: const TextStyle(
                            color: Color(0xFF4a5568),
                            fontSize: 12,
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
                  Text(
                    '$credits',
                    style: const TextStyle(
                      color: Color(0xFF00ff41),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'кредитов',
                    style: TextStyle(
                      color: Color(0xFF4a5568),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Прогресс XP
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Опыт',
                          style: TextStyle(
                            color: Color(0xFF4a5568),
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          '$xp / $xpNeeded',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 11,
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
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF00ff41)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // Узлы
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.dns,
                          color: Color(0xFF00e5ff), size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '$onlineNodes',
                        style: const TextStyle(
                          color: Color(0xFF00e5ff),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        ' / $totalNodes',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    'узлов онлайн',
                    style: TextStyle(
                      color: Color(0xFF4a5568),
                      fontSize: 11,
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFff9800).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFff9800).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb, color: Color(0xFFff9800), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Добро пожаловать, хакер!',
                  style: TextStyle(
                    color: Color(0xFFff9800),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Начни с постройки базы — открой «Моя база» и разверни первый узел.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward,
                color: Color(0xFFff9800)),
            onPressed: () => context.go('/game/network'),
          ),
        ],
      ),
    );
  }
}

// ─── Сетка действий ────────────────────────────────────────────────────────

class _ActionGrid extends StatelessWidget {
  final List<Widget> children;

  const _ActionGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.25,
      children: children,
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
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
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: color.withValues(alpha: 0.15),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 11,
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

// ─── Нижние кнопки ─────────────────────────────────────────────────────────

class _BottomActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => context.go('/settings'),
            icon: const Icon(Icons.settings, size: 18),
            label: const Text('Настройки'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF4a5568),
              side: const BorderSide(color: Color(0xFF1a2030)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () async {
              final auth = context.read<AuthProvider>();
              await auth.logout();
            },
            icon: const Icon(Icons.power_settings_new, size: 18),
            label: const Text('Выйти'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFff4444),
              side: const BorderSide(color: Color(0xFF331111)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
