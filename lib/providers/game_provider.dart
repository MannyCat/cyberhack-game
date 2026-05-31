import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Provider ────────────────────────────────────────────────────────────

final gameProvider =
    StateNotifierProvider<GameNotifier, GameState>((ref) {
  return GameNotifier();
});

// ── State ───────────────────────────────────────────────────────────────

class GameState {
  final Map<String, dynamic>? profile;
  final List<Map<String, dynamic>> servers;
  final List<Map<String, dynamic>> operations;
  final List<Map<String, dynamic>> agents;
  final bool isLoading;

  const GameState({
    this.profile,
    this.servers = const [],
    this.operations = const [],
    this.agents = const [],
    this.isLoading = false,
  });

  GameState copyWith({
    Map<String, dynamic>? profile,
    List<Map<String, dynamic>>? servers,
    List<Map<String, dynamic>>? operations,
    List<Map<String, dynamic>>? agents,
    bool? isLoading,
  }) {
    return GameState(
      profile: profile ?? this.profile,
      servers: servers ?? this.servers,
      operations: operations ?? this.operations,
      agents: agents ?? this.agents,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// ── Notifier ───────────────────────────────────────────────────────────

class GameNotifier extends StateNotifier<GameState> {
  final _supabase = Supabase.instance.client;
  Timer? _opsTimer;
  Timer? _powerTimer;
  bool _disposed = false;

  GameNotifier() : super(const GameState(isLoading: true)) {
    loadAllData();
    _startTimers();
  }

  // ── Timers ──────────────────────────────────────────────────────────

  void _startTimers() {
    // Check active operations every 10 seconds
    _opsTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!_disposed) _checkOperations();
    });
    // Regenerate power and decay heat every 60 seconds
    _powerTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (!_disposed) _regenPowerAndDecayHeat();
    });
  }

  // ── Data loading ────────────────────────────────────────────────────

  Future<void> loadAllData() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      state = const GameState(isLoading: false);
      return;
    }

    await Future.wait([
      refreshProfile(),
      refreshServers(),
      refreshOperations(),
      refreshAgents(),
    ]);
    state = state.copyWith(isLoading: false);
  }

  Future<void> refreshProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();
      state = state.copyWith(profile: data);
    } catch (_) {
      // Silently fail – profile may not exist yet (first login)
    }
  }

  Future<void> refreshServers() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      final data = await _supabase
          .from('player_servers')
          .select('*, server_types(*)')
          .eq('player_id', user.id)
          .order('purchased_at', ascending: false);
      state = state.copyWith(servers: List<Map<String, dynamic>>.from(data));
    } catch (_) {}
  }

  Future<void> refreshOperations() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      final data = await _supabase
          .from('operations')
          .select('*, targets(*), player_servers(*)')
          .eq('player_id', user.id)
          .inFilter('status', ['active', 'planning', 'completed', 'failed'])
          .order('created_at', ascending: false);
      state =
          state.copyWith(operations: List<Map<String, dynamic>>.from(data));
    } catch (_) {}
  }

  Future<void> refreshAgents() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      final data = await _supabase
          .from('agents')
          .select()
          .eq('player_id', user.id)
          .order('hired_at', ascending: false);
      state = state.copyWith(agents: List<Map<String, dynamic>>.from(data));
    } catch (_) {}
  }

  // ── Operation completion check ──────────────────────────────────────

  Future<void> _checkOperations() async {
    final activeOps =
        state.operations.where((o) => o['status'] == 'active').toList();
    if (activeOps.isEmpty) return;

    for (final op in activeOps) {
      final completesAt = op['completes_at'] as String?;
      if (completesAt == null) continue;
      final endTime = DateTime.parse(completesAt);
      if (DateTime.now().isAfter(endTime)) {
        try {
          await _supabase
              .rpc('complete_operation', params: {'p_op_id': op['id']});
        } catch (_) {}
      }
    }
    // Refresh data after checking
    await Future.wait([refreshOperations(), refreshProfile()]);
  }

  // ── Power regen & heat decay (client-side visual, server is source) ─

  Future<void> _regenPowerAndDecayHeat() async {
    final p = state.profile;
    if (p == null) return;

    // First pull fresh data from server
    await refreshProfile();
    final fresh = state.profile;
    if (fresh == null) return;

    final currentPower = (fresh['power'] as num?)?.toInt() ?? 0;
    final maxPower = (fresh['max_power'] as num?)?.toInt() ?? 200;
    final heat = (fresh['heat'] as num?)?.toInt() ?? 0;

    bool changed = false;
    final updated = Map<String, dynamic>.from(fresh);

    if (currentPower < maxPower) {
      updated['power'] = (currentPower + 5).clamp(0, maxPower);
      changed = true;
    }
    if (heat > 0) {
      updated['heat'] = (heat - 1).clamp(0, 999);
      changed = true;
    }

    if (changed) {
      state = state.copyWith(profile: updated);
    }
  }

  // ── Convenience getters ─────────────────────────────────────────────

  int? get credits => (state.profile?['credits'] as num?)?.toInt();
  int? get power => (state.profile?['power'] as num?)?.toInt();
  int? get maxPower => (state.profile?['max_power'] as num?)?.toInt();
  int? get heat => (state.profile?['heat'] as num?)?.toInt();
  int? get level => (state.profile?['level'] as num?)?.toInt();
  int? get experience => (state.profile?['experience'] as num?)?.toInt();
  int? get reputation => (state.profile?['reputation'] as num?)?.toInt();
  int? get totalEarnings =>
      (state.profile?['total_earnings'] as num?)?.toInt();
  int? get cpu => (state.profile?['cpu'] as num?)?.toInt();
  int? get bandwidth => (state.profile?['bandwidth'] as num?)?.toInt();
  String? get username => state.profile?['username'] as String?;
  String? get clanId => state.profile?['clan_id'] as String?;

  // ── Dispose ─────────────────────────────────────────────────────────

  @override
  void dispose() {
    _disposed = true;
    _opsTimer?.cancel();
    _powerTimer?.cancel();
    super.dispose();
  }
}
