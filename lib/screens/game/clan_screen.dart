import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/game_provider.dart';
import '../../providers/auth_provider.dart';

// ─── ClanScreen — PC Desktop Layout ──────────────────────────────────────────
// Child of GameShell (provides sidebar + top bar).
// No Scaffold/AppBar — content-only widget.
//   • In clan: two-column layout — clan info left (40%), member table right (60%)
//   • Not in clan: centered create/search panel (maxWidth: 800)
// Member list as a table (name, role, level, status).
// Clan actions as buttons in header row.
// Russian text, dark cyberpunk theme (Color(0xFF0a0e17)).

// ═══════════════════════════════════════════════════════════════════════════
// SHARED THEME CONSTANTS (top-level to avoid Dart library-private conflicts)
// ═══════════════════════════════════════════════════════════════════════════

const _kBg = Color(0xFF0a0e17);
const _kSurface = Color(0xFF0d1220);
const _kBorder = Color(0xFF1e2a3a);
const _kBorderLight = Color(0xFF2a3a4e);
const _kNeonPrimary = Color(0xFFa855f7);
const _kNeonCyan = Color(0xFF00e5ff);
const _kNeonGreen = Color(0xFF00FF41);
const _kNeonAmber = Color(0xFFFFD700);
const _kNeonRed = Color(0xFFFF0040);
const _kTextPrimary = Color(0xFFe0e6ed);
const _kTextSecondary = Color(0xFF6a7080);
const _kTextMuted = Color(0xFF3a4555);

class ClanScreen extends StatefulWidget {
  const ClanScreen({super.key});

  @override
  State<ClanScreen> createState() => _ClanScreenState();
}

class _ClanScreenState extends State<ClanScreen> {
  // ── Create Clan Form ────────────────────────────────────────────────────
  final _clanNameController = TextEditingController();
  final _clanTagController = TextEditingController();
  final _clanDescController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isCreating = false;

  // ── State ────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _publicClans = [];
  List<Map<String, dynamic>> _myClanInfo = [];
  bool _isLoadingClans = false;
  bool _isLoadingMyClan = false;
  bool _showCreateForm = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _clanNameController.dispose();
    _clanTagController.dispose();
    _clanDescController.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DATA LOGIC (preserved exactly)
  // ══════════════════════════════════════════════════════════════════════════

  void _loadData() {
    final auth = context.read<AuthProvider>();
    if (auth.profile?.clanId != null) {
      _loadMyClan(auth.profile!.clanId!);
    } else {
      _loadPublicClans();
    }
  }

  Future<void> _loadPublicClans() async {
    setState(() {
      _isLoadingClans = true;
      _errorMessage = null;
    });
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('clans')
          .select('*, clan_members(count)')
          .order('created_at', ascending: false)
          .limit(50);
      if (!mounted) return;
      setState(() {
        _publicClans = (response as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _isLoadingClans = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Не удалось загрузить кланы';
        _isLoadingClans = false;
      });
    }
  }

  Future<void> _loadMyClan(String clanId) async {
    setState(() => _isLoadingMyClan = true);
    final game = context.read<GameProvider>();
    final info = await game.getClanInfo(clanId);
    if (!mounted) return;
    setState(() {
      _myClanInfo = info;
      _isLoadingMyClan = false;
    });
  }

  Future<void> _createClan() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    if (auth.userId == null) return;

    setState(() => _isCreating = true);

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.from('clans').insert({
        'name': _clanNameController.text.trim(),
        'tag': _clanTagController.text.trim().toUpperCase(),
        'description': _clanDescController.text.trim(),
        'leader_id': auth.userId,
      }).select().single();

      final clanId = response['id'] as String;

      await supabase.from('clan_members').insert({
        'clan_id': clanId,
        'player_id': auth.userId,
        'role': 'leader',
      });

      await supabase.from('profiles').update({
        'clan_id': clanId,
      }).eq('id', auth.userId!);

      await auth.refreshProfile();

      if (!mounted) return;
      setState(() {
        _showCreateForm = false;
        _isCreating = false;
      });
      _loadMyClan(clanId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Клан создан успешно!'),
          backgroundColor: Colors.greenAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCreating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось создать клан: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _joinClan(String clanId) async {
    final auth = context.read<AuthProvider>();
    if (auth.userId == null) return;

    final game = context.read<GameProvider>();
    final success =
        await game.joinClan(playerId: auth.userId!, clanId: clanId);

    if (!mounted) return;
    if (success) {
      await auth.refreshProfile();
      _loadMyClan(clanId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Вступили в клан!'),
          backgroundColor: Colors.greenAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось вступить в клан'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _leaveClan() async {
    final auth = context.read<AuthProvider>();
    if (auth.userId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _kSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: _kNeonRed.withValues(alpha: 0.5)),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: _kNeonRed),
            SizedBox(width: 10),
            Text('ПОКИНУТЬ КЛАН?', style: TextStyle(color: _kTextPrimary)),
          ],
        ),
        content: const Text(
          'Вы уверены, что хотите покинуть клан? Это действие нельзя отменить.',
          style: TextStyle(color: _kTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ОТМЕНА', style: TextStyle(color: _kTextSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: _kNeonRed),
            child: const Text('ПОКИНУТЬ'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final game = context.read<GameProvider>();
    final success = await game.leaveClan(playerId: auth.userId!);

    if (!mounted) return;
    if (success) {
      await auth.refreshProfile();
      setState(() => _myClanInfo = []);
      _loadPublicClans();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Покинули клан'),
          backgroundColor: Colors.orangeAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось покинуть клан'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;
    final isInClan = profile?.clanId != null;

    return Container(
      color: _kBg,
      child: isInClan
          ? _buildMyClanView(profile!)
          : _buildNoClanView(),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MY CLAN VIEW — Two-column: info left (40%) + member table right (60%)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildMyClanView(PlayerProfile profile) {
    if (_isLoadingMyClan || _myClanInfo.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: _kNeonPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Загрузка данных клана...',
              style: TextStyle(color: _kTextSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    final clanData = _myClanInfo.first;
    final name = clanData['name'] as String? ?? 'Неизвестный клан';
    final tag = clanData['tag'] as String? ?? '???';
    final description = clanData['description'] as String? ?? '';
    final members =
        List<Map<String, dynamic>>.from(clanData['clan_members'] as List? ?? []);
    final createdAt = clanData['created_at'] as String?;
    final myUserId = context.read<AuthProvider>().userId;

    // Sort: leader → officer → member
    members.sort((a, b) =>
        _rolePriority(a['role'] as String?).compareTo(_rolePriority(b['role'] as String?)));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Row: clan badge + name + description + action buttons ──
          _buildClanHeader(name, tag, description, profile.clanId!, members.length, createdAt),
          const SizedBox(height: 24),

          // ── Two-column layout ───────────────────────────────────────────
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // LEFT — Clan Info (40%)
                Expanded(
                  flex: 4,
                  child: _buildClanInfoPanel(
                    name: name,
                    tag: tag,
                    description: description,
                    memberCount: members.length,
                    createdAt: createdAt,
                  ),
                ),
                const SizedBox(width: 20),
                // RIGHT — Member Table (60%)
                Expanded(
                  flex: 6,
                  child: _buildMemberTablePanel(members, myUserId),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Clan Header Row ─────────────────────────────────────────────────────

  Widget _buildClanHeader(
    String name,
    String tag,
    String description,
    String clanId,
    int memberCount,
    String? createdAt,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [
            _kNeonPrimary.withValues(alpha: 0.08),
            _kNeonCyan.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: _kNeonPrimary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          // Tag badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _kNeonPrimary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kNeonPrimary.withValues(alpha: 0.4)),
              boxShadow: [
                BoxShadow(
                  color: _kNeonPrimary.withValues(alpha: 0.15),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Text(
              '[$tag]',
              style: const TextStyle(
                color: _kNeonPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 2,
                fontFamily: 'monospace',
                shadows: [Shadow(color: _kNeonPrimary, blurRadius: 8)],
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: _kTextPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      description,
                      style: const TextStyle(color: _kTextSecondary, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          // Stats pills
          _buildStatPill(Icons.people_rounded, '$memberCount участников', _kNeonCyan),
          const SizedBox(width: 8),
          if (createdAt != null)
            _buildStatPill(Icons.calendar_today_rounded, _formatDate(createdAt), _kTextMuted),
          const SizedBox(width: 16),
          // Action buttons
          _HeaderActionButton(
            icon: Icons.refresh_rounded,
            label: 'ОБНОВИТЬ',
            color: _kNeonCyan,
            onPressed: () => _loadMyClan(clanId),
          ),
          const SizedBox(width: 8),
          _HeaderActionButton(
            icon: Icons.exit_to_app_rounded,
            label: 'ПОКИНУТЬ',
            color: _kNeonRed,
            onPressed: _leaveClan,
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ── Left Panel: Clan Info (40%) ────────────────────────────────────────

  Widget _buildClanInfoPanel({
    required String name,
    required String tag,
    required String description,
    required int memberCount,
    String? createdAt,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: _kNeonPrimary, size: 18),
              SizedBox(width: 8),
              Text(
                'ИНФОРМАЦИЯ',
                style: TextStyle(
                  color: _kNeonPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          Divider(color: _kBorder, height: 24),

          // Clan emblem
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _kNeonPrimary.withValues(alpha: 0.15),
                    _kNeonCyan.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kNeonPrimary.withValues(alpha: 0.35)),
                boxShadow: [
                  BoxShadow(color: _kNeonPrimary.withValues(alpha: 0.1), blurRadius: 16),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                tag.length > 3 ? tag.substring(0, 3) : tag,
                style: const TextStyle(
                  color: _kNeonPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Detail rows
          _InfoRow(label: 'Название', value: name),
          const SizedBox(height: 12),
          _InfoRow(label: 'Тег', value: '[$tag]'),
          const SizedBox(height: 12),
          _InfoRow(label: 'Участников', value: '$memberCount'),
          const SizedBox(height: 12),
          if (createdAt != null)
            _InfoRow(label: 'Создан', value: _formatDate(createdAt)),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: _kBorder, height: 24),
            const Text(
              'ОПИСАНИЕ',
              style: TextStyle(
                color: _kTextMuted,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(color: _kTextSecondary, fontSize: 13, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }

  // ── Right Panel: Member Table (60%) ───────────────────────────────────

  Widget _buildMemberTablePanel(
    List<Map<String, dynamic>> members,
    String? myUserId,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _kBorder.withValues(alpha: 0.3),
              border: Border(bottom: BorderSide(color: _kBorder)),
            ),
            child: Row(
              children: const [
                SizedBox(width: 36), // avatar space
                Expanded(flex: 3, child: _TableHeaderCell(label: 'ИМЯ', flex: 3)),
                SizedBox(width: 12),
                Expanded(flex: 2, child: _TableHeaderCell(label: 'РОЛЬ', flex: 2)),
                SizedBox(width: 12),
                Expanded(flex: 1, child: _TableHeaderCell(label: 'УРОВЕНЬ', flex: 1)),
                SizedBox(width: 12),
                Expanded(flex: 2, child: _TableHeaderCell(label: 'СТАТУС', flex: 2)),
                SizedBox(width: 16), // actions space
              ],
            ),
          ),
          // Member rows
          if (members.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: Text(
                  'Нет участников',
                  style: TextStyle(color: _kTextMuted, fontSize: 14),
                ),
              ),
            )
          else
            ...members.map((member) {
              final memberProfile =
                  member['profiles'] as Map<String, dynamic>?;
              final username =
                  memberProfile?['username'] as String? ?? 'Неизвестный';
              final role = member['role'] as String? ?? 'member';
              final level = memberProfile?['level'] as int? ?? 1;
              final playerId = member['player_id'] as String?;
              final isMe = playerId == myUserId;
              final isOnline =
                  memberProfile?['is_online'] as bool? ?? false;

              return _MemberTableRow(
                username: username,
                role: role,
                level: level,
                isOnline: isOnline,
                isMe: isMe,
              );
            }),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // NO CLAN VIEW — Centered create/search panel
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildNoClanView() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Banner ────────────────────────────────────────────
              _buildNoClanBanner(),
              const SizedBox(height: 24),

              // ── Action Buttons Row ────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.add_circle_outline_rounded,
                      label: 'СОЗДАТЬ КЛАН',
                      description: 'Создайте свой клан и станьте лидером',
                      color: _kNeonPrimary,
                      isActive: _showCreateForm,
                      onTap: () =>
                          setState(() => _showCreateForm = !_showCreateForm),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.explore_rounded,
                      label: 'НАЙТИ КЛАН',
                      description: 'Просмотрите публичные кланы и вступите',
                      color: _kNeonCyan,
                      isActive: !_showCreateForm,
                      onTap: _loadPublicClans,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Create Form (toggle) ─────────────────────────────────────
              if (_showCreateForm) ...[
                _buildCreateForm(),
                const SizedBox(height: 24),
              ],

              // ── Section Divider ──────────────────────────────────────────
              _SectionDivider(title: 'ПУБЛИЧНЫЕ КЛАНЫ', icon: Icons.public_rounded),
              const SizedBox(height: 16),

              // ── Public Clan Table ─────────────────────────────────────────
              _isLoadingClans
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: _kNeonPrimary,
                        ),
                      ),
                    )
                  : _errorMessage != null
                      ? _buildErrorWidget(_errorMessage!, _loadPublicClans)
                      : _publicClans.isEmpty
                          ? _buildEmptyState()
                          : _buildPublicClanTable(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoClanBanner() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [
            _kNeonPrimary.withValues(alpha: 0.06),
            _kNeonCyan.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: _kNeonPrimary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _kNeonPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kNeonPrimary.withValues(alpha: 0.3)),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.groups_rounded, color: _kNeonPrimary, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'НЕТ КЛАНА',
                  style: TextStyle(
                    color: _kTextPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Вступите в существующий клан или создайте свой собственный, '
                  'чтобы играть вместе с другими хакерами.',
                  style: TextStyle(color: _kTextSecondary, fontSize: 13, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Create Form ─────────────────────────────────────────────────────────

  Widget _buildCreateForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kNeonPrimary.withValues(alpha: 0.25)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.edit_note_rounded, color: _kNeonPrimary, size: 18),
                SizedBox(width: 8),
                Text(
                  'СОЗДАТЬ НОВЫЙ КЛАН',
                  style: TextStyle(
                    color: _kNeonPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const Divider(color: _kBorder, height: 24),

            // Two-column form fields
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: name
                Expanded(
                  child: _CyberTextField(
                    controller: _clanNameController,
                    label: 'Название клана',
                    hint: 'Введите название...',
                    prefixIcon: Icons.label_rounded,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Введите название';
                      if (value.trim().length < 3) return 'Мин. 3 символа';
                      if (value.trim().length > 24) return 'Макс. 24 символа';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                // Right: tag
                SizedBox(
                  width: 180,
                  child: _CyberTextField(
                    controller: _clanTagController,
                    label: 'Тег',
                    hint: 'ABC',
                    prefixText: '[ ',
                    suffixText: ' ]',
                    maxLength: 5,
                    textCapitalization: TextCapitalization.characters,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Введите тег';
                      if (value.trim().length < 3) return 'Мин. 3';
                      if (value.trim().length > 5) return 'Макс. 5';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Description
            _CyberTextField(
              controller: _clanDescController,
              label: 'Описание (необязательно)',
              hint: 'О чём ваш клан...',
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            // Submit button
            SizedBox(
              width: double.infinity,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: ElevatedButton.icon(
                  onPressed: _isCreating ? null : _createClan,
                  icon: _isCreating
                      ? const SizedBox(
                          width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.group_add_rounded),
                  label: Text(_isCreating ? 'СОЗДАНИЕ...' : 'СОЗДАТЬ КЛАН'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kNeonPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Public Clan Table ───────────────────────────────────────────────────

  Widget _buildPublicClanTable() {
    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _kBorder.withValues(alpha: 0.3),
              border: Border(bottom: BorderSide(color: _kBorder)),
            ),
            child: const Row(
              children: [
                SizedBox(width: 52), // tag badge space
                Expanded(flex: 3, child: _TableHeaderCell(label: 'КЛАН', flex: 3)),
                SizedBox(width: 12),
                Expanded(flex: 2, child: _TableHeaderCell(label: 'ОПИСАНИЕ', flex: 2)),
                SizedBox(width: 12),
                Expanded(flex: 1, child: _TableHeaderCell(label: 'УЧАСТНИКИ', flex: 1)),
                SizedBox(width: 12),
                SizedBox(width: 100, child: _TableHeaderCell(label: 'ДЕЙСТВИЕ')),
              ],
            ),
          ),
          // Clan rows
          ..._publicClans.map((clan) {
            final membersAgg = (clan['clan_members'] as List?)?.firstOrNull;
            final memberCount =
                (membersAgg is Map ? (membersAgg['count'] as num?)?.toInt() : 0) ?? 0;
            return _PublicClanRow(
              clan: clan,
              memberCount: memberCount,
              onJoin: () => _joinClan(clan['id'] as String),
            );
          }),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SHARED HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.groups_outlined, size: 48, color: _kTextMuted),
            SizedBox(height: 12),
            Text('Публичных кланов не найдено', style: TextStyle(color: _kTextSecondary, fontSize: 15)),
            SizedBox(height: 6),
            Text('Станьте первым — создайте свой клан!', style: TextStyle(color: _kTextMuted, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget(String message, VoidCallback onRetry) {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kNeonRed.withValues(alpha: 0.3)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: _kNeonRed),
            const SizedBox(height: 12),
            Text(message, style: const TextStyle(color: _kTextSecondary, fontSize: 14)),
            const SizedBox(height: 16),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('ПОВТОРИТЬ'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kNeonRed.withValues(alpha: 0.15),
                  foregroundColor: _kNeonRed,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _rolePriority(String? role) {
    return switch (role) {
      'leader' => 0,
      'officer' => 1,
      _ => 2,
    };
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    } catch (_) {
      return '—';
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SUB-WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

// ── Header Action Button ───────────────────────────────────────────────────

class _HeaderActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _HeaderActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  State<_HeaderActionButton> createState() => _HeaderActionButtonState();
}

class _HeaderActionButtonState extends State<_HeaderActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _hovered ? widget.color.withValues(alpha: 0.15) : widget.color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: widget.color.withValues(alpha: _hovered ? 0.5 : 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, size: 16, color: widget.color),
            const SizedBox(width: 6),
            Text(
              widget.label,
              style: TextStyle(
                color: widget.color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Info Row (clan detail) ─────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF3a4555), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Color(0xFFe0e6ed), fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

// ── Table Header Cell ──────────────────────────────────────────────────────

class _TableHeaderCell extends StatelessWidget {
  final String label;

  const _TableHeaderCell({required this.label, int flex = 1});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF3a4555),
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    );
  }
}

// ── Member Table Row ───────────────────────────────────────────────────────

class _MemberTableRow extends StatefulWidget {
  final String username;
  final String role;
  final int level;
  final bool isOnline;
  final bool isMe;

  const _MemberTableRow({
    required this.username,
    required this.role,
    required this.level,
    required this.isOnline,
    required this.isMe,
  });

  @override
  State<_MemberTableRow> createState() => _MemberTableRowState();
}

class _MemberTableRowState extends State<_MemberTableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final roleColor = switch (widget.role) {
      'leader' => _kNeonAmber,
      'officer' => _kNeonCyan,
      _ => _kTextSecondary,
    };

    final roleIcon = switch (widget.role) {
      'leader' => Icons.star_rounded,
      'officer' => Icons.shield_rounded,
      _ => Icons.person_rounded,
    };

    final roleLabel = switch (widget.role) {
      'leader' => 'ЛИДЕР',
      'officer' => 'ОФИЦЕР',
      _ => 'УЧАСТНИК',
    };

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: widget.isMe
              ? _kNeonPrimary.withValues(alpha: 0.06)
              : _hovered
                  ? _kBorder.withValues(alpha: 0.3)
                  : Colors.transparent,
          border: Border(
            bottom: BorderSide(color: _kBorder.withValues(alpha: 0.5)),
            left: widget.isMe
                ? BorderSide(color: _kNeonPrimary.withValues(alpha: 0.4), width: 2)
                : BorderSide.none,
          ),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: roleColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: roleColor.withValues(alpha: 0.3)),
              ),
              alignment: Alignment.center,
              child: Icon(roleIcon, color: roleColor, size: 16),
            ),
            // Name
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  widget.username + (widget.isMe ? ' (ВЫ)' : ''),
                  style: TextStyle(
                    color: widget.isMe ? _kNeonPrimary : _kTextPrimary,
                    fontSize: 13,
                    fontWeight: widget.isMe ? FontWeight.bold : FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            // Role badge
            Expanded(
              flex: 2,
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: roleColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: roleColor.withValues(alpha: 0.25)),
                ),
                child: Text(
                  roleLabel,
                  style: TextStyle(
                    color: roleColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            // Level
            Expanded(
              flex: 1,
              child: Text(
                'Ур. ${widget.level}',
                style: const TextStyle(color: _kTextSecondary, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            // Status
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: widget.isOnline ? _kNeonGreen : _kTextMuted,
                      shape: BoxShape.circle,
                      boxShadow: widget.isOnline
                          ? [BoxShadow(color: _kNeonGreen.withValues(alpha: 0.5), blurRadius: 6)]
                          : [],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.isOnline ? 'В сети' : 'Не в сети',
                    style: TextStyle(
                      color: widget.isOnline ? _kNeonGreen : _kTextMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }
}

// ── Public Clan Row ────────────────────────────────────────────────────────

class _PublicClanRow extends StatefulWidget {
  final Map<String, dynamic> clan;
  final int memberCount;
  final VoidCallback onJoin;

  const _PublicClanRow({
    required this.clan,
    required this.memberCount,
    required this.onJoin,
  });

  @override
  State<_PublicClanRow> createState() => _PublicClanRowState();
}

class _PublicClanRowState extends State<_PublicClanRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final name = widget.clan['name'] as String? ?? 'Неизвестный';
    final tag = widget.clan['tag'] as String? ?? '???';
    final description = widget.clan['description'] as String? ?? '';

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _hovered ? _kBorder.withValues(alpha: 0.3) : Colors.transparent,
          border: Border(bottom: BorderSide(color: _kBorder.withValues(alpha: 0.5))),
        ),
        child: Row(
          children: [
            // Tag badge
            SizedBox(
              width: 52,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _kNeonPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _kNeonPrimary.withValues(alpha: 0.3)),
                ),
                alignment: Alignment.center,
                child: Text(
                  '[$tag]',
                  style: const TextStyle(
                    color: _kNeonPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
            // Name
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  name,
                  style: const TextStyle(
                    color: _kTextPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            // Description
            Expanded(
              flex: 2,
              child: Text(
                description.isNotEmpty ? description : '—',
                style: TextStyle(
                  color: description.isNotEmpty ? _kTextSecondary : _kTextMuted,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Member count
            Expanded(
              flex: 1,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.people_rounded, size: 13, color: _kTextSecondary),
                  const SizedBox(width: 4),
                  Text(
                    '${widget.memberCount}',
                    style: const TextStyle(color: _kTextSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Join button
            SizedBox(
              width: 100,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: _JoinButton(onTap: widget.onJoin),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Join Button ───────────────────────────────────────────────────────────

class _JoinButton extends StatefulWidget {
  final VoidCallback onTap;

  const _JoinButton({required this.onTap});

  @override
  State<_JoinButton> createState() => _JoinButtonState();
}

class _JoinButtonState extends State<_JoinButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: _hovered
                ? const Color(0xFFa855f7).withValues(alpha: 0.2)
                : const Color(0xFFa855f7).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: const Color(0xFFa855f7).withValues(alpha: _hovered ? 0.6 : 0.35),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            'ВСТУПИТЬ',
            style: TextStyle(
              color: const Color(0xFFa855f7),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Action Card (no-clan view) ─────────────────────────────────────────────

class _ActionCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final bool isActive;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _hovered ? widget.color.withValues(alpha: 0.06) : const Color(0xFF0d1220),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isActive
                  ? widget.color.withValues(alpha: 0.5)
                  : _hovered
                      ? widget.color.withValues(alpha: 0.3)
                      : const Color(0xFF1e2a3a),
            ),
            boxShadow: widget.isActive
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.1),
                      blurRadius: 16,
                      spreadRadius: -2,
                    ),
                  ]
                : [],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: widget.color.withValues(alpha: 0.25)),
                ),
                alignment: Alignment.center,
                child: Icon(widget.icon, color: widget.color, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: TextStyle(
                        color: widget.isActive ? widget.color : const Color(0xFFe0e6ed),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.description,
                      style: const TextStyle(color: Color(0xFF6a7080), fontSize: 11),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: widget.isActive ? widget.color : const Color(0xFF3a4555),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Cyber Text Field ──────────────────────────────────────────────────────

class _CyberTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final String? prefixText;
  final String? suffixText;
  final int? maxLength;
  final int maxLines;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;

  const _CyberTextField({
    required this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.prefixText,
    this.suffixText,
    this.maxLength,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(
        color: Color(0xFFe0e6ed),
        fontFamily: 'monospace',
        fontSize: 13,
      ),
      maxLines: maxLines,
      maxLength: maxLength,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Color(0xFF6a7080), fontSize: 12),
        hintStyle: const TextStyle(color: Color(0xFF3a4555)),
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: const Color(0xFFa855f7), size: 18) : null,
        prefixText: prefixText,
        suffixText: suffixText,
        prefixStyle: const TextStyle(
          color: Color(0xFFa855f7),
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
        suffixStyle: const TextStyle(
          color: Color(0xFFa855f7),
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
        counterStyle: const TextStyle(color: Color(0xFF3a4555)),
        filled: true,
        fillColor: const Color(0xFF0a0e17),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF1e2a3a)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF1e2a3a)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFa855f7), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFFF0040)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      validator: validator,
    );
  }
}

// ── Section Divider ─────────────────────────────────────────────────────────

class _SectionDivider extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionDivider({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFa855f7), size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFFa855f7),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Divider(color: const Color(0xFFa855f7).withValues(alpha: 0.2), height: 1),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
