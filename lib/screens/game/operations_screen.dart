import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/game_provider.dart';
import '../../widgets/cyber_button.dart';

// ── Color Constants ──────────────────────────────────────────────────────

const _bgDark = Color(0xFF0a0e17);
const _surface = Color(0xFF111827);
const _surfaceVariant = Color(0xFF1a2332);
const _greenPrimary = Color(0xFF00ff88);
const _greenDark = Color(0xFF00cc6a);
const _cyanSecondary = Color(0xFF00d4ff);
const _goldAccent = Color(0xFFFFD700);
const _purpleAccent = Color(0xFFa855f7);
const _dangerRed = Color(0xFFff4444);

// ── Operations Screen ─────────────────────────────────────────────────────

class OperationsScreen extends ConsumerStatefulWidget {
  const OperationsScreen({super.key});

  @override
  ConsumerState<OperationsScreen> createState() => _OperationsScreenState();
}

class _OperationsScreenState extends ConsumerState<OperationsScreen> {
  final _supabase = Supabase.instance.client;

  // ── Form state ──────────────────────────────────────────────────────────
  String? _selectedServerId;
  String? _selectedOpType;
  Map<String, dynamic>? _selectedTarget;

  // ── Targets from Supabase ────────────────────────────────────────────────
  List<Map<String, dynamic>> _targets = [];
  bool _targetsLoading = true;

  // ── Action states ──────────────────────────────────────────────────────
  bool _starting = false;
  final Set<String> _completingOps = {};

  // ── Countdown timer ─────────────────────────────────────────────────────
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _loadTargets();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  // ── Data Loading ────────────────────────────────────────────────────────

  Future<void> _loadTargets() async {
    setState(() => _targetsLoading = true);
    try {
      final data = await _supabase
          .from('targets')
          .select()
          .eq('is_active', true)
          .order('difficulty');
      if (mounted) {
        setState(() {
          _targets = List<Map<String, dynamic>>.from(data);
          _targetsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _targetsLoading = false);
    }
  }

  // ── Operation Type Helpers ─────────────────────────────────────────────

  static const _opTypes = [
    ('data_theft', 'Кража данных'),
    ('ddos', 'DDoS-атака'),
    ('ransomware', 'Вымогательство'),
    ('espionage', 'Шпионаж'),
    ('crypto_mining', 'Крипто-майнинг'),
    ('identity_theft', 'Кража личности'),
  ];

  String _opTypeRu(String type) {
    for (final entry in _opTypes) {
      if (entry.$1 == type) return entry.$2;
    }
    return type;
  }

  // ── Target Class Helpers ────────────────────────────────────────────────

  String _targetClassRu(String cls) {
    switch (cls) {
      case 'bank':
        return 'Банк';
      case 'tech':
        return 'Технологии';
      case 'energy':
        return 'Энергетика';
      case 'logistics':
        return 'Логистика';
      case 'retail':
        return 'Ритейл';
      case 'pharma':
        return 'Фармацевтика';
      case 'media':
        return 'Медиа';
      case 'gov':
        return 'Правительство';
      default:
        return cls;
    }
  }

  IconData _targetClassIcon(String? cls) {
    switch (cls) {
      case 'bank':
        return Icons.account_balance;
      case 'tech':
        return Icons.memory;
      case 'energy':
        return Icons.bolt;
      case 'logistics':
        return Icons.local_shipping;
      case 'retail':
        return Icons.shopping_cart;
      case 'pharma':
        return Icons.medical_services;
      case 'media':
        return Icons.tv;
      case 'gov':
        return Icons.security;
      default:
        return Icons.public;
    }
  }

  Color _securityColor(int security) {
    if (security < 30) return _greenPrimary;
    if (security < 60) return _goldAccent;
    if (security < 80) return const Color(0xFFFF8C00);
    return _dangerRed;
  }

  String _securityLabel(int security) {
    if (security < 30) return 'Низкая';
    if (security < 60) return 'Средняя';
    if (security < 80) return 'Высокая';
    return 'Максимальная';
  }

  // ── Formatting ────────────────────────────────────────────────────────

  String _formatCredits(dynamic value) {
    final v = (value as num?)?.toInt() ?? 0;
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toString();
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '—';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '$hч ${m.toString().padLeft(2, '0')}м';
    if (m > 0) return '$mм ${s.toString().padLeft(2, '0')}с';
    return '$sс';
  }

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

  bool _isReady(Map<String, dynamic> op) {
    final completesAt = op['completes_at'] as String?;
    if (completesAt == null) return false;
    return DateTime.now().toUtc().isAfter(DateTime.parse(completesAt));
  }

  // ── Estimated values for selected target + op type ─────────────────────

  int _estimatedDuration() {
    if (_selectedTarget == null || _selectedOpType == null) return 0;
    final base = (_selectedTarget!['base_duration'] as num?)?.toInt() ?? 60;
    final difficulty = (_selectedTarget!['difficulty'] as num?)?.toInt() ?? 1;
    // Type multipliers
    final typeMulti = _typeDurationMulti(_selectedOpType!);
    return ((base * typeMulti * (difficulty / 5.0))).round();
  }

  int _estimatedReward() {
    if (_selectedTarget == null || _selectedOpType == null) return 0;
    final base = (_selectedTarget!['base_reward'] as num?)?.toInt() ?? 100;
    final difficulty = (_selectedTarget!['difficulty'] as num?)?.toInt() ?? 1;
    final typeMulti = _typeRewardMulti(_selectedOpType!);
    return ((base * typeMulti * (1 + difficulty * 0.1))).round();
  }

  int _estimatedHeat() {
    if (_selectedTarget == null || _selectedOpType == null) return 0;
    final base = (_selectedTarget!['difficulty'] as num?)?.toInt() ?? 1;
    final typeMulti = _typeHeatMulti(_selectedOpType!);
    return (base * typeMulti).round();
  }

  int _estimatedPower() {
    if (_selectedTarget == null || _selectedOpType == null) return 0;
    final base = (_selectedTarget!['difficulty'] as num?)?.toInt() ?? 1;
    final typeMulti = _typePowerMulti(_selectedOpType!);
    return (base * typeMulti * 5).round();
  }

  double _typeDurationMulti(String type) {
    switch (type) {
      case 'data_theft':
        return 1.0;
      case 'ddos':
        return 0.6;
      case 'ransomware':
        return 1.5;
      case 'espionage':
        return 1.2;
      case 'crypto_mining':
        return 2.0;
      case 'identity_theft':
        return 1.3;
      default:
        return 1.0;
    }
  }

  double _typeRewardMulti(String type) {
    switch (type) {
      case 'data_theft':
        return 1.0;
      case 'ddos':
        return 0.5;
      case 'ransomware':
        return 2.0;
      case 'espionage':
        return 1.2;
      case 'crypto_mining':
        return 0.8;
      case 'identity_theft':
        return 1.5;
      default:
        return 1.0;
    }
  }

  double _typeHeatMulti(String type) {
    switch (type) {
      case 'data_theft':
        return 1.0;
      case 'ddos':
        return 1.5;
      case 'ransomware':
        return 2.0;
      case 'espionage':
        return 0.8;
      case 'crypto_mining':
        return 0.5;
      case 'identity_theft':
        return 1.8;
      default:
        return 1.0;
    }
  }

  double _typePowerMulti(String type) {
    switch (type) {
      case 'data_theft':
        return 1.0;
      case 'ddos':
        return 0.8;
      case 'ransomware':
        return 1.5;
      case 'espionage':
        return 1.2;
      case 'crypto_mining':
        return 2.0;
      case 'identity_theft':
        return 1.3;
      default:
        return 1.0;
    }
  }

  // ── Actions ───────────────────────────────────────────────────────────

  Future<void> _startOperation() async {
    if (_selectedServerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Выберите сервер для операции'),
          backgroundColor: _dangerRed,
        ),
      );
      return;
    }
    if (_selectedTarget == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Выберите цель для операции'),
          backgroundColor: _dangerRed,
        ),
      );
      return;
    }
    if (_selectedOpType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Выберите тип операции'),
          backgroundColor: _dangerRed,
        ),
      );
      return;
    }

    final power = ref.read(gameProvider).power ?? 0;
    if (power < _estimatedPower()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Недостаточно энергии (нужно ${_estimatedPower()}, есть $power)'),
          backgroundColor: _dangerRed,
        ),
      );
      return;
    }

    setState(() => _starting = true);
    try {
      await _supabase.rpc('start_operation', params: {
        'p_target_id': _selectedTarget!['id'],
        'p_server_id': _selectedServerId,
        'p_op_type': _selectedOpType,
      });
      await ref.read(gameProvider).notifier.loadAllData();
      if (mounted) {
        setState(() {
          _selectedTarget = null;
          _selectedOpType = null;
          _selectedServerId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Операция начата!'),
            backgroundColor: _greenPrimary,
            foregroundColor: _bgDark,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка запуска операции: $e'),
            backgroundColor: _dangerRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _completeOperation(Map<String, dynamic> op) async {
    if (_completingOps.contains(op['id'])) return;
    setState(() => _completingOps.add(op['id']));
    try {
      await _supabase.rpc('complete_operation', params: {'p_op_id': op['id']});
      await ref.read(gameProvider).notifier.loadAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Операция завершена: ${_opTypeRu(op['op_type'] ?? '')}'),
            backgroundColor: _greenPrimary,
            foregroundColor: _bgDark,
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
    final servers =
        game.servers.where((s) => s['is_active'] == true).toList();
    final operations = game.operations;
    final activeOps =
        operations.where((o) => o['status'] == 'active').toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Left Panel: New Operation + Active Operations ──────────────
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNewOperationForm(servers),
                  const SizedBox(height: 24),
                  _buildActiveOperations(activeOps),
                ],
              ),
            ),
          ),
          const SizedBox(width: 20),
          // ── Right Panel: Target Selection ─────────────────────────────
          Expanded(
            flex: 2,
            child: _buildTargetPanel(),
          ),
        ],
      ),
    );
  }

  // ── Left Panel: New Operation Form ─────────────────────────────────────

  Widget _buildNewOperationForm(List<Map<String, dynamic>> servers) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _surfaceVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.add_circle_outline, color: _greenPrimary, size: 20),
              SizedBox(width: 8),
              Text(
                'НОВАЯ ОПЕРАЦИЯ',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Divider(color: _surfaceVariant, height: 1),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Server selector
          const Text(
            'СЕРВЕР',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          if (servers.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0d1420),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _surfaceVariant),
              ),
              child: const Text(
                'Нет доступных серверов',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            )
          else
            _buildServerDropdown(servers),
          const SizedBox(height: 14),

          // Operation type selector
          const Text(
            'ТИП ОПЕРАЦИИ',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          _buildOpTypeSelector(),
          const SizedBox(height: 14),

          // Selected target details (shown when target is selected)
          if (_selectedTarget != null) ...[
            const Divider(color: _surfaceVariant),
            const SizedBox(height: 14),
            _buildSelectedTargetDetails(),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: CyberButton(
                text: 'НАЧАТЬ ОПЕРАЦИЮ',
                icon: Icons.play_arrow,
                variant: CyberButtonVariant.primary,
                height: 48,
                isLoading: _starting,
                onPressed: _startOperation,
              ),
            ),
          ] else ...[
            const Divider(color: _surfaceVariant),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0d1420),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _surfaceVariant),
              ),
              child: Column(
                children: [
                  Icon(Icons.arrow_back,
                      color: _cyanSecondary.withValues(alpha: 0.4), size: 28),
                  const SizedBox(height: 8),
                  const Text(
                    'Выберите цель на панели справа →',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildServerDropdown(List<Map<String, dynamic>> servers) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0d1420),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _selectedServerId != null
              ? _cyanSecondary.withValues(alpha: 0.4)
              : _surfaceVariant,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedServerId,
          isExpanded: true,
          dropdownColor: const Color(0xFF1a2332),
          hint: const Text(
            'Выберите сервер...',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
          ),
          items: servers.map((server) {
            return DropdownMenuItem<String>(
              value: server['id'] as String?,
              child: Row(
                children: [
                  Icon(Icons.dns_outlined,
                      color: _cyanSecondary.withValues(alpha: 0.6), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      server['name'] as String? ?? 'Безымянный',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() => _selectedServerId = value);
          },
        ),
      ),
    );
  }

  Widget _buildOpTypeSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _opTypes.map((entry) {
        final isSelected = _selectedOpType == entry.$1;
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => setState(() => _selectedOpType = entry.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? _greenPrimary.withValues(alpha: 0.15)
                    : const Color(0xFF0d1420),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? _greenPrimary.withValues(alpha: 0.5)
                      : _surfaceVariant,
                ),
              ),
              child: Text(
                entry.$2,
                style: TextStyle(
                  color: isSelected ? _greenPrimary : Colors.grey.shade400,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSelectedTargetDetails() {
    final target = _selectedTarget!;
    final name = target['name'] as String? ?? '—';
    final corp = target['corporation'] as String? ?? '';
    final difficulty = (target['difficulty'] as num?)?.toInt() ?? 1;
    final security = (target['security_level'] as num?)?.toInt() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Target header
        Row(
          children: [
            Icon(_targetClassIcon(target['class']),
                color: _cyanSecondary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (corp.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      corp,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Stats grid
        Row(
          children: [
            Expanded(child: _DetailStat(
              label: 'ВРЕМЯ',
              value: _formatDuration(_estimatedDuration()),
              color: _cyanSecondary,
              icon: Icons.timer_outlined,
            )),
            const SizedBox(width: 12),
            Expanded(child: _DetailStat(
              label: 'НАГРАДА',
              value: '${_formatCredits(_estimatedReward())} cr',
              color: _greenPrimary,
              icon: Icons.attach_money,
            )),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _DetailStat(
              label: 'ТЕПЛОТА',
              value: '+${_estimatedHeat()}',
              color: _dangerRed,
              icon: Icons.local_fire_department,
            )),
            const SizedBox(width: 12),
            Expanded(child: _DetailStat(
              label: 'ЭНЕРГИЯ',
              value: '${_estimatedPower()}',
              color: _goldAccent,
              icon: Icons.bolt,
            )),
          ],
        ),
        const SizedBox(height: 12),

        // Difficulty stars
        Row(
          children: [
            const Text(
              'СЛОЖНОСТЬ',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 8),
            Row(
              children: List.generate(10, (i) {
                final filled = i < difficulty;
                return Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Icon(
                    filled ? Icons.star : Icons.star_outline,
                    color: filled
                        ? (difficulty >= 8
                            ? _dangerRed
                            : difficulty >= 5
                                ? _goldAccent
                                : _greenPrimary)
                        : Colors.grey.shade700,
                    size: 14,
                  ),
                );
              }),
            ),
            const SizedBox(width: 8),
            Text(
              '$difficulty/10',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Security bar
        Row(
          children: [
            const Text(
              'ЗАЩИТА',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (security / 100.0).clamp(0.0, 1.0),
                  backgroundColor: const Color(0xFF1a2332),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _securityColor(security),
                  ),
                  minHeight: 8,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _securityLabel(security),
              style: TextStyle(
                color: _securityColor(security),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Left Panel: Active Operations ─────────────────────────────────────

  Widget _buildActiveOperations(List<Map<String, dynamic>> activeOps) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.explore_outlined, color: _greenPrimary, size: 18),
            SizedBox(width: 8),
            Text(
              'АКТИВНЫЕ ОПЕРАЦИИ',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            SizedBox(width: 8),
            Expanded(child: Divider(color: _surfaceVariant, height: 1)),
          ],
        ),
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
                  'Нет активных операций.',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ...activeOps.map((op) => _buildActiveOpCard(op)),
      ],
    );
  }

  Widget _buildActiveOpCard(Map<String, dynamic> op) {
    final ready = _isReady(op);
    final isCompleting = _completingOps.contains(op['id']);

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
              ? _greenPrimary.withValues(alpha: 0.5)
              : _greenPrimary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          // Status indicator
          Container(
            width: 4,
            height: 48,
            decoration: BoxDecoration(
              color: ready ? _greenPrimary : _cyanSecondary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 14),
          // Info
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
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      targetName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.dns_outlined,
                        color: Colors.grey.shade600, size: 13),
                    const SizedBox(width: 4),
                    Text(
                      serverName,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Icon(Icons.attach_money,
                        color: _greenPrimary.withValues(alpha: 0.5), size: 13),
                    const SizedBox(width: 4),
                    Text(
                      '${_formatCredits(expectedReward)} cr',
                      style: TextStyle(
                        color: _greenPrimary.withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Countdown / complete
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                ready ? 'Готово' : _timeRemaining(op),
                style: TextStyle(
                  color: ready ? _greenPrimary : Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 6),
              ready
                  ? CyberButton(
                      text: 'ЗАБРАТЬ',
                      variant: CyberButtonVariant.success,
                      height: 32,
                      isLoading: isCompleting,
                      onPressed: () => _completeOperation(op),
                    )
                  : const SizedBox(
                      width: 100,
                      height: 32,
                      child: Center(
                        child: SizedBox(
                          width: 14,
                          height: 14,
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

  // ── Right Panel: Target Selection ──────────────────────────────────────

  Widget _buildTargetPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _surfaceVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.gps_fixed, color: _cyanSecondary, size: 20),
              SizedBox(width: 8),
              Text(
                'ВЫБЕРИТЕ ЦЕЛЬ',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_targetsLoading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(color: _cyanSecondary),
              ),
            )
          else if (_targets.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.public_off_outlined,
                        color: Colors.grey.shade600, size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      'Нет доступных целей',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: _targets.map((target) {
                    return _buildTargetCard(target);
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTargetCard(Map<String, dynamic> target) {
    final isSelected =
        _selectedTarget != null && _selectedTarget!['id'] == target['id'];
    final name = target['name'] as String? ?? '—';
    final corp = target['corporation'] as String? ?? '';
    final targetClass = target['class'] as String? ?? '';
    final difficulty = (target['difficulty'] as num?)?.toInt() ?? 1;
    final baseReward = (target['base_reward'] as num?)?.toInt() ?? 0;
    final security = (target['security_level'] as num?)?.toInt() ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => setState(() => _selectedTarget = target),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected
                  ? _cyanSecondary.withValues(alpha: 0.08)
                  : const Color(0xFF0d1420),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? _cyanSecondary.withValues(alpha: 0.6)
                    : _surfaceVariant,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: icon + name + corp
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _cyanSecondary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _targetClassIcon(targetClass),
                        color: _cyanSecondary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              color: isSelected
                                  ? _cyanSecondary
                                  : Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (corp.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              corp,
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Class + difficulty
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _targetClassRu(targetClass),
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Сложность: $difficulty/10',
                      style: TextStyle(
                        color: difficulty >= 8
                            ? _dangerRed
                            : difficulty >= 5
                                ? _goldAccent
                                : _greenPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Reward
                Row(
                  children: [
                    Icon(Icons.attach_money,
                        color: _greenPrimary.withValues(alpha: 0.6), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${_formatCredits(baseReward)} cr',
                      style: const TextStyle(
                        color: _greenPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Security bar
                Row(
                  children: [
                    const Icon(Icons.shield_outlined,
                        color: Colors.grey, size: 12),
                    const SizedBox(width: 4),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: (security / 100.0).clamp(0.0, 1.0),
                          backgroundColor: const Color(0xFF1a2332),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _securityColor(security),
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$security%',
                      style: TextStyle(
                        color: _securityColor(security),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Select button
                SizedBox(
                  width: double.infinity,
                  child: CyberButton(
                    text: isSelected ? 'ВЫБРАНО ✓' : 'ВЫБРАТЬ',
                    variant: isSelected
                        ? CyberButtonVariant.primary
                        : CyberButtonVariant.secondary,
                    height: 34,
                    onPressed: isSelected
                        ? null
                        : () => setState(() => _selectedTarget = target),
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

// ── Detail Stat ───────────────────────────────────────────────────────────

class _DetailStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _DetailStat({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
