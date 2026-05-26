import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/game_provider.dart';
import '../../providers/auth_provider.dart';

class ClanScreen extends StatefulWidget {
  const ClanScreen({super.key});

  @override
  State<ClanScreen> createState() => _ClanScreenState();
}

class _ClanScreenState extends State<ClanScreen> {
  // ── Create Clan Form ──
  final _clanNameController = TextEditingController();
  final _clanTagController = TextEditingController();
  final _clanDescController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isCreating = false;

  // ── State ──
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
        _publicClans = (response as List).cast<Map<String, dynamic>>();
        _isLoadingClans = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load clans';
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

      // Add creator as leader member
      await supabase.from('clan_members').insert({
        'clan_id': clanId,
        'player_id': auth.userId,
        'role': 'leader',
      });

      // Update profile
      await supabase.from('profiles').update({
        'clan_id': clanId,
      }).eq('id', auth.userId!);

      // Refresh auth profile
      await auth.refreshProfile();

      if (!mounted) return;
      setState(() {
        _showCreateForm = false;
        _isCreating = false;
      });
      _loadMyClan(clanId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Clan created successfully!'),
          backgroundColor: Colors.greenAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCreating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create clan: $e'),
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
    final success = await game.joinClan(playerId: auth.userId!, clanId: clanId);

    if (!mounted) return;
    if (success) {
      await auth.refreshProfile();
      _loadMyClan(clanId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Joined clan!'),
          backgroundColor: Colors.greenAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to join clan'),
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
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
        ),
        title: Row(
          children: const [
            Icon(Icons.warning, color: Colors.redAccent),
            SizedBox(width: 10),
            Text('Leave Clan?'),
          ],
        ),
        content: const Text(
          'Are you sure you want to leave your clan? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('LEAVE'),
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
          content: Text('Left clan'),
          backgroundColor: Colors.orangeAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to leave clan'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    final profile = auth.profile;
    final isInClan = profile?.clanId != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('CLAN'),
        actions: [
          if (isInClan)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: () {
                if (profile?.clanId != null) _loadMyClan(profile!.clanId!);
              },
            ),
        ],
      ),
      body: isInClan
          ? _buildMyClanView(theme, profile!)
          : _buildNoClanView(theme),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // NO CLAN VIEW — Create form + public clan list
  // ═══════════════════════════════════════════════════════════

  Widget _buildNoClanView(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.groups_outlined, size: 32, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Text(
                      'NO CLAN',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Join a crew or forge your own syndicate.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Action Buttons ──
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => setState(() => _showCreateForm = !_showCreateForm),
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('CREATE CLAN'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loadPublicClans,
                  icon: const Icon(Icons.search),
                  label: const Text('BROWSE'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.5)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Create Clan Form ──
          if (_showCreateForm) _buildCreateForm(theme),
          if (_showCreateForm) const SizedBox(height: 20),

          // ── Section Title ──
          _buildSectionTitle('PUBLIC CREWS', Icons.explore, theme),
          const SizedBox(height: 10),

          // ── Clan List ──
          _isLoadingClans
              ? const Center(child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ))
              : _errorMessage != null
                  ? _buildErrorWidget(theme, _errorMessage!, _loadPublicClans)
                  : _publicClans.isEmpty
                      ? _buildEmptyState(theme, Icons.groups_outlined, 'No public clans found', 'Be the first to create one!')
                      : Column(
                          children: _publicClans.map((clan) {
                            final members = (clan['clan_members'] as List?)?.firstOrNull;
                            final memberCount = (members is Map ? (members['count'] as num?)?.toInt() : 0) ?? 0;
                            return _PublicClanCard(
                              clan: clan,
                              memberCount: memberCount,
                              onJoin: () => _joinClan(clan['id'] as String),
                            );
                          }).toList(),
                        ),
        ],
      ),
    );
  }

  Widget _buildCreateForm(ThemeData theme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CREATE NEW CLAN', style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            )),
            const SizedBox(height: 16),
            // Name
            TextFormField(
              controller: _clanNameController,
              style: const TextStyle(fontFamily: 'monospace'),
              decoration: InputDecoration(
                labelText: 'Clan Name',
                prefixIcon: const Icon(Icons.label),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return 'Name is required';
                if (value.trim().length < 3) return 'Min 3 characters';
                if (value.trim().length > 24) return 'Max 24 characters';
                return null;
              },
            ),
            const SizedBox(height: 12),
            // Tag
            TextFormField(
              controller: _clanTagController,
              style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold),
              maxLength: 5,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Tag (3-5 chars)',
                prefixText: '[ ',
                suffixText: ' ]',
                prefixStyle: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                suffixStyle: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                counterStyle: TextStyle(color: theme.colorScheme.outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return 'Tag is required';
                if (value.trim().length < 3) return 'Min 3 characters';
                if (value.trim().length > 5) return 'Max 5 characters';
                return null;
              },
            ),
            const SizedBox(height: 12),
            // Description
            TextFormField(
              controller: _clanDescController,
              style: const TextStyle(fontFamily: 'monospace'),
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description (optional)',
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Submit
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isCreating ? null : _createClan,
                icon: _isCreating
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.group_add),
                label: Text(_isCreating ? 'CREATING...' : 'CREATE CLAN'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // MY CLAN VIEW — Clan info + members
  // ═══════════════════════════════════════════════════════════

  Widget _buildMyClanView(ThemeData theme, PlayerProfile profile) {
    if (_isLoadingMyClan) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_myClanInfo.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Loading clan data...', style: theme.textTheme.bodyMedium),
          ],
        ),
      );
    }

    final clanData = _myClanInfo.first;
    final name = clanData['name'] as String? ?? 'Unknown Clan';
    final tag = clanData['tag'] as String? ?? '???';
    final description = clanData['description'] as String? ?? '';
    final members = clanData['clan_members'] as List? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Clan Header Card ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  theme.colorScheme.tertiaryContainer.withValues(alpha: 0.15),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: theme.colorScheme.primary),
                      ),
                      child: Text(
                        '[$tag]',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        name,
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(description, style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  )),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.people, size: 16, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      '${members.length} member${members.length != 1 ? 's' : ''}',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Members Section ──
          _buildSectionTitle('MEMBERS', Icons.person, theme),
          const SizedBox(height: 10),

          // Sort members: leader first, then officers, then members
          ...(() {
            final sorted = List<Map<String, dynamic>>.from(members)
              ..sort((a, b) {
                final roleA = _rolePriority(a['role'] as String?);
                final roleB = _rolePriority(b['role'] as String?);
                return roleA.compareTo(roleB);
              });
            return sorted.map((member) {
              final memberProfile = member['profiles'] as Map<String, dynamic>?;
              final username = memberProfile?['username'] as String? ?? 'Unknown';
              final role = member['role'] as String? ?? 'member';
              final playerId = member['player_id'] as String?;
              final isMe = playerId == context.read<AuthProvider>().userId;
              return _buildMemberTile(
                theme: theme,
                username: username,
                role: role,
                isMe: isMe,
              );
            }).toList();
          })(),
          const SizedBox(height: 24),

          // ── Leave Button ──
          Center(
            child: SizedBox(
              width: 200,
              child: OutlinedButton.icon(
                onPressed: _leaveClan,
                icon: const Icon(Icons.exit_to_app, color: Colors.redAccent),
                label: const Text('LEAVE CLAN', style: TextStyle(color: Colors.redAccent)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildMemberTile({
    required ThemeData theme,
    required String username,
    required String role,
    required bool isMe,
  }) {
    final roleColor = switch (role) {
      'leader' => Colors.amberAccent,
      'officer' => Colors.cyanAccent,
      _ => theme.colorScheme.onSurfaceVariant,
    };

    final roleIcon = switch (role) {
      'leader' => Icons.star,
      'officer' => Icons.shield,
      _ => Icons.person,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: isMe
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.2)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
        border: Border.all(
          color: isMe
              ? theme.colorScheme.primary.withValues(alpha: 0.4)
              : theme.colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: roleColor.withValues(alpha: 0.2),
            child: Icon(roleIcon, color: roleColor, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              username + (isMe ? ' (YOU)' : ''),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isMe ? FontWeight.bold : FontWeight.w600,
                color: isMe ? theme.colorScheme.primary : theme.colorScheme.onSurface,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: roleColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              role.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: roleColor,
                fontWeight: FontWeight.bold,
                fontSize: 10,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Shared helpers
  // ═══════════════════════════════════════════════════════════

  Widget _buildSectionTitle(String title, IconData icon, ThemeData theme) {
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 18),
        const SizedBox(width: 8),
        Text(title, style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        )),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: theme.colorScheme.primary.withValues(alpha: 0.3))),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme, IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.outline.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.outline)),
            const SizedBox(height: 6),
            Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline.withValues(alpha: 0.7))),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget(ThemeData theme, String message, VoidCallback onRetry) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(message, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text('RETRY')),
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
}

// ═══════════════════════════════════════════════════════════
// Public Clan Card Widget
// ═══════════════════════════════════════════════════════════

class _PublicClanCard extends StatelessWidget {
  final Map<String, dynamic> clan;
  final int memberCount;
  final VoidCallback onJoin;

  const _PublicClanCard({
    required this.clan,
    required this.memberCount,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = clan['name'] as String? ?? 'Unknown';
    final tag = clan['tag'] as String? ?? '???';
    final description = clan['description'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.12),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          // Clan icon with tag
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
            ),
            alignment: Alignment.center,
            child: Text(
              '[$tag]',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.people, size: 13, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      '$memberCount member${memberCount != 1 ? 's' : ''}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Join button
          ElevatedButton(
            onPressed: onJoin,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
              foregroundColor: theme.colorScheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.4)),
            ),
            child: const Text('JOIN'),
          ),
        ],
      ),
    );
  }
}
