import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../providers/game_provider.dart';
import '../../widgets/cyber_button.dart';

// ── Screen ─────────────────────────────────────────────────────

class ProfileScreen extends StatefulWidget {
  final PlayerProfileData? profile;

  const ProfileScreen({super.key, this.profile});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  late AnimationController _xpController;
  late Animation<double> _xpAnim;

  @override
  void initState() {
    super.initState();
    _xpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _xpAnim = Tween<double>(begin: 0, end: 0.0).animate(CurvedAnimation(
      parent: _xpController,
      curve: Curves.easeOutCubic,
    ));
    _xpController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Задержка для загрузки данных из providers
      final game = context.read<GameProvider>();
      final auth = context.read<AuthProvider>();
      if (auth.userId != null) {
        game.init(auth.userId!);
      }
      // Обновляем анимацию XP
      final level = game.level;
      final xp = game.xp;
      final xpNeeded = level * 1000;
      final target = xpNeeded > 0 ? (xp / xpNeeded).clamp(0.0, 1.0) : 0.0;
      if (mounted) {
        setState(() {
          _xpAnim = Tween<double>(begin: 0, end: target).animate(CurvedAnimation(
            parent: _xpController,
            curve: Curves.easeOutCubic,
          ));
        });
        _xpController.forward(from: 0);
      }
    });
  }

  @override
  void dispose() {
    _xpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final game = context.watch<GameProvider>();
    final theme = Theme.of(context);

    final username = (widget.profile?.handle.isNotEmpty == true
        ? widget.profile!.handle
        : auth.displayName.isNotEmpty
            ? auth.displayName
            : 'Хакер');
    final level = widget.profile?.level ?? game.level;
    final xp = widget.profile?.currentXp ?? game.xp;
    final xpNeeded = widget.profile?.xpToNextLevel ?? level * 1000;
    final ranking = widget.profile?.ranking ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17),
      body: CustomScrollView(
        slivers: [
          // ── App bar with avatar ──────────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: const Color(0xFF0A0E17),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF00FF41)),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF0F1320), Color(0xFF0A0E17)],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      // Avatar
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF00FF41), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00FF41).withValues(alpha: 0.2),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 44,
                          backgroundColor: const Color(0xFF1A1F2E),
                          child: Text(
                            username.isNotEmpty
                                ? username.substring(0, min(2, username.length)).toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Color(0xFF00FF41),
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Username
                      Text(
                        username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                      if (auth.profile?.clanId != null)
                        Text(
                          'В КЛАНЕ',
                          style: const TextStyle(
                            color: Color(0xFF00E5FF),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Level & XP ───────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _buildLevelSection(level, xp, xpNeeded, ranking),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ── Stats grid ───────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildStatsGrid(game, auth),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // ── Network Info ─────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildNetworkInfo(game),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // ── Edit profile button ──────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              child: CyberButton(
                label: 'РЕДАКТИРОВАТЬ',
                variant: CyberButtonVariant.secondary,
                icon: Icons.edit,
                width: double.infinity,
                onPressed: _onEditProfile,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Level & XP ──────────────────────────────────────────────
  Widget _buildLevelSection(int level, int xp, int xpNeeded, int ranking) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2A2F45)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.stars, color: Color(0xFFFFD700), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'УРОВЕНЬ $level',
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              if (ranking > 0)
                Text(
                  'Рейтинг #$ranking',
                  style: const TextStyle(
                    color: Color(0xFF00FF41),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: ListenableBuilder(
              listenable: _xpAnim,
              builder: (context, _) => LinearProgressIndicator(
                value: _xpAnim.value,
                minHeight: 10,
                backgroundColor: const Color(0xFF12162A),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00FF41)),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$xp XP', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
              Text('$xpNeeded XP', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Stats grid ──────────────────────────────────────────────
  Widget _buildStatsGrid(GameProvider game, AuthProvider auth) {
    final credits = game.credits;
    final cpu = game.cpu;
    final bandwidth = game.bandwidth;
    final nodes = game.networkNodes.length;
    final onlineNodes = game.networkNodes.where((n) => n.isOnline).length;

    final stats = [
      _StatItem(label: 'Кредиты', value: _formatNum(credits), icon: Icons.monetization_on, color: const Color(0xFFFFD700)),
      _StatItem(label: 'ЦПУ', value: '$cpu THz', icon: Icons.memory, color: const Color(0xFF00E5FF)),
      _StatItem(label: 'Канал', value: '$bandwidth MB/s', icon: Icons.wifi_tethering, color: const Color(0xFFFF9800)),
      _StatItem(label: 'Узлы онлайн', value: '$onlineNodes/$nodes', icon: Icons.dns, color: const Color(0xFF00FF41)),
      _StatItem(label: 'Уровень', value: '${game.level}', icon: Icons.trending_up, color: const Color(0xFF00E5FF)),
      _StatItem(label: 'Опыт', value: _formatNum(game.xp), icon: Icons.star, color: const Color(0xFFFFD700)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'СТАТИСТИКА',
          style: TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 2),
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.8,
          children: stats.map((s) => _buildStatCard(s)).toList(),
        ),
      ],
    );
  }

  Widget _buildStatCard(_StatItem stat) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: stat.color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(stat.icon, color: stat.color, size: 20),
          const SizedBox(height: 6),
          Text(
            stat.value,
            style: TextStyle(color: stat.color, fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: 0.5),
          ),
          Text(
            stat.label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ── Network Info ────────────────────────────────────────────
  Widget _buildNetworkInfo(GameProvider game) {
    final nodes = game.networkNodes;
    if (nodes.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ВАША СЕТЬ', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 2)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F2E),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF2A2F45)),
            ),
            child: const Center(
              child: Text('Сеть пуста. Разверните первый узел!', style: TextStyle(color: Color(0xFF4a5568), fontSize: 13)),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ВАША СЕТЬ', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 2)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F2E),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF2A2F45)),
          ),
          child: Column(
            children: nodes.take(10).map((node) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      node.isOnline ? Icons.dns : Icons.dns_outlined,
                      color: node.isOnline ? const Color(0xFF00FF41) : const Color(0xFF4a5568),
                      size: 16,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${_nodeTypeLabel(node.nodeType)} #${node.id.length >= 6 ? node.id.substring(0, 6) : node.id}',
                        style: TextStyle(color: node.isOnline ? Colors.white : const Color(0xFF4a5568), fontSize: 12),
                      ),
                    ),
                    Text(
                      'УР${node.nodeLevel}',
                      style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 11, fontWeight: FontWeight.bold),
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

  // ── Helpers ─────────────────────────────────────────────────
  String _nodeTypeLabel(String nodeType) {
    return switch (nodeType.toLowerCase()) {
      'server' => 'Сервер',
      'firewall' => 'Файрвол',
      'proxy' => 'Прокси',
      'router' => 'Роутер',
      'miner' => 'Майнер',
      'scanner' => 'Сканер',
      'database' => 'База данных',
      'terminal' => 'Терминал',
      _ => nodeType,
    };
  }

  String _formatNum(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  void _onEditProfile() {
    final auth = context.read<AuthProvider>();
    final ctrl = TextEditingController(text: auth.displayName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF00E5FF)),
        ),
        title: const Text('Редактировать профиль', style: TextStyle(color: Color(0xFF00E5FF))),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            labelText: 'Имя пользователя',
            labelStyle: const TextStyle(color: Color(0xFF00E5FF)),
            filled: true,
            fillColor: const Color(0xFF12162A),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: const Color(0xFF2A2F45))),
            focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF00E5FF))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ctrl.dispose();
              Navigator.pop(ctx);
            },
            child: const Text('ОТМЕНА', style: TextStyle(color: Colors.white54)),
          ),
          CyberButton(
            label: 'СОХРАНИТЬ',
            variant: CyberButtonVariant.secondary,
            height: 36,
            onPressed: () async {
              final newName = ctrl.text.trim();
              if (newName.isEmpty) return;
              ctrl.dispose();
              Navigator.pop(ctx);
              try {
                await Supabase.instance.client
                    .from('profiles')
                    .update({'username': newName})
                    .eq('id', auth.userId!);
                await auth.refreshProfile();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Профиль обновлён'), backgroundColor: Color(0xFF00FF41)),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ошибка: $e'), backgroundColor: Color(0xFFFF0040)),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}

// ── Stat helper ────────────────────────────────────────────────

class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

// Data model for passing profile data
class PlayerProfileData {
  final String id;
  final String handle;
  final String avatarUrl;
  final int level;
  final int currentXp;
  final int xpToNextLevel;
  final int totalAttacks;
  final int successfulAttacks;
  final int creditsEarned;
  final int networksDestroyed;
  final int ranking;
  final String clanTag;

  const PlayerProfileData({
    required this.id,
    required this.handle,
    this.avatarUrl = '',
    this.level = 1,
    this.currentXp = 0,
    this.xpToNextLevel = 1000,
    this.totalAttacks = 0,
    this.successfulAttacks = 0,
    this.creditsEarned = 0,
    this.networksDestroyed = 0,
    this.ranking = 0,
    this.clanTag = '',
  });
}


