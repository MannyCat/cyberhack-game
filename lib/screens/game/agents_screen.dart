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
const _blueAccent = Color(0xFF3b82f6);

// ── Agent Class Data ─────────────────────────────────────────────────────

class _AgentClassInfo {
  final String id;
  final String nameRu;
  final String description;
  final Color color;
  final int baseSalary;

  const _AgentClassInfo({
    required this.id,
    required this.nameRu,
    required this.description,
    required this.color,
    required this.baseSalary,
  });
}

const _agentClasses = [
  _AgentClassInfo(
    id: 'script_kiddie',
    nameRu: 'Скрипт-кидди',
    description: 'Базовый навык, дёшево в содержании',
    color: Color(0xFF9E9E9E),
    baseSalary: 30,
  ),
  _AgentClassInfo(
    id: 'hacker',
    nameRu: 'Хакер',
    description: 'Универсальный специалист для атак',
    color: _greenPrimary,
    baseSalary: 60,
  ),
  _AgentClassInfo(
    id: 'analyst',
    nameRu: 'Аналитик',
    description: 'Анализирует цели, повышает награду',
    color: _cyanSecondary,
    baseSalary: 80,
  ),
  _AgentClassInfo(
    id: 'engineer',
    nameRu: 'Инженер',
    description: 'Улучшает серверы и инфраструктуру',
    color: _blueAccent,
    baseSalary: 100,
  ),
  _AgentClassInfo(
    id: 'mastermind',
    nameRu: 'Мастер-ум',
    description: 'Управляет операциями, максимальная эффективность',
    color: _purpleAccent,
    baseSalary: 150,
  ),
  _AgentClassInfo(
    id: 'ghost',
    nameRu: 'Призрак',
    description: 'Снижает теплоту, незаметность',
    color: _goldAccent,
    baseSalary: 200,
  ),
];

// ── Specialty Data ─────────────────────────────────────────────────────────

const _specialties = [
  (null, 'Без специализации'),
  ('offense', 'Атака'),
  ('defense', 'Защита'),
  ('stealth', 'Стелс'),
  ('economy', 'Экономика'),
  ('research', 'Исследования'),
];

// ── Agents Screen ─────────────────────────────────────────────────────────

class AgentsScreen extends ConsumerStatefulWidget {
  const AgentsScreen({super.key});

  @override
  ConsumerState<AgentsScreen> createState() => _AgentsScreenState();
}

class _AgentsScreenState extends ConsumerState<AgentsScreen> {
  final _supabase = Supabase.instance.client;

  // ── Hire form state ────────────────────────────────────────────────────
  final _nameController = TextEditingController();
  String? _selectedClassId;
  String? _selectedSpecialty;

  // ── Action states ──────────────────────────────────────────────────────
  bool _hiring = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  _AgentClassInfo? _getClassInfo(String? classId) {
    if (classId == null) return null;
    for (final c in _agentClasses) {
      if (c.id == classId) return c;
    }
    return null;
  }

  String _specialtyRu(String? spec) {
    for (final entry in _specialties) {
      if (entry.$1 == spec) return entry.$2;
    }
    return spec ?? '—';
  }

  String _formatCredits(dynamic value) {
    final v = (value as num?)?.toInt() ?? 0;
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toString();
  }

  Color _efficiencyColor(int eff) {
    if (eff > 70) return _greenPrimary;
    if (eff > 40) return _goldAccent;
    return _dangerRed;
  }

  int get _hireCost {
    final info = _getClassInfo(_selectedClassId);
    return (info?.baseSalary ?? 0) * 10;
  }

  int get _hireSalary {
    final info = _getClassInfo(_selectedClassId);
    return info?.baseSalary ?? 0;
  }

  // ── Actions ───────────────────────────────────────────────────────────

  Future<void> _hireAgent() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Введите имя агента'),
          backgroundColor: _dangerRed,
        ),
      );
      return;
    }
    if (_selectedClassId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Выберите класс агента'),
          backgroundColor: _dangerRed,
        ),
      );
      return;
    }

    final credits =
        (ref.read(gameProvider).profile?['credits'] as num?)?.toInt() ?? 0;
    if (credits < _hireCost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Недостаточно кредитов (нужно ${_formatCredits(_hireCost)}, есть ${_formatCredits(credits)})'),
          backgroundColor: _dangerRed,
        ),
      );
      return;
    }

    setState(() => _hiring = true);
    try {
      await _supabase.rpc('hire_agent', params: {
        'p_name': name,
        'p_class': _selectedClassId,
        'p_specialty': _selectedSpecialty,
      });
      await ref.read(gameProvider.notifier).loadAllData();
      if (mounted) {
        _nameController.clear();
        setState(() {
          _selectedClassId = null;
          _selectedSpecialty = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Агент "$name" нанят!'),
            backgroundColor: _greenPrimary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка найма: $e'),
            backgroundColor: _dangerRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _hiring = false);
    }
  }

  Future<void> _toggleAgentActive(Map<String, dynamic> agent) async {
    try {
      final newActive = !(agent['is_active'] as bool? ?? true);
      await _supabase
          .from('agents')
          .update({'is_active': newActive})
          .eq('id', agent['id']);
      await ref.read(gameProvider.notifier).refreshAgents();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: _dangerRed,
          ),
        );
      }
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(gameProvider);
    final agents = game.agents;

    // Compute total salary cost
    int totalSalary = 0;
    for (final agent in agents) {
      final salary = (agent['salary'] as num?)?.toInt() ?? 0;
      final isActive = agent['is_active'] as bool? ?? true;
      if (isActive) totalSalary += salary;
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Left Panel: My Agents ──────────────────────────────────────
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAgentsHeader(agents.length),
                const SizedBox(height: 12),
                Expanded(child: _buildAgentsList(agents)),
                // Total salary footer
                if (agents.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildSalaryFooter(totalSalary),
                ],
              ],
            ),
          ),
          const SizedBox(width: 20),
          // ── Right Panel: Hire Agent ───────────────────────────────────
          Expanded(
            flex: 2,
            child: _buildHirePanel(),
          ),
        ],
      ),
    );
  }

  // ── Left Panel: Header ──────────────────────────────────────────────────

  Widget _buildAgentsHeader(int count) {
    return Row(
      children: [
        const Icon(Icons.group_outlined, color: _greenPrimary, size: 20),
        const SizedBox(width: 8),
        const Text(
          'МОИ АГЕНТЫ',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: _cyanSecondary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: _cyanSecondary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // ── Left Panel: Agents List ─────────────────────────────────────────────

  Widget _buildAgentsList(List<Map<String, dynamic>> agents) {
    if (agents.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _surfaceVariant),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_add_outlined, color: Colors.grey, size: 48),
              SizedBox(height: 16),
              Text(
                'Нет агентов. Нанять первого!',
                style: TextStyle(color: Colors.grey, fontSize: 15),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: agents.map((agent) {
          return _buildAgentCard(agent);
        }).toList(),
      ),
    );
  }

  Widget _buildAgentCard(Map<String, dynamic> agent) {
    final classId = agent['agent_class'] as String? ?? 'script_kiddie';
    final classInfo = _getClassInfo(classId);
    final name = agent['name'] as String? ?? 'Безымянный';
    final skill = (agent['skill_level'] as num?)?.toInt() ?? 0;
    final salary = (agent['salary'] as num?)?.toInt() ?? 0;
    final efficiency = (agent['efficiency'] as num?)?.toInt() ?? 0;
    final specialty = agent['specialty'] as String?;
    final isActive = agent['is_active'] as bool? ?? true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MouseRegion(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isActive ? _surface : Colors.grey.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? (classInfo?.color ?? Colors.grey).withValues(alpha: 0.25)
                  : Colors.grey.shade800,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: avatar placeholder, name, class, toggle
              Row(
                children: [
                  // Avatar circle
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: (classInfo?.color ?? Colors.grey)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: (classInfo?.color ?? Colors.grey)
                            .withValues(alpha: 0.3),
                      ),
                    ),
                    child: Icon(
                      _agentClassIcon(classId),
                      color: classInfo?.color ?? Colors.grey,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            color: isActive
                                ? Colors.white
                                : Colors.grey.shade500,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: (classInfo?.color ?? Colors.grey)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                classInfo?.nameRu ?? classId,
                                style: TextStyle(
                                  color: classInfo?.color ?? Colors.grey,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (specialty != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: _purpleAccent
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _specialtyRu(specialty),
                                  style: const TextStyle(
                                    color: _purpleAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Active/Inactive toggle
                  GestureDetector(
                    onTap: () => _toggleAgentActive(agent),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isActive
                              ? _greenPrimary.withValues(alpha: 0.15)
                              : Colors.grey.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isActive
                                ? _greenPrimary.withValues(alpha: 0.4)
                                : Colors.grey.shade700,
                          ),
                        ),
                        child: Text(
                          isActive ? 'Активен' : 'Отдых',
                          style: TextStyle(
                            color: isActive
                                ? _greenPrimary
                                : Colors.grey.shade500,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Row 2: Skill progress bar
              Row(
                children: [
                  Icon(Icons.psychology,
                      color: Colors.grey.shade500, size: 14),
                  const SizedBox(width: 6),
                  const Text(
                    'НАВЫК',
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
                        value: (skill / 100.0).clamp(0.0, 1.0),
                        backgroundColor: const Color(0xFF1a2332),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          classInfo?.color ?? Colors.grey,
                        ),
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$skill/100',
                    style: TextStyle(
                      color: classInfo?.color ?? Colors.grey,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Row 3: Stats — salary, efficiency
              Row(
                children: [
                  // Salary
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.attach_money,
                            color: _greenPrimary.withValues(alpha: 0.6),
                            size: 13),
                        const SizedBox(width: 4),
                        Text(
                          '$salary cr/ч',
                          style: TextStyle(
                            color: _greenPrimary.withValues(alpha: 0.8),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Efficiency
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _efficiencyColor(efficiency)
                          .withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.speed,
                            color: _efficiencyColor(efficiency)
                                .withValues(alpha: 0.6),
                            size: 13),
                        const SizedBox(width: 4),
                        Text(
                          '$efficiency%',
                          style: TextStyle(
                            color:
                                _efficiencyColor(efficiency),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _agentClassIcon(String classId) {
    switch (classId) {
      case 'script_kiddie':
        return Icons.code;
      case 'hacker':
        return Icons.bug_report;
      case 'analyst':
        return Icons.analytics;
      case 'engineer':
        return Icons.build;
      case 'mastermind':
        return Icons.psychology_alt;
      case 'ghost':
        return Icons.visibility_off;
      default:
        return Icons.person;
    }
  }

  // ── Left Panel: Salary Footer ──────────────────────────────────────────

  Widget _buildSalaryFooter(int totalSalary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _greenPrimary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet,
                  color: _greenPrimary.withValues(alpha: 0.6), size: 16),
              const SizedBox(width: 8),
              const Text(
                'Итого зарплата:',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Text(
            '${_formatCredits(totalSalary)} cr/ч',
            style: const TextStyle(
              color: _greenPrimary,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  // ── Right Panel: Hire Agent ────────────────────────────────────────────

  Widget _buildHirePanel() {
    final credits =
        (ref.watch(gameProvider).profile?['credits'] as num?)?.toInt() ?? 0;
    final canAfford = credits >= _hireCost && _hireCost > 0;
    final isFormValid =
        _nameController.text.trim().isNotEmpty && _selectedClassId != null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _surfaceVariant),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Row(
              children: [
                Icon(Icons.person_add, color: _cyanSecondary, size: 20),
                SizedBox(width: 8),
                Text(
                  'НАЙМ АГЕНТА',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Name field
            const Text(
              'ИМЯ АГЕНТА',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _nameController,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF0d1420),
                hintText: 'Например: Нёйт',
                hintStyle: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: _cyanSecondary.withValues(alpha: 0.3),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: _cyanSecondary.withValues(alpha: 0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: _cyanSecondary,
                    width: 1.5,
                  ),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // Class selector
            const Text(
              'КЛАСС АГЕНТА',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 6),
            _buildClassSelector(),
            const SizedBox(height: 16),

            // Specialty selector
            const Text(
              'СПЕЦИАЛИЗАЦИЯ',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 6),
            _buildSpecialtySelector(),
            const SizedBox(height: 20),

            // Class description
            if (_selectedClassId != null) ...[
              _buildClassDescription(),
              const SizedBox(height: 16),
            ],

            // Cost summary
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0d1420),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _surfaceVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Зарплата:',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        _selectedClassId != null
                            ? '$_hireSalary cr/ч'
                            : '— cr/ч',
                        style: TextStyle(
                          color: _cyanSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [
                            FontFeature.tabularFigures()
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Divider(color: _surfaceVariant, height: 1),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Стоимость найма:',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _selectedClassId != null
                            ? '${_formatCredits(_hireCost)} cr'
                            : '— cr',
                        style: TextStyle(
                          color: canAfford ? _greenPrimary : _dangerRed,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFeatures: const [
                            FontFeature.tabularFigures()
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (_selectedClassId != null && !canAfford)
                    Text(
                      'Недостаточно кредитов (${_formatCredits(credits)})',
                      style: const TextStyle(
                        color: _dangerRed,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Hire button
            SizedBox(
              width: double.infinity,
              child: CyberButton(
                text: 'НАНЯТЬ',
                icon: Icons.person_add,
                variant: CyberButtonVariant.primary,
                height: 48,
                isLoading: _hiring,
                onPressed: (isFormValid && canAfford) ? _hireAgent : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Class Selector ────────────────────────────────────────────────────

  Widget _buildClassSelector() {
    return Column(
      children: _agentClasses.map((classInfo) {
        final isSelected = _selectedClassId == classInfo.id;
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => setState(() => _selectedClassId = classInfo.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? classInfo.color.withValues(alpha: 0.12)
                      : const Color(0xFF0d1420),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? classInfo.color.withValues(alpha: 0.5)
                        : _surfaceVariant,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: classInfo.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        _agentClassIcon(classInfo.id),
                        color: classInfo.color,
                        size: 15,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        classInfo.nameRu,
                        style: TextStyle(
                          color: isSelected
                              ? classInfo.color
                              : Colors.grey.shade400,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${classInfo.baseSalary} cr/ч',
                      style: TextStyle(
                        color: isSelected
                            ? classInfo.color.withValues(alpha: 0.8)
                            : Colors.grey.shade600,
                        fontSize: 11,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Specialty Selector ─────────────────────────────────────────────────

  Widget _buildSpecialtySelector() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0d1420),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _selectedSpecialty != null
              ? _purpleAccent.withValues(alpha: 0.4)
              : _surfaceVariant,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _selectedSpecialty,
          isExpanded: true,
          dropdownColor: const Color(0xFF1a2332),
          hint: const Text(
            'Без специализации',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
          ),
          items: _specialties.map((entry) {
            return DropdownMenuItem<String?>(
              value: entry.$1,
              child: Text(entry.$2),
            );
          }).toList(),
          onChanged: (value) {
            setState(() => _selectedSpecialty = value);
          },
        ),
      ),
    );
  }

  // ── Class Description ───────────────────────────────────────────────────

  Widget _buildClassDescription() {
    final classInfo = _getClassInfo(_selectedClassId);
    if (classInfo == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: classInfo.color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: classInfo.color.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: classInfo.color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              classInfo.description,
              style: TextStyle(
                color: classInfo.color.withValues(alpha: 0.8),
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
