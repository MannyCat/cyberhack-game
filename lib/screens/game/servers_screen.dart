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

// ── Servers Screen ─────────────────────────────────────────────────────────

class ServersScreen extends ConsumerStatefulWidget {
  const ServersScreen({super.key});

  @override
  ConsumerState<ServersScreen> createState() => _ServersScreenState();
}

class _ServersScreenState extends ConsumerState<ServersScreen> {
  final _supabase = Supabase.instance.client;

  // Shop data
  List<Map<String, dynamic>> _serverTypes = [];
  bool _shopLoading = true;

  // Right panel mode: true = shop, false = selected server details
  bool _shopMode = true;

  // Selected server
  Map<String, dynamic>? _selectedServer;

  // Editable server name
  late TextEditingController _nameController;
  bool _nameChanged = false;

  // Action loading states
  bool _buying = false;
  bool _repairing = false;
  bool _disposing = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _loadServerTypes();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // ── Data Loading ────────────────────────────────────────────────────────

  Future<void> _loadServerTypes() async {
    setState(() => _shopLoading = true);
    try {
      final data = await _supabase
          .from('server_types')
          .select()
          .order('sort_order');
      if (mounted) {
        setState(() {
          _serverTypes = List<Map<String, dynamic>>.from(data);
          _shopLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _shopLoading = false);
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _serverClassRu(String cls) {
    switch (cls) {
      case 'basic':
        return 'Базовый';
      case 'advanced':
        return 'Продвинутый';
      case 'premium':
        return 'Премиум';
      case 'elite':
        return 'Элитный';
      case 'legendary':
        return 'Легендарный';
      default:
        return cls;
    }
  }

  Color _serverClassColor(String cls) {
    switch (cls) {
      case 'basic':
        return Colors.grey;
      case 'advanced':
        return _greenPrimary;
      case 'premium':
        return _cyanSecondary;
      case 'elite':
        return _purpleAccent;
      case 'legendary':
        return _goldAccent;
      default:
        return Colors.grey;
    }
  }

  String _formatCredits(dynamic value) {
    final v = (value as num?)?.toInt() ?? 0;
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toString();
  }

  String _serverEmoji(String? typeName) {
    // Fallback emoji mapping if emoji column is missing
    if (typeName == null) return '🖥️';
    switch (typeName.toLowerCase()) {
      case 'basic':
        return '🖥️';
      case 'advanced':
        return '💻';
      case 'premium':
        return '🔧';
      case 'elite':
        return '⚡';
      case 'legendary':
        return '🔮';
      default:
        return '🖥️';
    }
  }

  int _serverHealth(Map<String, dynamic> server) {
    return (server['health'] as num?)?.toInt() ?? 0;
  }

  int _serverMaxHealth(Map<String, dynamic> server) {
    return (server['max_health'] as num?)?.toInt() ?? 100;
  }

  int _serverCurrentLoad(Map<String, dynamic> server) {
    return (server['current_load'] as num?)?.toInt() ?? 0;
  }

  int _serverMaxBandwidth(Map<String, dynamic> server) {
    return (server['max_bandwidth'] as num?)?.toInt() ?? 100;
  }

  int _serverPowerCost(Map<String, dynamic> server) {
    return (server['power_cost'] as num?)?.toInt() ?? 0;
  }

  int _serverSecurity(Map<String, dynamic> server) {
    return (server['security_rating'] as num?)?.toInt() ?? 0;
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> _buyServer(Map<String, dynamic> type) async {
    final credits =
        (ref.read(gameProvider).profile?['credits'] as num?)?.toInt() ?? 0;
    final price = (type['price'] as num?)?.toInt() ?? 0;
    if (credits < price) return;

    setState(() => _buying = true);
    try {
      await _supabase.rpc('buy_server', params: {
        'p_type_id': type['id'],
      });
      await ref.read(gameProvider).notifier.loadAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Сервер "${type['name']}" приобретён!'),
            backgroundColor: _greenPrimary,
            foregroundColor: _bgDark,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка покупки: $e'),
            backgroundColor: _dangerRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  Future<void> _repairServer() async {
    if (_selectedServer == null) return;
    setState(() => _repairing = true);
    try {
      await _supabase.rpc('repair_server', params: {
        'p_server_id': _selectedServer!['id'],
      });
      await ref.read(gameProvider).notifier.loadAllData();
      // Update local selected server with fresh data
      final fresh = ref.read(gameProvider).servers;
      final updated = fresh.where((s) => s['id'] == _selectedServer!['id']).toList();
      if (updated.isNotEmpty) {
        setState(() => _selectedServer = updated.first);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Сервер отремонтирован!'),
            backgroundColor: _greenPrimary,
            foregroundColor: _bgDark,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка ремонта: $e'),
            backgroundColor: _dangerRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _repairing = false);
    }
  }

  Future<void> _disposeServer() async {
    if (_selectedServer == null) return;

    // Confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: _dangerRed),
        ),
        title: const Text(
          'Утилизировать сервер?',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: const Text(
          'Вы получите 30% от стоимости сервера. Это действие необратимо.',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Утилизировать',
              style: TextStyle(color: _dangerRed, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _disposing = true);
    try {
      await _supabase.rpc('dispose_server', params: {
        'p_server_id': _selectedServer!['id'],
      });
      setState(() {
        _selectedServer = null;
        _shopMode = true;
      });
      await ref.read(gameProvider).notifier.loadAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Сервер утилизирован.'),
            backgroundColor: _cyanSecondary,
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
      if (mounted) setState(() => _disposing = false);
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> server) async {
    try {
      final newActive = !(server['is_active'] as bool? ?? true);
      await _supabase
          .from('player_servers')
          .update({'is_active': newActive})
          .eq('id', server['id']);
      await ref.read(gameProvider).notifier.refreshServers();
    } catch (_) {}
  }

  Future<void> _saveServerName() async {
    if (_selectedServer == null || !_nameChanged) return;
    try {
      await _supabase
          .from('player_servers')
          .update({'name': _nameController.text.trim()})
          .eq('id', _selectedServer!['id']);
      await ref.read(gameProvider).notifier.refreshServers();
      setState(() => _nameChanged = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Имя сервера обновлено.'),
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
    }
  }

  void _selectServer(Map<String, dynamic> server) {
    setState(() {
      _selectedServer = server;
      _shopMode = false;
      _nameController.text = server['name'] as String? ?? '';
      _nameChanged = false;
    });
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(gameProvider);
    final servers = game.servers;
    final credits =
        (game.profile?['credits'] as num?)?.toInt() ?? 0;

    // If the selected server was removed, go back to shop
    if (!_shopMode && _selectedServer != null) {
      final exists = servers.any((s) => s['id'] == _selectedServer!['id']);
      if (!exists) {
        _shopMode = true;
        _selectedServer = null;
      }
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Left Panel: Fleet List ───────────────────────────────────
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFleetHeader(servers.length),
                const SizedBox(height: 12),
                Expanded(child: _buildFleetList(servers, credits)),
              ],
            ),
          ),
          const SizedBox(width: 20),
          // ── Right Panel: Details or Shop ──────────────────────────────
          Expanded(
            flex: 2,
            child: _shopMode
                ? _buildShopPanel(credits)
                : _buildDetailsPanel(),
          ),
        ],
      ),
    );
  }

  // ── Left Panel ───────────────────────────────────────────────────────────

  Widget _buildFleetHeader(int count) {
    return Row(
      children: [
        const Icon(Icons.dns_outlined, color: _greenPrimary, size: 20),
        const SizedBox(width: 8),
        const Text(
          'МОЙ ПАРК СЕРВЕРОВ',
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
        const Spacer(),
        CyberButton(
          text: 'КУПИТЬ СЕРВЕР',
          icon: Icons.add_shopping_cart,
          variant: CyberButtonVariant.secondary,
          height: 36,
          onPressed: () => setState(() {
            _shopMode = true;
            _selectedServer = null;
          }),
        ),
      ],
    );
  }

  Widget _buildFleetList(
      List<Map<String, dynamic>> servers, int credits) {
    if (servers.isEmpty) {
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
              Icon(Icons.dns_outlined, color: Colors.grey, size: 48),
              SizedBox(height: 16),
              Text(
                'У вас нет серверов. Купите первый!',
                style: TextStyle(color: Colors.grey, fontSize: 15),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: servers.map((server) {
          final isSelected =
              _selectedServer != null && _selectedServer!['id'] == server['id'];
          final typeData = server['server_types'] as Map<String, dynamic>?;
          final typeName = typeData?['name'] as String? ?? '—';
          final typeClass = typeData?['class'] as String? ?? 'basic';
          final emoji = typeData?['emoji'] as String? ?? _serverEmoji(typeClass);
          final isActive = server['is_active'] as bool? ?? true;
          final health = _serverHealth(server);
          final maxHealth = _serverMaxHealth(server);
          final currentLoad = _serverCurrentLoad(server);
          final maxBandwidth = _serverMaxBandwidth(server);
          final powerCost = _serverPowerCost(server);

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => _selectServer(server),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _serverClassColor(typeClass).withValues(alpha: 0.1)
                        : _surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? _serverClassColor(typeClass).withValues(alpha: 0.5)
                          : _surfaceVariant,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row 1: name + type + toggle
                      Row(
                        children: [
                          Text(
                            emoji,
                            style: const TextStyle(fontSize: 22),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  server['name'] as String? ?? 'Безымянный',
                                  style: TextStyle(
                                    color: isActive
                                        ? Colors.white
                                        : Colors.grey.shade500,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    decoration: isActive
                                        ? TextDecoration.none
                                        : TextDecoration.lineThrough,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: _serverClassColor(typeClass)
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        typeName,
                                        style: TextStyle(
                                          color: _serverClassColor(typeClass),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _serverClassRu(typeClass),
                                      style: TextStyle(
                                        color:
                                            Colors.grey.shade500,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Active/Inactive toggle
                          GestureDetector(
                            onTap: () => _toggleActive(server),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
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
                                isActive ? 'Активен' : 'Отключён',
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
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Row 2: Health bar
                      Row(
                        children: [
                          Icon(Icons.favorite,
                              color: _healthColor(health, maxHealth),
                              size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: maxHealth > 0
                                    ? (health / maxHealth).clamp(0.0, 1.0)
                                    : 0.0,
                                backgroundColor: const Color(0xFF1a2332),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _healthColor(health, maxHealth),
                                ),
                                minHeight: 6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$health/$maxHealth',
                            style: TextStyle(
                              color: _healthColor(health, maxHealth),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Row 3: Bandwidth + power cost
                      Row(
                        children: [
                          Icon(Icons.speed,
                              color: _cyanSecondary.withValues(alpha: 0.6),
                              size: 14),
                          const SizedBox(width: 6),
                          Text(
                            '$currentLoad/$maxBandwidth Мб/с',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 11,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Icon(Icons.bolt,
                              color: _goldAccent.withValues(alpha: 0.6),
                              size: 14),
                          const SizedBox(width: 6),
                          Text(
                            '⚡$powerCost/оп',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _healthColor(int health, int maxHealth) {
    final ratio = maxHealth > 0 ? health / maxHealth : 0.0;
    if (ratio >= 0.6) return _greenPrimary;
    if (ratio >= 0.3) return _goldAccent;
    return _dangerRed;
  }

  // ── Right Panel: Shop ───────────────────────────────────────────────────

  Widget _buildShopPanel(int credits) {
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
              Icon(Icons.storefront, color: _cyanSecondary, size: 20),
              SizedBox(width: 8),
              Text(
                'МАГАЗИН СЕРВЕРОВ',
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
          if (_shopLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: _cyanSecondary),
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: _serverTypes.map((type) {
                    final price = (type['price'] as num?)?.toInt() ?? 0;
                    final typeClass = type['class'] as String? ?? 'basic';
                    final classColor = _serverClassColor(typeClass);
                    final canAfford = credits >= price;
                    final bandwidth =
                        (type['bandwidth'] as num?)?.toInt() ?? 0;
                    final powerCost =
                        (type['power_cost'] as num?)?.toInt() ?? 0;
                    final security =
                        (type['security'] as num?)?.toInt() ?? 0;
                    final storage =
                        (type['storage'] as num?)?.toInt() ?? 0;
                    final emoji = type['emoji'] as String? ??
                        _serverEmoji(typeClass);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: MouseRegion(
                        cursor: canAfford
                            ? SystemMouseCursors.click
                            : SystemMouseCursors.basic,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0d1420),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: classColor.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header row
                              Row(
                                children: [
                                  Text(emoji, style: const TextStyle(fontSize: 24)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          type['name'] as String? ?? '—',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _serverClassRu(typeClass),
                                          style: TextStyle(
                                            color: classColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${_formatCredits(price)} ₽',
                                    style: TextStyle(
                                      color: canAfford
                                          ? _greenPrimary
                                          : _dangerRed,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures()
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              // Stats row
                              Row(
                                children: [
                                  _ShopStat(
                                    icon: Icons.speed,
                                    label: 'ШИР.',
                                    value: '$bandwidth Мб/с',
                                    color: _cyanSecondary,
                                  ),
                                  const SizedBox(width: 12),
                                  _ShopStat(
                                    icon: Icons.bolt,
                                    label: 'ЭН.',
                                    value: '$powerCost',
                                    color: _goldAccent,
                                  ),
                                  const SizedBox(width: 12),
                                  _ShopStat(
                                    icon: Icons.shield,
                                    label: 'ЗАЩ.',
                                    value: '$security',
                                    color: _greenPrimary,
                                  ),
                                  const SizedBox(width: 12),
                                  _ShopStat(
                                    icon: Icons.storage,
                                    label: 'ХРН.',
                                    value: '$storage ГБ',
                                    color: _purpleAccent,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Buy button
                              SizedBox(
                                width: double.infinity,
                                child: CyberButton(
                                  text: 'КУПИТЬ',
                                  variant: canAfford
                                      ? CyberButtonVariant.primary
                                      : CyberButtonVariant.secondary,
                                  height: 38,
                                  isLoading: _buying,
                                  onPressed: canAfford
                                      ? () => _buyServer(type)
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Right Panel: Server Details ─────────────────────────────────────────

  Widget _buildDetailsPanel() {
    if (_selectedServer == null) return const SizedBox.shrink();

    final server = _selectedServer!;
    final typeData = server['server_types'] as Map<String, dynamic>?;
    final typeName = typeData?['name'] as String? ?? '—';
    final typeClass = typeData?['class'] as String? ?? 'basic';
    final classColor = _serverClassColor(typeClass);
    final emoji = typeData?['emoji'] as String? ?? _serverEmoji(typeClass);

    final health = _serverHealth(server);
    final maxHealth = _serverMaxHealth(server);
    final currentLoad = _serverCurrentLoad(server);
    final maxBandwidth = _serverMaxBandwidth(server);
    final powerCost = _serverPowerCost(server);
    final security = _serverSecurity(server);

    // Sync name controller if it changed externally
    if (_nameController.text != (server['name'] as String? ?? '') &&
        !_nameChanged) {
      _nameController.text = server['name'] as String? ?? '';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: classColor.withValues(alpha: 0.3),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ДЕТАЛИ СЕРВЕРА',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        typeName,
                        style: TextStyle(
                          color: classColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Close button
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _shopMode = true;
                      _selectedServer = null;
                      _nameChanged = false;
                    }),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.close,
                          color: Colors.grey, size: 18),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Editable server name
            const Text(
              'ИМЯ СЕРВЕРА',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF0d1420),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: classColor.withValues(alpha: 0.3),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: classColor.withValues(alpha: 0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: _cyanSecondary,
                          width: 1.5,
                        ),
                      ),
                    ),
                    onChanged: (_) => setState(() => _nameChanged = true),
                  ),
                ),
                if (_nameChanged) ...[
                  const SizedBox(width: 8),
                  CyberButton(
                    text: 'СОХР.',
                    variant: CyberButtonVariant.primary,
                    height: 42,
                    onPressed: _saveServerName,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),

            // Health
            _DetailRow(
              label: 'ПРОЧНОСТЬ',
              value: '$health/$maxHealth',
              valueColor: _healthColor(health, maxHealth),
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: maxHealth > 0
                        ? (health / maxHealth).clamp(0.0, 1.0)
                        : 0.0,
                    backgroundColor: const Color(0xFF1a2332),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _healthColor(health, maxHealth),
                    ),
                    minHeight: 8,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Bandwidth
            _DetailRow(
              label: 'ПРОПУСКНАЯ СПОСОБНОСТЬ',
              value: '$currentLoad/$maxBandwidth Мб/с',
              valueColor: _cyanSecondary,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: maxBandwidth > 0
                        ? (currentLoad / maxBandwidth).clamp(0.0, 1.0)
                        : 0.0,
                    backgroundColor: const Color(0xFF1a2332),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        _cyanSecondary),
                    minHeight: 8,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Power cost
            _DetailRow(
              label: 'РАСХОД ЭНЕРГИИ',
              value: '$powerCost за операцию',
              valueColor: _goldAccent,
            ),
            const SizedBox(height: 16),

            // Security
            _DetailRow(
              label: 'УРОВЕНЬ ЗАЩИТЫ',
              value: '$security/100',
              valueColor: _greenPrimary,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (security / 100).clamp(0.0, 1.0),
                    backgroundColor: const Color(0xFF1a2332),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        _greenPrimary),
                    minHeight: 8,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: CyberButton(
                    text: 'РЕМОНТ',
                    icon: Icons.build,
                    variant: CyberButtonVariant.secondary,
                    height: 44,
                    isLoading: _repairing,
                    onPressed: health < maxHealth ? _repairServer : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CyberButton(
                    text: 'УТИЛИЗИРОВАТЬ',
                    icon: Icons.delete_forever,
                    variant: CyberButtonVariant.danger,
                    height: 44,
                    isLoading: _disposing,
                    onPressed: _disposeServer,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shop Stat Widget ──────────────────────────────────────────────────────

class _ShopStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _ShopStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color.withValues(alpha: 0.7), size: 13),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Detail Row Widget ─────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final Widget? child;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.valueColor,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (child != null) child!,
      ],
    );
  }
}
