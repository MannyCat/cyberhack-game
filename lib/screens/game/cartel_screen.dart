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
const _cyanSecondary = Color(0xFF00d4ff);
const _goldAccent = Color(0xFFFFD700);
const _dangerRed = Color(0xFFff4444);

// ── Cartel Screen ────────────────────────────────────────────────────────

class CartelScreen extends ConsumerStatefulWidget {
  const CartelScreen({super.key});

  @override
  ConsumerState<CartelScreen> createState() => _CartelScreenState();
}

class _CartelScreenState extends ConsumerState<CartelScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isCreating = false;

  // Cartel data
  Map<String, dynamic>? _cartel;
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _availableCartels = [];
  bool _actionInProgress = false;

  // Create form controllers
  final _nameController = TextEditingController();
  final _tagController = TextEditingController();
  final _descController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _tagController.dispose();
    _descController.dispose();
    super.dispose();
  }

  // ── Data Loading ──────────────────────────────────────────────────────

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final game = ref.read(gameProvider);
      final clanId = game.clanId;

      if (clanId != null) {
        await _loadCartelInfo(clanId);
      } else {
        await _loadAvailableCartels();
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadCartelInfo(String clanId) async {
    // Fetch cartel data
    final cartelData = await _supabase
        .from('clans')
        .select()
        .eq('id', clanId)
        .single();
    _cartel = cartelData;

    // Fetch members with profile info
    final membersData = await _supabase
        .from('clan_members')
        .select('*, profiles!clan_members_user_id_fkey(username)')
        .eq('clan_id', clanId);
    _members = membersData;
  }

  Future<void> _loadAvailableCartels() async {
    final data = await _supabase
        .from('clans')
        .select('*, profiles!clans_leader_id_fkey(username)')
        .order('created_at', ascending: false)
        .limit(50);

    // Get member counts for each cartel
    final List<Map<String, dynamic>> enriched = [];
    for (final cartel in data) {
      final countData = await _supabase
          .from('clan_members')
          .select('id')
          .eq('clan_id', cartel['id'] as String);
      enriched.add({
        ...cartel,
        'member_count': countData.length,
      });
    }
    _availableCartels = enriched;
  }

  // ── Actions ──────────────────────────────────────────────────────────

  Future<void> _createCartel() async {
    final name = _nameController.text.trim();
    final tag = _tagController.text.trim();
    final desc = _descController.text.trim();

    if (name.isEmpty || tag.isEmpty || tag.length < 3 || tag.length > 5) {
      _showError('Заполните все поля. Тег: 3-5 символов.');
      return;
    }

    setState(() => _isCreating = true);
    try {
      final userId = _supabase.auth.currentUser!.id;

      // Create clan
      final clanData = await _supabase.from('clans').insert({
        'name': name,
        'tag': tag.toUpperCase(),
        'description': desc,
        'leader_id': userId,
        'max_members': 20,
      }).select().single();

      // Join as leader
      await _supabase.from('clan_members').insert({
        'clan_id': clanData['id'],
        'user_id': userId,
        'role': 'leader',
      });

      // Update profile
      await _supabase
          .from('profiles')
          .update({'clan_id': clanData['id']})
          .eq('id', userId);

      // Refresh game data
      await ref.read(gameProvider.notifier).loadAllData();

      if (mounted) {
        _nameController.clear();
        _tagController.clear();
        _descController.clear();
        _showSuccess('Картель «$name» создан!');
        _loadData();
      }
    } catch (e) {
      if (mounted) _showError('Ошибка создания: $e');
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<void> _joinCartel(String cartelId) async {
    if (_actionInProgress) return;
    setState(() => _actionInProgress = true);
    try {
      final userId = _supabase.auth.currentUser!.id;

      await _supabase.from('clan_members').insert({
        'clan_id': cartelId,
        'user_id': userId,
        'role': 'member',
      });

      await _supabase
          .from('profiles')
          .update({'clan_id': cartelId})
          .eq('id', userId);

      await ref.read(gameProvider.notifier).loadAllData();

      if (mounted) {
        _showSuccess('Вы вступили в картель!');
        _loadData();
      }
    } catch (e) {
      if (mounted) _showError('Ошибка: $e');
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _leaveCartel() async {
    if (_actionInProgress) return;
    setState(() => _actionInProgress = true);
    try {
      final userId = _supabase.auth.currentUser!.id;
      final clanId = ref.read(gameProvider).clanId!;

      await _supabase
          .from('clan_members')
          .delete()
          .match({'clan_id': clanId, 'user_id': userId});

      await _supabase
          .from('profiles')
          .update({'clan_id': null})
          .eq('id', userId);

      await ref.read(gameProvider.notifier).loadAllData();

      if (mounted) {
        _showSuccess('Вы покинули картель.');
        _cartel = null;
        _members = [];
        _loadData();
      }
    } catch (e) {
      if (mounted) _showError('Ошибка: $e');
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _disbandCartel() async {
    if (_actionInProgress) return;

    // Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: _dangerRed.withValues(alpha: 0.4)),
        ),
        title: const Text(
          'Распустить картель?',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: const Text(
          'Это действие необратимо. Все участники будут исключены.',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
        actions: [
          CyberButton(
            text: 'ОТМЕНА',
            variant: CyberButtonVariant.secondary,
            height: 36,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          CyberButton(
            text: 'РАСПУСТИТЬ',
            variant: CyberButtonVariant.danger,
            height: 36,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _actionInProgress = true);
    try {
      final userId = _supabase.auth.currentUser!.id;
      final clanId = ref.read(gameProvider).clanId!;

      // Remove all members
      await _supabase
          .from('clan_members')
          .delete()
          .eq('clan_id', clanId);

      // Update all profiles
      await _supabase
          .from('profiles')
          .update({'clan_id': null})
          .eq('clan_id', clanId);

      // Delete clan
      await _supabase.from('clans').delete().eq('id', clanId);

      await ref.read(gameProvider.notifier).loadAllData();

      if (mounted) {
        _showSuccess('Картель распущен.');
        _cartel = null;
        _members = [];
        _loadData();
      }
    } catch (e) {
      if (mounted) _showError('Ошибка: $e');
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _toggleMemberRole(String memberId, String currentRole) async {
    try {
      final newRole = currentRole == 'officer' ? 'member' : 'officer';
      await _supabase
          .from('clan_members')
          .update({'role': newRole})
          .eq('id', memberId);
      _loadData();
    } catch (e) {
      if (mounted) _showError('Ошибка: $e');
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: _dangerRed),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _greenPrimary,
        foregroundColor: _bgDark,
      ),
    );
  }

  bool _isLeader() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null || _cartel == null) return false;
    return _cartel!['leader_id'] == userId;
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'leader':
        return 'Лидер';
      case 'officer':
        return 'Офицер';
      default:
        return 'Участник';
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'leader':
        return _goldAccent;
      case 'officer':
        return _cyanSecondary;
      default:
        return Colors.grey;
    }
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(gameProvider);

    if (game.isLoading || _isLoading) {
      return const Center(child: CircularProgressIndicator(color: _greenPrimary));
    }

    final isInCartel = game.clanId != null;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: isInCartel ? _buildCartelView() : _buildNoCartelView(),
    );
  }

  // ── No Cartel View ──────────────────────────────────────────────────

  Widget _buildNoCartelView() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          children: [
            // ── Join/Create Card ──────────────────────────────────────
            _buildJoinCreateCard(),
            const SizedBox(height: 32),

            // ── Divider ───────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 1,
                    color: _surfaceVariant,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'ИЛИ',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 1,
                    color: _surfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Cartel List ──────────────────────────────────────────
            _buildCartelList(),
          ],
        ),
      ),
    );
  }

  Widget _buildJoinCreateCard() {
    return Container(
      width: 500,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _surfaceVariant),
        boxShadow: [
          BoxShadow(
            color: _greenPrimary.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          const Row(
            children: [
              Icon(Icons.shield_outlined, color: _goldAccent, size: 28),
              SizedBox(width: 12),
              Text(
                'Вступите в картель',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Объединитесь с другими хакерами для совместных операций',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 24),

          // Divider
          const Text(
            'Или создайте свой:',
            style: TextStyle(
              color: _cyanSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),

          // Name field
          _buildTextField(
            controller: _nameController,
            label: 'Название картеля',
            icon: Icons.label_outlined,
          ),
          const SizedBox(height: 12),

          // Tag field
          _buildTextField(
            controller: _tagController,
            label: 'Тег (3-5 символов)',
            icon: Icons.tag,
            maxLength: 5,
          ),
          const SizedBox(height: 12),

          // Description field
          _buildTextField(
            controller: _descController,
            label: 'Описание',
            icon: Icons.description_outlined,
            maxLines: 2,
          ),
          const SizedBox(height: 20),

          // Create button
          SizedBox(
            width: double.infinity,
            child: CyberButton(
              text: 'СОЗДАТЬ КАРТЕЛЬ',
              variant: CyberButtonVariant.primary,
              height: 48,
              isLoading: _isCreating,
              onPressed: _isCreating ? null : _createCartel,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLength = 40,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 12),
        prefixIcon: Icon(icon, color: Colors.grey.shade500, size: 18),
        filled: true,
        fillColor: _surfaceVariant.withValues(alpha: 0.5),
        counterStyle: TextStyle(color: Colors.grey.shade600, fontSize: 10),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _surfaceVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: _greenPrimary.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: maxLines > 1 ? 12 : 0,
        ),
      ),
    );
  }

  Widget _buildCartelList() {
    return SizedBox(
      width: 600,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.list_alt, color: _cyanSecondary, size: 18),
              SizedBox(width: 8),
              Text(
                'СПИСОК КАРТЕЛЕЙ',
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
          const SizedBox(height: 12),
          if (_availableCartels.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _surfaceVariant),
              ),
              child: const Center(
                child: Text(
                  'Картелей пока нет. Создайте первый!',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
            )
          else
            ..._availableCartels.map((cartel) => _buildCartelRow(cartel)),
        ],
      ),
    );
  }

  Widget _buildCartelRow(Map<String, dynamic> cartel) {
    final memberCount = cartel['member_count'] as int? ?? 0;
    final maxMembers = (cartel['max_members'] as num?)?.toInt() ?? 20;
    final leaderName = (cartel['profiles'] as Map<String, dynamic>?)?['username']
            as String? ??
        '—';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _surfaceVariant),
        ),
        child: Row(
          children: [
            // Tag badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _goldAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _goldAccent.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                cartel['tag'] as String? ?? '???',
                style: const TextStyle(
                  color: _goldAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Name + leader
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cartel['name'] as String? ?? 'Безымянный',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Лидер: $leaderName · $memberCount/$maxMembers',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Join button
            CyberButton(
              text: 'ВСТУПИТЬ',
              variant: CyberButtonVariant.secondary,
              height: 34,
              isLoading: _actionInProgress,
              onPressed: _actionInProgress
                  ? null
                  : () => _joinCartel(cartel['id'] as String),
            ),
          ],
        ),
      ),
    );
  }

  // ── Cartel View (IN cartel) ────────────────────────────────────────

  Widget _buildCartelView() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left panel — cartel info
        Expanded(
          flex: 2,
          child: _buildCartelInfoPanel(),
        ),
        const SizedBox(width: 20),
        // Right panel — members
        Expanded(
          flex: 3,
          child: _buildMembersPanel(),
        ),
      ],
    );
  }

  Widget _buildCartelInfoPanel() {
    if (_cartel == null) {
      return const Center(child: CircularProgressIndicator(color: _greenPrimary));
    }

    final isLeader = _isLeader();
    final memberCount = _members.length;
    final maxMembers = (_cartel!['max_members'] as num?)?.toInt() ?? 20;

    // Find leader name
    final leaderMember = _members.firstWhere(
      (m) => m['role'] == 'leader',
      orElse: () => const {},
    );
    final leaderProfile = leaderMember['profiles'] as Map<String, dynamic>?;
    final leaderName = leaderProfile?['username'] as String? ?? '—';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _goldAccent.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Shield icon
          const Icon(Icons.shield, color: _goldAccent, size: 36),
          const SizedBox(height: 16),

          // Name + tag
          Row(
            children: [
              Text(
                _cartel!['name'] as String? ?? 'Картель',
                style: const TextStyle(
                  color: _goldAccent,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _goldAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _goldAccent.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  '[${_cartel!['tag'] as String? ?? '???'}]',
                  style: const TextStyle(
                    color: _goldAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Description
          if (_cartel!['description'] != null &&
              (_cartel!['description'] as String).isNotEmpty) ...[
            Text(
              _cartel!['description'] as String,
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
          ] else
            const SizedBox(height: 20),

          // Stats
          _InfoRow(
            icon: Icons.people_outline,
            label: 'Участники',
            value: '$memberCount / $maxMembers',
            valueColor: _cyanSecondary,
          ),
          const SizedBox(height: 10),
          _InfoRow(
            icon: Icons.star_outline,
            label: 'Лидер',
            value: leaderName,
            valueColor: _goldAccent,
          ),
          const SizedBox(height: 24),

          // Divider
          const Divider(color: _surfaceVariant),
          const SizedBox(height: 16),

          // Action button
          if (isLeader)
            CyberButton(
              text: 'РАСПУСТИТЬ КАРТЕЛЬ',
              variant: CyberButtonVariant.danger,
              height: 42,
              icon: Icons.delete_forever,
              isLoading: _actionInProgress,
              onPressed: _actionInProgress ? null : _disbandCartel,
            )
          else
            CyberButton(
              text: 'ПОКИНУТЬ',
              variant: CyberButtonVariant.danger,
              height: 42,
              icon: Icons.logout,
              isLoading: _actionInProgress,
              onPressed: _actionInProgress ? null : _leaveCartel,
            ),
        ],
      ),
    );
  }

  Widget _buildMembersPanel() {
    if (_cartel == null) {
      return const Center(child: CircularProgressIndicator(color: _greenPrimary));
    }

    final isLeader = _isLeader();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.people, color: _greenPrimary, size: 18),
            SizedBox(width: 8),
            Text(
              'УЧАСТНИКИ',
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
        if (_members.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _surfaceVariant),
            ),
            child: const Center(
              child: Text(
                'Нет участников.',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _surfaceVariant),
            ),
            child: Column(
              children: _members.asMap().entries.map((entry) {
                final idx = entry.key;
                final member = entry.value;
                final role = member['role'] as String? ?? 'member';
                final profile =
                    member['profiles'] as Map<String, dynamic>?;
                final username =
                    profile?['username'] as String? ?? 'Неизвестный';
                final currentUserId = _supabase.auth.currentUser?.id;
                final isSelf = member['user_id'] == currentUserId;

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: idx < _members.length - 1
                        ? const Border(
                            bottom: BorderSide(color: _surfaceVariant),
                          )
                        : null,
                    color: isSelf
                        ? _greenPrimary.withValues(alpha: 0.05)
                        : null,
                  ),
                  child: Row(
                    children: [
                      // Avatar placeholder
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _roleColor(role).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _roleColor(role).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            username.isNotEmpty ? username[0].toUpperCase() : '?',
                            style: TextStyle(
                              color: _roleColor(role),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Name
                      Expanded(
                        child: Text(
                          username + (isSelf ? ' (вы)' : ''),
                          style: TextStyle(
                            color: isSelf ? _greenPrimary : Colors.white,
                            fontSize: 14,
                            fontWeight:
                                isSelf ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ),
                      // Role badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _roleColor(role).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _roleColor(role).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          _roleLabel(role),
                          style: TextStyle(
                            color: _roleColor(role),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      // Leader actions
                      if (isLeader && role != 'leader') ...[
                        const SizedBox(width: 10),
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () =>
                                _toggleMemberRole(member['id'] as String, role),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _surfaceVariant,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey.shade700),
                              ),
                              child: Text(
                                role == 'officer' ? '−' : '+',
                                style: TextStyle(
                                  color: role == 'officer'
                                      ? _dangerRed
                                      : _cyanSecondary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

// ── Info Row Helper ─────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey.shade500, size: 16),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
