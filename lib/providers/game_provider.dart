import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_provider.dart';

// --- Data Models ---

class NetworkNode {
  final String id;
  final String playerId;
  final String nodeType;
  final int nodeLevel;
  final int health;
  final int maxHealth;
  final bool isOnline;
  final DateTime createdAt;

  const NetworkNode({
    required this.id,
    required this.playerId,
    required this.nodeType,
    required this.nodeLevel,
    required this.health,
    required this.maxHealth,
    required this.isOnline,
    required this.createdAt,
  });

  factory NetworkNode.fromJson(Map<String, dynamic> json) {
    return NetworkNode(
      id: json['id'] as String,
      playerId: json['player_id'] as String,
      nodeType: json['node_type'] as String,
      nodeLevel: (json['node_level'] as num?)?.toInt() ?? 1,
      health: (json['health'] as num?)?.toInt() ?? 0,
      maxHealth: (json['max_health'] as num?)?.toInt() ?? 100,
      isOnline: (json['is_online'] as bool?) ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  NetworkNode copyWith({
    String? id,
    String? playerId,
    String? nodeType,
    int? nodeLevel,
    int? health,
    int? maxHealth,
    bool? isOnline,
    DateTime? createdAt,
  }) {
    return NetworkNode(
      id: id ?? this.id,
      playerId: playerId ?? this.playerId,
      nodeType: nodeType ?? this.nodeType,
      nodeLevel: nodeLevel ?? this.nodeLevel,
      health: health ?? this.health,
      maxHealth: maxHealth ?? this.maxHealth,
      isOnline: isOnline ?? this.isOnline,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class AttackTarget {
  final String id;
  final String username;
  final int level;
  final int networkStrength;
  final String clanTag;

  const AttackTarget({
    required this.id,
    required this.username,
    required this.level,
    required this.networkStrength,
    this.clanTag = '',
  });

  factory AttackTarget.fromJson(Map<String, dynamic> json) {
    return AttackTarget(
      id: json['id'] as String,
      username: json['username'] as String? ?? 'Неизвестный',
      level: (json['level'] as num?)?.toInt() ?? 1,
      networkStrength: (json['network_strength'] as num?)?.toInt() ?? 0,
      clanTag: json['clan_tag'] as String? ?? '',
    );
  }
}

class AttackRecord {
  final String id;
  final String attackerId;
  final String defenderId;
  final String? targetNodeId;
  final String attackType;
  final int damage;
  final String status;
  final int creditsStolen;
  final DateTime createdAt;
  final String? defenderName;

  const AttackRecord({
    required this.id,
    required this.attackerId,
    required this.defenderId,
    this.targetNodeId,
    required this.attackType,
    required this.damage,
    required this.status,
    required this.creditsStolen,
    required this.createdAt,
    this.defenderName,
  });

  factory AttackRecord.fromJson(Map<String, dynamic> json) {
    return AttackRecord(
      id: json['id'] as String,
      attackerId: json['attacker_id'] as String,
      defenderId: json['defender_id'] as String,
      targetNodeId: json['target_node_id'] as String?,
      attackType: json['attack_type'] as String,
      damage: (json['damage'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'pending',
      creditsStolen: (json['credits_stolen'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      defenderName: json['defender_name'] as String?,
    );
  }
}

class PlayerResources {
  final int credits;
  final int cpu;
  final int bandwidth;
  final int level;
  final int experience;

  const PlayerResources({
    required this.credits,
    required this.cpu,
    required this.bandwidth,
    required this.level,
    required this.experience,
  });

  factory PlayerResources.fromProfile(PlayerProfile profile) {
    return PlayerResources(
      credits: profile.credits,
      cpu: profile.cpu,
      bandwidth: profile.bandwidth,
      level: profile.level,
      experience: profile.experience,
    );
  }
}

// --- Game Provider ---

class GameProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  // State
  PlayerResources? _resources;
  List<NetworkNode> _networkNodes = [];
  NetworkNode? _selectedNode;
  List<AttackTarget> _availableTargets = [];
  List<AttackRecord> _attackHistory = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Realtime subscriptions
  RealtimeChannel? _profileChannel;
  RealtimeChannel? _attacksChannel;

  // --- Getters ---

  PlayerResources? get resources => _resources;
  List<NetworkNode> get networkNodes => List.unmodifiable(_networkNodes);
  NetworkNode? get selectedNode => _selectedNode;
  List<AttackTarget> get availableTargets => List.unmodifiable(_availableTargets);
  List<AttackRecord> get attackHistory => List.unmodifiable(_attackHistory);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get credits => _resources?.credits ?? 0;
  int get cpu => _resources?.cpu ?? 0;
  int get bandwidth => _resources?.bandwidth ?? 0;
  int get level => _resources?.level ?? 1;
  int get xp => _resources?.experience ?? 0;

  // --- Initialization ---

  bool _isInitialized = false;

  void init(String userId) {
    if (_isInitialized) return;
    _isInitialized = true;
    _loadAllData(userId);
    _subscribeToRealtimeUpdates(userId);
  }

  Future<void> _loadAllData(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await Future.wait([
        _loadResources(userId),
        _loadNetworkNodes(userId),
        _loadAttackHistory(userId),
      ]);
      await _loadAvailableTargets(userId);
    } catch (e) {
      debugPrint('Error loading game data: $e');
      _errorMessage = 'Не удалось загрузить игровые данные';
    }

    _isLoading = false;
    notifyListeners();
  }

  // --- Resource Methods ---

  Future<void> _loadResources(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      final profile = PlayerProfile.fromJson(response);
      _resources = PlayerResources.fromProfile(profile);
    } catch (e) {
      debugPrint('Error loading resources: $e');
    }
  }

  Future<void> refreshResources(String userId) async {
    await _loadResources(userId);
    notifyListeners();
  }

  // --- Network Node Methods ---

  Future<void> _loadNetworkNodes(String userId) async {
    try {
      final response = await _supabase
          .from('network_nodes')
          .select()
          .eq('player_id', userId)
          .order('created_at');

      _networkNodes = (response as List)
          .map((json) => NetworkNode.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error loading network nodes: $e');
    }
  }

  Future<void> refreshNetworkNodes(String userId) async {
    await _loadNetworkNodes(userId);
    notifyListeners();
  }

  Future<bool> deployNode({
    required String userId,
    required String nodeType,
    required int health,
    required int maxHealth,
  }) async {
    try {
      await _supabase.from('network_nodes').insert({
        'player_id': userId,
        'node_type': nodeType,
        'node_level': 1,
        'health': health,
        'max_health': maxHealth,
        'is_online': true,
      });

      await _loadNetworkNodes(userId);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deploying node: $e');
      _errorMessage = 'Не удалось развернуть узел';
      notifyListeners();
      return false;
    }
  }

  Future<bool> upgradeNode({
    required String nodeId,
    required String userId,
    required int cost,
  }) async {
    try {
      await _supabase.rpc('upgrade_network_node', params: {
        'p_node_id': nodeId,
        'p_cost': cost,
      });

      await _loadResources(userId);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error upgrading node: $e');
      _errorMessage = 'Не удалось улучшить узел';
      notifyListeners();
      return false;
    }
  }

  void selectNode(NetworkNode? node) {
    _selectedNode = node;
    notifyListeners();
  }

  // --- Attack Methods ---

  Future<void> _loadAvailableTargets(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('id, username, level, clan_id, clan:clans(tag), network_nodes(count)')
          .neq('id', userId)
          .order('level', ascending: false)
          .limit(20);

      _availableTargets = (response as List).map((row) {
        final clan = row['clan'] as Map?;
        final nodes = row['network_nodes'] as List?;
        final nodeCount = nodes?.length ?? 0;
        return AttackTarget(
          id: row['id'] as String,
          username: row['username'] as String? ?? 'Неизвестный',
          level: (row['level'] as num?)?.toInt() ?? 1,
          networkStrength: nodeCount * 50,
          clanTag: clan?['tag'] as String? ?? '',
        );
      }).toList();
    } catch (e) {
      debugPrint('Error loading targets: $e');
    }
  }

  Future<void> refreshTargets(String userId) async {
    await _loadAvailableTargets(userId);
    notifyListeners();
  }

  Future<bool> launchAttack({
    required String attackerId,
    required String defenderId,
    required String? targetNodeId,
    required String attackType,
    required int damage,
  }) async {
    try {
      final response = await _supabase.from('attacks').insert({
        'attacker_id': attackerId,
        'defender_id': defenderId,
        'target_node_id': targetNodeId,
        'attack_type': attackType,
        'damage': damage,
        'status': 'pending',
        'credits_stolen': 0,
      }).select();

      if (response.isNotEmpty) {
        _attackHistory.insert(0, AttackRecord.fromJson(response.first));
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('Error launching attack: $e');
      _errorMessage = 'Не удалось запустить атаку';
      notifyListeners();
      return false;
    }
  }

  Future<void> _loadAttackHistory(String userId) async {
    try {
      final response = await _supabase
          .from('attacks')
          .select('*, defender:profiles!defender_id(username)')
          .or('attacker_id.eq.$userId,defender_id.eq.$userId')
          .order('created_at', ascending: false)
          .limit(50);

      _attackHistory = (response as List)
          .map((json) => AttackRecord.fromJson({
            ...json,
            'defender_name': (json['defender'] as Map?)?['username'],
          }))
          .toList();
    } catch (e) {
      debugPrint('Error loading attack history: $e');
    }
  }

  Future<void> refreshAttackHistory(String userId) async {
    await _loadAttackHistory(userId);
    notifyListeners();
  }

  // --- Market Methods ---

  Future<List<Map<String, dynamic>>> getMarketItems({String? category}) async {
    try {
      var query = _supabase
          .from('market_items')
          .select()
          .gt('stock', 0);

      if (category != null) {
        query = query.eq('category', category);
      }

      final response = await query.order('price');
      return (response as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      debugPrint('Error loading market items: $e');
      return [];
    }
  }

  Future<bool> purchaseItem({
    required String playerId,
    required String itemId,
    required int price,
  }) async {
    try {
      final result = await _supabase.rpc('purchase_item', params: {
        'p_player_id': playerId,
        'p_item_id': itemId,
        'p_price': price,
      });

      if (result == true) {
        await _loadResources(playerId);
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Недостаточно кредитов';
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('Error purchasing item: $e');
      _errorMessage = 'Не удалось купить товар';
      notifyListeners();
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getPlayerInventory(String playerId) async {
    try {
      final response = await _supabase
          .from('player_inventory')
          .select('*, market_items(name, description, category, effect_json)')
          .eq('player_id', playerId);

      return (response as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      debugPrint('Error loading inventory: $e');
      return [];
    }
  }

  // --- Realtime Subscriptions ---

  void _subscribeToRealtimeUpdates(String userId) {
    // Listen for profile/resource updates
    _profileChannel = _supabase
        .channel('profile_updates_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: (payload) {
            final newProfile = PlayerProfile.fromJson(payload.newRecord as Map<String, dynamic>);
            _resources = PlayerResources.fromProfile(newProfile);
            notifyListeners();
          },
        )
        .subscribe();

    // Listen for new attacks involving this player
    _attacksChannel = _supabase
        .channel('attack_updates_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'attacks',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'attacker_id',
            value: userId,
          ),
          callback: (payload) {
            final record = AttackRecord.fromJson(payload.newRecord as Map<String, dynamic>);
            _attackHistory.insert(0, record);
            notifyListeners();
          },
        )
        .subscribe();

    // Also subscribe to incoming attacks
    _supabase
        .channel('incoming_attacks_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'attacks',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'defender_id',
            value: userId,
          ),
          callback: (payload) {
            final record = AttackRecord.fromJson(payload.newRecord as Map<String, dynamic>);
            _attackHistory.insert(0, record);
            notifyListeners();
          },
        )
        .subscribe();
  }

  // --- Clan Methods ---

  Future<List<Map<String, dynamic>>> getClanInfo(String clanId) async {
    try {
      final response = await _supabase
          .from('clans')
          .select('*, clan_members(player_id, role, profiles(username))')
          .eq('id', clanId)
          .single();

      return [response as Map<String, dynamic>];
    } catch (e) {
      debugPrint('Error loading clan info: $e');
      return [];
    }
  }

  Future<bool> joinClan({
    required String playerId,
    required String clanId,
  }) async {
    try {
      await _supabase.from('clan_members').insert({
        'clan_id': clanId,
        'player_id': playerId,
        'role': 'member',
      });

      await _supabase.from('profiles').update({
        'clan_id': clanId,
      }).eq('id', playerId);

      return true;
    } catch (e) {
      debugPrint('Error joining clan: $e');
      return false;
    }
  }

  Future<bool> leaveClan({required String playerId}) async {
    try {
      final profile = await _supabase
          .from('profiles')
          .select('clan_id')
          .eq('id', playerId)
          .single();

      final clanId = profile['clan_id'] as String?;
      if (clanId == null) return true;

      await _supabase
          .from('clan_members')
          .delete()
          .eq('player_id', playerId)
          .eq('clan_id', clanId);

      await _supabase.from('profiles').update({
        'clan_id': null,
      }).eq('id', playerId);

      return true;
    } catch (e) {
      debugPrint('Error leaving clan: $e');
      return false;
    }
  }

  // --- Leaderboard ---

  Future<List<Map<String, dynamic>>> getLeaderboard({
    int limit = 50,
    int offset = 0,
    String sortColumn = 'successful_attacks',
  }) async {
    try {
      final validColumns = ['successful_attacks', 'clan_score', 'credits_earned', 'total_damage'];
      final column = validColumns.contains(sortColumn) ? sortColumn : 'successful_attacks';

      final response = await _supabase
          .from('player_stats')
          .select('*, profiles(username, level, clan_id)')
          .order(column, ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      debugPrint('Error loading leaderboard: $e');
      return [];
    }
  }

  // --- Utility ---

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _profileChannel?.unsubscribe();
    _attacksChannel?.unsubscribe();
    super.dispose();
  }
}
