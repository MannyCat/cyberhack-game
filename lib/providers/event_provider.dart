import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─── Data Models ──────────────────────────────────────────────────────────────

class WeeklyEvent {
  final String id;
  final String name;
  final String description;
  final String eventType;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final int rewardCredits;
  final int rewardXp;
  final Map<String, dynamic> bonusModifier;

  const WeeklyEvent({
    required this.id,
    required this.name,
    required this.description,
    required this.eventType,
    required this.startDate,
    required this.endDate,
    required this.isActive,
    this.rewardCredits = 0,
    this.rewardXp = 0,
    this.bonusModifier = const {},
  });

  factory WeeklyEvent.fromJson(Map<String, dynamic> json) {
    return WeeklyEvent(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      eventType: json['event_type'] as String? ?? '',
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      isActive: (json['is_active'] as bool?) ?? false,
      rewardCredits: (json['reward_credits'] as num?)?.toInt() ?? 0,
      rewardXp: (json['reward_xp'] as num?)?.toInt() ?? 0,
      bonusModifier: (json['bonus_modifier'] as Map<String, dynamic>?) ?? {},
    );
  }

  String get typeLabel => switch (eventType) {
    'pvp_tournament' => 'Турнир хакеров',
    'black_friday' => 'Чёрная пятница',
    'clan_raid' => 'Клановый рейд',
    'bug_hunt' => 'Охота на баги',
    _ => eventType,
  };

  String get typeIcon => switch (eventType) {
    'pvp_tournament' => 'military_tech',
    'black_friday' => 'local_offer',
    'clan_raid' => 'groups',
    'bug_hunt' => 'bug_report',
    _ => 'event',
  };

  double get progressPercent {
    final now = DateTime.now();
    final total = endDate.difference(startDate).inSeconds;
    final elapsed = now.difference(startDate).inSeconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  String get timeRemaining {
    final now = DateTime.now();
    final remaining = endDate.difference(now);
    if (remaining.isNegative) return 'Завершён';
    final days = remaining.inDays;
    final hours = remaining.inHours % 24;
    if (days > 0) return '${days}д ${hours}ч';
    final minutes = remaining.inMinutes % 60;
    return '${hours}ч ${minutes}м';
  }

  bool get isMarketDiscount => eventType == 'black_friday';
}

class EventParticipation {
  final String id;
  final String playerId;
  final String eventId;
  final int score;
  final int attempts;
  final int bestScore;
  final bool hasClaimedReward;
  final int rankPosition;

  const EventParticipation({
    required this.id,
    required this.playerId,
    required this.eventId,
    this.score = 0,
    this.attempts = 0,
    this.bestScore = 0,
    this.hasClaimedReward = false,
    this.rankPosition = 0,
  });

  factory EventParticipation.fromJson(Map<String, dynamic> json) {
    return EventParticipation(
      id: json['id'] as String,
      playerId: json['player_id'] as String,
      eventId: json['event_id'] as String,
      score: (json['score'] as num?)?.toInt() ?? 0,
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      bestScore: (json['best_score'] as num?)?.toInt() ?? 0,
      hasClaimedReward: (json['has_claimed_reward'] as bool?) ?? false,
      rankPosition: (json['rank_position'] as num?)?.toInt() ?? 0,
    );
  }
}

class DailyRewardState {
  final int streakDay;
  final DateTime? lastClaimDate;
  final int currentStreak;
  final int bestStreak;
  final int totalClaimed;

  const DailyRewardState({
    this.streakDay = 1,
    this.lastClaimDate,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.totalClaimed = 0,
  });

  factory DailyRewardState.fromJson(Map<String, dynamic> json) {
    return DailyRewardState(
      streakDay: (json['streak_day'] as num?)?.toInt() ?? 1,
      lastClaimDate: json['last_claim_date'] != null
          ? DateTime.parse(json['last_claim_date'] as String)
          : null,
      currentStreak: (json['current_streak'] as num?)?.toInt() ?? 0,
      bestStreak: (json['best_streak'] as num?)?.toInt() ?? 0,
      totalClaimed: (json['total_claimed'] as num?)?.toInt() ?? 0,
    );
  }

  bool get canClaimToday {
    if (lastClaimDate == null) return true;
    final today = DateTime.now();
    final last = lastClaimDate!;
    return today.year != last.year ||
        today.month != last.month ||
        today.day != last.day;
  }

  bool get isStreakBroken {
    if (lastClaimDate == null) return false;
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final last = lastClaimDate!;
    return last.year != yesterday.year ||
        last.month != yesterday.month ||
        last.day != yesterday.day;
  }
}

class Achievement {
  final String id;
  final String key;
  final String name;
  final String description;
  final String icon;
  final String category;
  final int rewardCredits;
  final int rewardXp;
  final bool isCompleted;
  final bool isClaimed;
  final Map<String, dynamic> progress;

  const Achievement({
    required this.id,
    required this.key,
    required this.name,
    required this.description,
    required this.icon,
    required this.category,
    this.rewardCredits = 0,
    this.rewardXp = 0,
    this.isCompleted = false,
    this.isClaimed = false,
    this.progress = const {},
  });

  factory Achievement.fromJson(Map<String, dynamic> json, {Map<String, dynamic>? playerData}) {
    final p = playerData ?? {};
    return Achievement(
      id: json['id'] as String,
      key: json['key'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      icon: json['icon'] as String? ?? 'star',
      category: json['category'] as String? ?? 'general',
      rewardCredits: (json['reward_credits'] as num?)?.toInt() ?? 0,
      rewardXp: (json['reward_xp'] as num?)?.toInt() ?? 0,
      isCompleted: (p['is_completed'] as bool?) ?? false,
      isClaimed: (p['is_claimed'] as bool?) ?? false,
      progress: (p['progress'] as Map<String, dynamic>?) ?? {},
    );
  }

  String get categoryLabel => switch (category) {
    'network' => 'Сеть',
    'combat' => 'Боевые',
    'economy' => 'Экономика',
    'social' => 'Социальные',
    'special' => 'Особые',
    _ => category,
  };
}

// ─── Daily Reward Tiers ──────────────────────────────────────────────────────

class DailyRewardTier {
  final int day;
  final int credits;
  final int xp;

  const DailyRewardTier({
    required this.day,
    required this.credits,
    required this.xp,
  });

  static const tiers = [
    DailyRewardTier(day: 1, credits: 100, xp: 10),
    DailyRewardTier(day: 2, credits: 200, xp: 20),
    DailyRewardTier(day: 3, credits: 300, xp: 30),
    DailyRewardTier(day: 4, credits: 500, xp: 50),
    DailyRewardTier(day: 5, credits: 800, xp: 80),
    DailyRewardTier(day: 6, credits: 1200, xp: 120),
    DailyRewardTier(day: 7, credits: 2000, xp: 250),
  ];

  static DailyRewardTier get forDay {
    final day = DateTime.now().weekday; // 1=Monday, 7=Sunday
    return tiers[(day - 1) % 7];
  }
}

// ─── Event Provider ───────────────────────────────────────────────────────────

class EventProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  // State
  List<WeeklyEvent> _activeEvents = [];
  Map<String, EventParticipation> _myParticipations = {};
  DailyRewardState _dailyRewardState = const DailyRewardState();
  List<Achievement> _achievements = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _dailyRewardClaiming = false;

  // Getters
  List<WeeklyEvent> get activeEvents => List.unmodifiable(_activeEvents);
  DailyRewardState get dailyRewardState => _dailyRewardState;
  List<Achievement> get achievements => List.unmodifiable(_achievements);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasActiveEvents => _activeEvents.isNotEmpty;
  bool get canClaimDaily => _dailyRewardState.canClaimToday;
  int get completedAchievements => _achievements.where((a) => a.isCompleted).length;

  // ─── Initialization ───────────────────────────────────────────────────────

  Future<void> init(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      await Future.wait([
        _loadActiveEvents(),
        _loadMyParticipations(userId),
        _loadDailyRewardState(userId),
        _loadAchievements(userId),
      ]);
    } catch (e) {
      debugPrint('EventProvider init error: $e');
      _errorMessage = 'Ошибка загрузки событий';
    }

    _isLoading = false;
    notifyListeners();
  }

  // ─── Weekly Events ────────────────────────────────────────────────────────

  Future<void> _loadActiveEvents() async {
    try {
      final response = await _supabase.rpc('get_active_events');
      _activeEvents = (response as List?)
          ?.map((e) => WeeklyEvent.fromJson(e as Map<String, dynamic>))
          .toList() ?? [];
    } catch (e) {
      debugPrint('Error loading events: $e');
    }
  }

  Future<void> _loadMyParticipations(String userId) async {
    try {
      final response = await _supabase
          .from('event_participation')
          .select()
          .eq('player_id', userId);

      _myParticipations = {};
      for (final row in (response as List)) {
        final p = EventParticipation.fromJson(row);
        _myParticipations[p.eventId] = p;
      }
    } catch (e) {
      debugPrint('Error loading participations: $e');
    }
  }

  Future<bool> joinEvent(String userId, String eventId) async {
    try {
      await _supabase.rpc('join_event', params: {
        'p_player_id': userId,
        'p_event_id': eventId,
      });
      await _loadMyParticipations(userId);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error joining event: $e');
      return false;
    }
  }

  EventParticipation? getParticipation(String eventId) {
    return _myParticipations[eventId];
  }

  // ─── Daily Rewards ─────────────────────────────────────────────────────────

  Future<void> _loadDailyRewardState(String userId) async {
    try {
      final response = await _supabase
          .from('daily_rewards')
          .select()
          .eq('player_id', userId)
          .maybeSingle();

      _dailyRewardState = response != null
          ? DailyRewardState.fromJson(response)
          : const DailyRewardState();
    } catch (e) {
      debugPrint('Error loading daily reward: $e');
    }
  }

  Future<Map<String, dynamic>?> claimDailyReward(String userId) async {
    if (_dailyRewardClaiming) return null;
    _dailyRewardClaiming = true;

    try {
      final result = await _supabase.rpc('claim_daily_reward', params: {
        'p_player_id': userId,
      });

      final resultMap = result as Map<String, dynamic>?;

      if (resultMap != null && resultMap['success'] == true) {
        await _loadDailyRewardState(userId);
        notifyListeners();
        return resultMap;
      } else {
        return resultMap; // contains error message
      }
    } catch (e) {
      debugPrint('Error claiming daily reward: $e');
      return {'success': false, 'message': 'Ошибка получения награды'};
    } finally {
      _dailyRewardClaiming = false;
    }
  }

  // ─── Achievements ─────────────────────────────────────────────────────────

  Future<void> _loadAchievements(String userId) async {
    try {
      final response = await _supabase
          .from('achievements')
          .select('*, player_achievements!inner(progress, is_completed, is_claimed)')
          .eq('player_achievements.player_id', userId)
          .order('sort_order');

      _achievements = (response as List).map((row) {
        final achJson = Map<String, dynamic>.from(row as Map);
        final playerData = achJson['player_achievements'] as List?;
        final pData = playerData?.isNotEmpty == true
            ? Map<String, dynamic>.from(playerData!.first as Map)
            : null;
        return Achievement.fromJson(achJson, playerData: pData);
      }).toList();

      // Also load achievements not yet unlocked
      final unlockedIds = _achievements.map((a) => a.id).toSet();
      final allResponse = await _supabase
          .from('achievements')
          .select()
          .order('sort_order');

      final allAchievements = (allResponse as List)
          .where((row) => !unlockedIds.contains((row as Map)['id']))
          .map((row) => Achievement.fromJson(row as Map<String, dynamic>));

      _achievements = [..._achievements, ...allAchievements];
    } catch (e) {
      debugPrint('Error loading achievements: $e');
    }
  }

  Future<bool> claimAchievement(String userId, String achievementId) async {
    try {
      await _supabase.from('player_achievements').update({
        'is_claimed': true,
        'claimed_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('player_id', userId).eq('achievement_id', achievementId);

      await _loadAchievements(userId);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error claiming achievement: $e');
      return false;
    }
  }

  Future<void> refresh(String userId) async {
    await Future.wait([
      _loadActiveEvents(),
      _loadDailyRewardState(userId),
    ]);
    notifyListeners();
  }

  @override
  void dispose() {
    super.dispose();
  }
}
