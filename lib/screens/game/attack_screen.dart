import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../providers/auth_provider.dart';

// ════════════════════════════════════════════════════════════════════════════════
// AttackScreen — PC Desktop Layout
// ════════════════════════════════════════════════════════════════════════════════
// Wide two-panel layout rendered inside GameShell (sidebar + top bar provided).
// Left  (40%): scrollable target list with hover effects.
// Right (60%): selected target details, attack type chips, launch button,
//              attack progress, and attack history.
// Attack result shown as a wide dialog overlay.
// All text Russian. Dark cyberpunk theme on Color(0xFF0a0e17).

class AttackScreen extends StatefulWidget {
  const AttackScreen({super.key});

  @override
  State<AttackScreen> createState() => _AttackScreenState();
}

class _AttackScreenState extends State<AttackScreen> with TickerProviderStateMixin {
  AttackTarget? _selectedTarget;
  _AttackType? _selectedAttackType;
  bool _isAttacking = false;
  double _attackProgress = 0.0;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Track hovered indices for target list & attack chips
  int _hoveredTargetIndex = -1;
  int _hoveredAttackIndex = -1;
  bool _launchButtonHovered = false;

  // ════════════════════════════════════════════════════════════════════════════
  // Attack type definitions — all original game logic preserved
  // ════════════════════════════════════════════════════════════════════════════
  static const _attackTypes = <_AttackType>[
    _AttackType(
      name: 'DDoS',
      icon: Icons.wifi_off,
      damage: 30,
      creditCost: 500,
      cpuCost: 20,
      color: Colors.redAccent,
      description: 'Затопить цель трафиком',
    ),
    _AttackType(
      name: 'Malware',
      icon: Icons.bug_report,
      damage: 50,
      creditCost: 1200,
      cpuCost: 35,
      color: Colors.purpleAccent,
      description: 'Развернуть вредоносную нагрузку',
    ),
    _AttackType(
      name: 'Phishing',
      icon: Icons.link_off,
      damage: 25,
      creditCost: 300,
      cpuCost: 10,
      color: Colors.tealAccent,
      description: 'Социальная инженерия учётных данных',
    ),
    _AttackType(
      name: 'Brute Force',
      icon: Icons.lock_open,
      damage: 40,
      creditCost: 800,
      cpuCost: 45,
      color: Colors.orangeAccent,
      description: 'Полный перебор паролей',
    ),
    _AttackType(
      name: 'SQL Injection',
      icon: Icons.code,
      damage: 60,
      creditCost: 2000,
      cpuCost: 50,
      color: Colors.blueAccent,
      description: 'Эксплуатация уязвимостей БД',
    ),
    _AttackType(
      name: 'Zero Day',
      icon: Icons.warning,
      damage: 100,
      creditCost: 5000,
      cpuCost: 80,
      color: Colors.yellowAccent,
      description: 'Неизвестный эксплойт — разрушителен',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Game Logic — attack launch (unchanged)
  // ════════════════════════════════════════════════════════════════════════════

  Future<void> _launchAttack() async {
    if (_selectedTarget == null || _selectedAttackType == null) return;

    final auth = context.read<AuthProvider>();
    final game = context.read<GameProvider>();
    if (auth.userId == null) return;

    final attackType = _selectedAttackType!;

    // Check resource requirements
    if (game.credits < attackType.creditCost) {
      _showAttackResultDialog(
        title: 'НЕДОСТАТОЧНО КРЕДИТОВ',
        message: 'Для атаки ${attackType.name} нужно ${attackType.creditCost} CR.\nУ вас: ${game.credits} CR',
        isSuccess: false,
      );
      return;
    }
    if (game.cpu < attackType.cpuCost) {
      _showAttackResultDialog(
        title: 'НЕДОСТАТОЧНО ЦПУ',
        message: 'Для атаки ${attackType.name} нужно ${attackType.cpuCost} CPU.\nУ вас: ${game.cpu} CPU',
        isSuccess: false,
      );
      return;
    }

    setState(() {
      _isAttacking = true;
      _attackProgress = 0.0;
    });

    // Animate progress
    for (int i = 0; i <= 100; i += 2) {
      await Future.delayed(const Duration(milliseconds: 30));
      if (!mounted) return;
      setState(() => _attackProgress = i / 100);
    }

    final success = await game.launchAttack(
      attackerId: auth.userId!,
      defenderId: _selectedTarget!.id,
      targetNodeId: null,
      attackType: attackType.name,
      damage: attackType.damage,
      creditCost: attackType.creditCost,
      cpuCost: attackType.cpuCost,
    );

    if (!mounted) return;
    setState(() => _isAttacking = false);

    if (success) {
      _showAttackResultDialog(
        title: 'АТАКА ЗАПУЩЕНА',
        message:
            '${attackType.name} отправлен против ${_selectedTarget!.username}\nУрон: ${attackType.damage}\n'
            'Стоимость: -${attackType.creditCost} CR / -${attackType.cpuCost} CPU',
        isSuccess: true,
      );
      await game.refreshResources(auth.userId!);
      await game.refreshAttackHistory(auth.userId!);
    } else {
      _showAttackResultDialog(
        title: 'АТАКА ПРОВАЛЕНА',
        message: game.errorMessage ?? 'Не удалось запустить атаку на ${_selectedTarget!.username}',
        isSuccess: false,
      );
    }
  }

  void _showAttackResultDialog({
    required String title,
    required String message,
    required bool isSuccess,
  }) {
    final accentColor = isSuccess ? const Color(0xFF00FF41) : const Color(0xFFFF0040);
    final icon = isSuccess ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded;

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black87,
      builder: (context) => _AttackResultDialog(
        title: title,
        message: message,
        icon: icon,
        accentColor: accentColor,
        isSuccess: isSuccess,
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Build — two-panel PC layout
  // ════════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    final auth = context.watch<AuthProvider>();

    if (auth.userId == null) {
      return const Center(
        child: Text('Не авторизован', style: TextStyle(color: Color(0xFF6a7080), fontSize: 14)),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── LEFT PANEL: Target List (40%) ─────────────────────────────────
        Expanded(
          flex: 4,
          child: _buildLeftPanel(game, auth),
        ),
        // ── Vertical divider ────────────────────────────────────────────────
        Container(
          width: 1,
          height: double.infinity,
          color: const Color(0xFF1e2a3a),
        ),
        // ── RIGHT PANEL: Attack Details (60%) ──────────────────────────────
        Expanded(
          flex: 6,
          child: _buildRightPanel(game, auth),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // LEFT PANEL — Target List
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildLeftPanel(GameProvider game, AuthProvider auth) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0d1220),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Panel header ──────────────────────────────────────────────────
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF1e2a3a))),
            ),
            child: Row(
              children: [
                const Icon(Icons.gps_fixed_rounded, color: Color(0xFFFF0040), size: 18),
                const SizedBox(width: 8),
                const Text(
                  'ЦЕЛИ АТАКИ',
                  style: TextStyle(
                    color: Color(0xFFFF0040),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    fontFamily: 'monospace',
                  ),
                ),
                const Spacer(),
                Text(
                  '${game.availableTargets.length} целей',
                  style: const TextStyle(
                    color: Color(0xFF3a4555),
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(width: 8),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      game.refreshTargets(auth.userId!);
                      game.refreshAttackHistory(auth.userId!);
                    },
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF0040).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFF0040).withValues(alpha: 0.2)),
                      ),
                      child: const Icon(Icons.refresh_rounded, color: Color(0xFFFF0040), size: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Target list ───────────────────────────────────────────────────
          Expanded(
            child: game.availableTargets.isEmpty
                ? _buildEmptyTargetList()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: game.availableTargets.length,
                    itemBuilder: (context, index) {
                      final target = game.availableTargets[index];
                      final isSelected = _selectedTarget?.id == target.id;
                      final isHovered = _hoveredTargetIndex == index;

                      return MouseRegion(
                        cursor: SystemMouseCursors.click,
                        onEnter: (_) => setState(() => _hoveredTargetIndex = index),
                        onExit: (_) => setState(() => _hoveredTargetIndex = -1),
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _selectedTarget = target;
                            _selectedAttackType = null; // reset attack type on new target
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFFF0040).withValues(alpha: 0.10)
                                  : isHovered
                                      ? const Color(0xFF1e2a3a).withValues(alpha: 0.5)
                                      : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: isSelected
                                  ? Border.all(
                                      color: const Color(0xFFFF0040).withValues(alpha: 0.5),
                                      width: 1,
                                    )
                                  : isHovered
                                      ? Border.all(
                                          color: const Color(0xFF1e2a3a),
                                          width: 1,
                                        )
                                      : null,
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFFFF0040).withValues(alpha: 0.08),
                                        blurRadius: 12,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              children: [
                                // Avatar
                                _buildTargetAvatar(target),
                                const SizedBox(width: 10),
                                // Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              target.username,
                                              style: TextStyle(
                                                color: isSelected
                                                    ? const Color(0xFFFF0040)
                                                    : const Color(0xFFe0e6ed),
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (target.clanTag.isNotEmpty) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFa855f7).withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(
                                                  color: const Color(0xFFa855f7).withValues(alpha: 0.25),
                                                ),
                                              ),
                                              child: Text(
                                                '[${target.clanTag}]',
                                                style: const TextStyle(
                                                  color: Color(0xFFa855f7),
                                                  fontSize: 10,
                                                  fontFamily: 'monospace',
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFD700).withValues(alpha: 0.10),
                                              borderRadius: BorderRadius.circular(3),
                                              border: Border.all(
                                                color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                                              ),
                                            ),
                                            child: Text(
                                              'УР ${target.level}',
                                              style: const TextStyle(
                                                color: Color(0xFFFFD700),
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                fontFamily: 'monospace',
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    const Text(
                                                      'СИЛ',
                                                      style: TextStyle(
                                                        color: Color(0xFF5a6578),
                                                        fontSize: 9,
                                                        fontFamily: 'monospace',
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Expanded(
                                                      child: ClipRRect(
                                                        borderRadius: BorderRadius.circular(2),
                                                        child: LinearProgressIndicator(
                                                          value: (target.networkStrength / 500).clamp(0.0, 1.0),
                                                          backgroundColor: const Color(0xFF1a1f2e),
                                                          valueColor: AlwaysStoppedAnimation<Color>(
                                                            target.networkStrength > 300
                                                                ? const Color(0xFFFF0040)
                                                                : target.networkStrength > 150
                                                                    ? const Color(0xFFff9800)
                                                                    : const Color(0xFF00FF41),
                                                          ),
                                                          minHeight: 4,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '${target.networkStrength}',
                                                      style: TextStyle(
                                                        color: target.networkStrength > 300
                                                            ? const Color(0xFFFF0040)
                                                            : target.networkStrength > 150
                                                                ? const Color(0xFFff9800)
                                                                : const Color(0xFF00FF41),
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.bold,
                                                        fontFamily: 'monospace',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // Chevron
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 18,
                                  color: isSelected ? const Color(0xFFFF0040) : const Color(0xFF3a4555),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetAvatar(AttackTarget target) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFFFF0040).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFF0040).withValues(alpha: 0.3)),
      ),
      alignment: Alignment.center,
      child: Text(
        target.username.isNotEmpty ? target.username[0].toUpperCase() : '?',
        style: const TextStyle(
          color: Color(0xFFFF0040),
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyTargetList() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off_rounded, size: 48, color: Color(0xFF3a4555)),
          const SizedBox(height: 12),
          const Text(
            'Поиск целей...',
            style: TextStyle(color: Color(0xFF5a6578), fontSize: 13),
          ),
          const SizedBox(height: 4),
          const Text(
            'Система сканирует сеть',
            style: TextStyle(color: Color(0xFF3a4555), fontSize: 11, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // RIGHT PANEL — Attack Details + History
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildRightPanel(GameProvider game, AuthProvider auth) {
    return Column(
      children: [
        // ── Panel header ──────────────────────────────────────────────────
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFF1e2a3a))),
          ),
          child: const Row(
            children: [
              Icon(Icons.flash_on_rounded, color: Color(0xFF00F0FF), size: 18),
              SizedBox(width: 8),
              Text(
                'ПАНЕЛЬ АТАКИ',
                style: TextStyle(
                  color: Color(0xFF00F0FF),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),

        // ── Content ───────────────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _selectedTarget == null
                ? _buildNoTargetSelected()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Selected target info card
                      _buildSelectedTargetCard(game),
                      const SizedBox(height: 20),

                      // Attack type chips
                      _buildAttackTypeChips(game),
                      const SizedBox(height: 20),

                      // Attack type detail card (when selected)
                      if (_selectedAttackType != null) _buildAttackTypeDetail(game),
                      if (_selectedAttackType != null) const SizedBox(height: 16),

                      // Launch button
                      _buildLaunchButton(game),
                      const SizedBox(height: 12),

                      // Attack progress
                      if (_isAttacking) ...[
                        _buildAttackProgress(),
                        const SizedBox(height: 20),
                      ],

                      // Divider
                      const Divider(color: Color(0xFF1e2a3a), height: 32),

                      // Attack history
                      _buildAttackHistorySection(game),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoTargetSelected() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF00F0FF).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF00F0FF).withValues(alpha: 0.15)),
            ),
            child: const Icon(Icons.gps_fixed_rounded, size: 36, color: Color(0xFF3a4555)),
          ),
          const SizedBox(height: 16),
          const Text(
            'ВЫБЕРИТЕ ЦЕЛЬ',
            style: TextStyle(
              color: Color(0xFF5a6578),
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Выберите цель из списка слева,\nчтобы настроить и запустить атаку',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF3a4555),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Selected Target Card
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildSelectedTargetCard(GameProvider game) {
    final target = _selectedTarget!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0d1220),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF0040).withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: const Color(0xFFFF0040).withValues(alpha: 0.06), blurRadius: 16),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section label
          const Text(
            'ВЫБРАННАЯ ЦЕЛЬ',
            style: TextStyle(
              color: Color(0xFF3a4555),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 10),
          // Target info row
          Row(
            children: [
              // Large avatar
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF0040).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFF0040).withValues(alpha: 0.35)),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFFF0040).withValues(alpha: 0.1), blurRadius: 12),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  target.username.isNotEmpty ? target.username[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Color(0xFFFF0040),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Name + clan
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      target.username,
                      style: const TextStyle(
                        color: Color(0xFFe0e6ed),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                    if (target.clanTag.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFa855f7).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFa855f7).withValues(alpha: 0.25)),
                        ),
                        child: Text(
                          '[${target.clanTag}]',
                          style: const TextStyle(
                            color: Color(0xFFa855f7),
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Level badge
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.star_rounded, size: 14, color: Color(0xFFFFD700)),
                    const SizedBox(height: 2),
                    Text(
                      'УР ${target.level}',
                      style: const TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Network strength bar
          Row(
            children: [
              const Text(
                'СИЛА СЕТИ',
                style: TextStyle(
                  color: Color(0xFF5a6578),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (target.networkStrength / 500).clamp(0.0, 1.0),
                    backgroundColor: const Color(0xFF1a1f2e),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      target.networkStrength > 300
                          ? const Color(0xFFFF0040)
                          : target.networkStrength > 150
                              ? const Color(0xFFff9800)
                              : const Color(0xFF00FF41),
                    ),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${target.networkStrength} / 500',
                style: TextStyle(
                  color: target.networkStrength > 300
                      ? const Color(0xFFFF0040)
                      : target.networkStrength > 150
                          ? const Color(0xFFff9800)
                          : const Color(0xFF00FF41),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Attack Type Chips (horizontal row)
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildAttackTypeChips(GameProvider game) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ВЕКТОР АТАКИ',
          style: TextStyle(
            color: Color(0xFF3a4555),
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 10),
        // Wrap chips so they flow onto multiple lines if needed
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(_attackTypes.length, (index) {
            final attack = _attackTypes[index];
            final isSelected = _selectedAttackType == attack;
            final canAfford = game.credits >= attack.creditCost && game.cpu >= attack.cpuCost;
            final isHovered = _hoveredAttackIndex == index;

            return MouseRegion(
              cursor: canAfford ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
              onEnter: (_) => setState(() => _hoveredAttackIndex = index),
              onExit: (_) => setState(() => _hoveredAttackIndex = -1),
              child: GestureDetector(
                onTap: canAfford
                    ? () => setState(() => _selectedAttackType = attack)
                    : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? attack.color.withValues(alpha: 0.18)
                        : isHovered && canAfford
                            ? const Color(0xFF1e2a3a).withValues(alpha: 0.6)
                            : const Color(0xFF0d1220),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? attack.color
                          : isHovered && canAfford
                              ? const Color(0xFF2a3444)
                              : const Color(0xFF1e2a3a),
                      width: isSelected ? 1.5 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: attack.color.withValues(alpha: 0.12),
                              blurRadius: 12,
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        attack.icon,
                        color: canAfford
                            ? (isSelected ? attack.color : const Color(0xFFe0e6ed))
                            : const Color(0xFF3a4555),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        attack.name,
                        style: TextStyle(
                          color: canAfford
                              ? (isSelected ? attack.color : const Color(0xFFe0e6ed))
                              : const Color(0xFF3a4555),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${attack.creditCost} CR',
                        style: TextStyle(
                          color: canAfford
                              ? const Color(0xFF5a6578)
                              : const Color(0xFF2a2f3a),
                          fontSize: 10,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Attack Type Detail Card
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildAttackTypeDetail(GameProvider game) {
    final attack = _selectedAttackType!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0d1220),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: attack.color.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(color: attack.color.withValues(alpha: 0.06), blurRadius: 16),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: attack.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: attack.color.withValues(alpha: 0.3)),
            ),
            child: Icon(attack.icon, color: attack.color, size: 24),
          ),
          const SizedBox(width: 16),
          // Text + stats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attack.description,
                  style: const TextStyle(
                    color: Color(0xFFe0e6ed),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                // Stats row
                Row(
                  children: [
                    _statBadge(Icons.local_fire_department_rounded, 'УРОН', '${attack.damage}', attack.color),
                    const SizedBox(width: 12),
                    _statBadge(Icons.monetization_on_rounded, 'КРЕДИТЫ', '${attack.creditCost}', const Color(0xFFFFD700)),
                    const SizedBox(width: 12),
                    _statBadge(Icons.memory_rounded, 'ЦПУ', '${attack.cpuCost}', const Color(0xFF00F0FF)),
                  ],
                ),
              ],
            ),
          ),
          // Check affordability indicators
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _affordIndicator(
                label: 'КР',
                value: game.credits,
                cost: attack.creditCost,
                color: const Color(0xFFFFD700),
              ),
              const SizedBox(height: 6),
              _affordIndicator(
                label: 'ЦП',
                value: game.cpu,
                cost: attack.cpuCost,
                color: const Color(0xFF00F0FF),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statBadge(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            '$label $value',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _affordIndicator({
    required String label,
    required int value,
    required int cost,
    required Color color,
  }) {
    final canAfford = value >= cost;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          canAfford ? Icons.check_circle_rounded : Icons.cancel_rounded,
          color: canAfford ? const Color(0xFF00FF41) : const Color(0xFFFF0040),
          size: 12,
        ),
        const SizedBox(width: 4),
        Text(
          '$label $value / $cost',
          style: TextStyle(
            color: canAfford ? const Color(0xFF5a6578) : const Color(0xFFFF0040),
            fontSize: 10,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Launch Button
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildLaunchButton(GameProvider game) {
    final canLaunch = _selectedTarget != null &&
        _selectedAttackType != null &&
        !_isAttacking &&
        game.credits >= (_selectedAttackType?.creditCost ?? 0) &&
        game.cpu >= (_selectedAttackType?.cpuCost ?? 0);

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: canLaunch ? _pulseAnimation.value : 0.35,
          child: child,
        );
      },
      child: MouseRegion(
        cursor: canLaunch ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
        onEnter: (_) => setState(() => _launchButtonHovered = true),
        onExit: (_) => setState(() => _launchButtonHovered = false),
        child: GestureDetector(
          onTap: canLaunch ? _launchAttack : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _launchButtonHovered && canLaunch
                    ? [const Color(0xFFFF0040), const Color(0xFFff2060)]
                    : [const Color(0xFFcc0033), const Color(0xFFFF0040)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: canLaunch
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFF0040).withValues(alpha: 0.25),
                        blurRadius: 20,
                        spreadRadius: -4,
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: _isAttacking
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'ВЫПОЛНЕНИЕ...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  )
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 22),
                      SizedBox(width: 12),
                      Text(
                        'НАЧАТЬ АТАКУ',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Attack Progress
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildAttackProgress() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0d1220),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00F0FF).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00F0FF)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'ИНИЦИАЛИЗАЦИЯ ${_selectedAttackType?.name.toUpperCase() ?? ""}...',
                    style: const TextStyle(
                      color: Color(0xFF00F0FF),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              Text(
                '${(_attackProgress * 100).toInt()}%',
                style: const TextStyle(
                  color: Color(0xFF00F0FF),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _attackProgress,
              minHeight: 10,
              backgroundColor: const Color(0xFF1a1f2e),
              valueColor: AlwaysStoppedAnimation<Color>(
                _selectedAttackType?.color ?? const Color(0xFF00F0FF),
              ),
            ),
          ),
          if (_selectedTarget != null) ...[
            const SizedBox(height: 6),
            Text(
              'Цель: ${_selectedTarget!.username}',
              style: const TextStyle(
                color: Color(0xFF5a6578),
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Attack History Section
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildAttackHistorySection(GameProvider game) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ЖУРНАЛ АТАК',
          style: TextStyle(
            color: Color(0xFF3a4555),
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 10),
        if (game.attackHistory.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF1e2a3a)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_outlined, size: 36, color: Color(0xFF3a4555)),
                  SizedBox(height: 8),
                  Text(
                    'Атак пока нет',
                    style: TextStyle(color: Color(0xFF5a6578), fontSize: 13),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Выберите цель и начните первую атаку',
                    style: TextStyle(color: Color(0xFF3a4555), fontSize: 11),
                  ),
                ],
              ),
            ),
          )
        else
          ...game.attackHistory.take(20).map((record) => _buildHistoryRow(record)),
      ],
    );
  }

  Widget _buildHistoryRow(AttackRecord record) {
    final isOutgoing = record.attackerId == context.read<AuthProvider>().userId;
    final statusColor = record.status == 'success'
        ? const Color(0xFF00FF41)
        : record.status == 'failed'
            ? const Color(0xFFFF0040)
            : const Color(0xFFff9800);
    final statusIcon = record.status == 'success'
        ? Icons.check_circle_rounded
        : record.status == 'failed'
            ? Icons.cancel_rounded
            : Icons.hourglass_top_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: const Color(0xFF0d1220),
        border: Border.all(color: const Color(0xFF1e2a3a)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 18),
          const SizedBox(width: 10),
          // Direction badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: (isOutgoing ? const Color(0xFF00FF41) : const Color(0xFFFF0040))
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              isOutgoing ? 'ИСХ' : 'ВХ',
              style: TextStyle(
                color: isOutgoing ? const Color(0xFF00FF41) : const Color(0xFFFF0040),
                fontSize: 9,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Attack info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${record.attackType} vs ${record.defenderName ?? "Неизвестен"}',
                  style: const TextStyle(
                    color: Color(0xFFe0e6ed),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      'Урон: ${record.damage}',
                      style: const TextStyle(
                        color: Color(0xFF5a6578),
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                    if (record.creditsStolen > 0) ...[
                      const SizedBox(width: 10),
                      Text(
                        '+${record.creditsStolen} CR',
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      _formatTimestamp(record.createdAt),
                      style: const TextStyle(
                        color: Color(0xFF3a4555),
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: statusColor.withValues(alpha: 0.25)),
            ),
            child: Text(
              record.status == 'success'
                  ? 'УСПЕХ'
                  : record.status == 'failed'
                      ? 'ПРОВАЛ'
                      : record.status == 'pending'
                          ? 'В ПРОЦЕССЕ'
                          : record.status.toUpperCase(),
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Только что';
    if (diff.inHours < 1) return '${diff.inMinutes}м назад';
    if (diff.inDays < 1) return '${diff.inHours}ч назад';
    if (diff.inDays < 7) return '${diff.inDays}д назад';
    return '${dt.day}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }
}

// ════════════════════════════════════════════════════════════════════════════════
// Attack Type Data Model
// ════════════════════════════════════════════════════════════════════════════════

class _AttackType {
  final String name;
  final IconData icon;
  final int damage;
  final int creditCost;
  final int cpuCost;
  final Color color;
  final String description;

  const _AttackType({
    required this.name,
    required this.icon,
    required this.damage,
    required this.creditCost,
    required this.cpuCost,
    required this.color,
    required this.description,
  });
}

// ════════════════════════════════════════════════════════════════════════════════
// Attack Result Dialog — Wide overlay for PC
// ════════════════════════════════════════════════════════════════════════════════

class _AttackResultDialog extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color accentColor;
  final bool isSuccess;

  const _AttackResultDialog({
    required this.title,
    required this.message,
    required this.icon,
    required this.accentColor,
    required this.isSuccess,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0d1220),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accentColor.withValues(alpha: 0.5), width: 1.5),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with glow
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                  boxShadow: [
                    BoxShadow(color: accentColor.withValues(alpha: 0.2), blurRadius: 20),
                  ],
                ),
                child: Icon(icon, color: accentColor, size: 32),
              ),
              const SizedBox(height: 20),
              // Title
              Text(
                title,
                style: TextStyle(
                  color: accentColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 12),
              // Message
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFe0e6ed),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              // Close button
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 140,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'ЗАКРЫТЬ',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        fontFamily: 'monospace',
                      ),
                    ),
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
