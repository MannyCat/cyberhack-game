/// Game balance constants for CyberHack – 2077.
///
/// All numeric tunables live here so designers can tweak values without
/// touching model or UI code. Pull requests that modify these values
/// should be reviewed with extreme prejudice.
library;

import 'dart:math' as math;

// ─── Resource identifiers ──────────────────────────────────────────────────
class Resources {
  Resources._();
  static const String credits = 'credits';
  static const String cpuPower = 'cpu_power';
  static const String bandwidth = 'bandwidth';
}

// ─── Building / Network‑node definitions ───────────────────────────────────
class BuildingConfig {
  BuildingConfig._();

  /// Per‑building stats keyed by type name.
  static const Map<String, BuildingStats> stats = {
    'server': BuildingStats(
      buildCostCredits: 500,
      buildCostCpu: 50,
      buildCostBandwidth: 30,
      hp: 200,
      defense: 10,
      passiveIncome: 15, // credits / min
      cpuYield: 5,
      bandwidthYield: 3,
      upgradeCostMultiplier: 1.8,
      buildTimeSeconds: 30,
    ),
    'firewall': BuildingStats(
      buildCostCredits: 800,
      buildCostCpu: 30,
      buildCostBandwidth: 50,
      hp: 500,
      defense: 60,
      passiveIncome: 0,
      cpuYield: 0,
      bandwidthYield: 0,
      upgradeCostMultiplier: 1.9,
      buildTimeSeconds: 45,
    ),
    'router': BuildingStats(
      buildCostCredits: 300,
      buildCostCpu: 20,
      buildCostBandwidth: 80,
      hp: 150,
      defense: 15,
      passiveIncome: 5,
      cpuYield: 2,
      bandwidthYield: 12,
      upgradeCostMultiplier: 1.6,
      buildTimeSeconds: 20,
    ),
    'database': BuildingStats(
      buildCostCredits: 1200,
      buildCostCpu: 100,
      buildCostBandwidth: 40,
      hp: 300,
      defense: 20,
      passiveIncome: 30, // credits / min
      cpuYield: 0,
      bandwidthYield: 0,
      upgradeCostMultiplier: 2.0,
      buildTimeSeconds: 60,
    ),
    'mining_rig': BuildingStats(
      buildCostCredits: 1500,
      buildCostCpu: 120,
      buildCostBandwidth: 60,
      hp: 100,
      defense: 5,
      passiveIncome: 50, // credits / min
      cpuYield: 0,
      bandwidthYield: -5, // consumes bandwidth
      upgradeCostMultiplier: 2.1,
      buildTimeSeconds: 50,
    ),
    'scanner': BuildingStats(
      buildCostCredits: 400,
      buildCostCpu: 25,
      buildCostBandwidth: 20,
      hp: 80,
      defense: 0,
      passiveIncome: 0,
      cpuYield: 3,
      bandwidthYield: 5,
      upgradeCostMultiplier: 1.5,
      buildTimeSeconds: 15,
      // Special: reveals enemy stats in PvP attacks
    ),
    'terminal': BuildingStats(
      buildCostCredits: 200,
      buildCostCpu: 15,
      buildCostBandwidth: 10,
      hp: 100,
      defense: 5,
      passiveIncome: 3,
      cpuYield: 2,
      bandwidthYield: 2,
      upgradeCostMultiplier: 1.4,
      buildTimeSeconds: 10,
      // Basic multi-purpose node for beginners
    ),
    'proxy_node': BuildingStats(
      buildCostCredits: 600,
      buildCostCpu: 40,
      buildCostBandwidth: 100,
      hp: 120,
      defense: 30,
      passiveIncome: 0,
      cpuYield: 0,
      bandwidthYield: 20,
      upgradeCostMultiplier: 1.7,
      buildTimeSeconds: 25,
      // Special: reduces incoming attack damage by 15 % per proxy
      specialFlatDefense: 15,
    ),
  };

  /// Maximum number of nodes a player may own (before clan bonuses).
  static const int maxNodesBase = 12;

  /// Additional nodes granted per clan level.
  static const int maxNodesPerClanLevel = 2;
}

class BuildingStats {
  final int buildCostCredits;
  final int buildCostCpu;
  final int buildCostBandwidth;
  final int hp;
  final int defense;
  final int passiveIncome; // credits per minute
  final int cpuYield;
  final int bandwidthYield;
  final double upgradeCostMultiplier;
  final int buildTimeSeconds;
  final int specialFlatDefense;

  const BuildingStats({
    required this.buildCostCredits,
    required this.buildCostCpu,
    required this.buildCostBandwidth,
    required this.hp,
    required this.defense,
    required this.passiveIncome,
    required this.cpuYield,
    required this.bandwidthYield,
    required this.upgradeCostMultiplier,
    required this.buildTimeSeconds,
    this.specialFlatDefense = 0,
  });
}

// ─── Attack definitions ────────────────────────────────────────────────────
class AttackConfig {
  AttackConfig._();

  static const Map<String, AttackStats> stats = {
    'ddos': AttackStats(
      baseDamage: 80,
      cpuCost: 40,
      bandwidthCost: 60,
      cooldownSeconds: 300,
      durationSeconds: 30,
      description: 'Overwhelms target bandwidth, slowing all nodes for a time.',
    ),
    'malware': AttackStats(
      baseDamage: 120,
      cpuCost: 60,
      bandwidthCost: 20,
      cooldownSeconds: 600,
      durationSeconds: 45,
      description: 'Infects a random node, draining its passive income.',
    ),
    'phishing': AttackStats(
      baseDamage: 50,
      cpuCost: 10,
      bandwidthCost: 10,
      cooldownSeconds: 120,
      durationSeconds: 0,
      creditStealPercent: 10,
      description: 'Siphons credits directly from the target.',
    ),
    'brute_force': AttackStats(
      baseDamage: 150,
      cpuCost: 80,
      bandwidthCost: 30,
      cooldownSeconds: 480,
      durationSeconds: 0,
      description: 'Brute‑force attack with massive upfront damage.',
    ),
    'sql_injection': AttackStats(
      baseDamage: 100,
      cpuCost: 50,
      bandwidthCost: 40,
      cooldownSeconds: 420,
      durationSeconds: 0,
      creditStealPercent: 15,
      description: 'Targets databases — high damage + credit theft.',
    ),
    'zero_day': AttackStats(
      baseDamage: 250,
      cpuCost: 150,
      bandwidthCost: 80,
      cooldownSeconds: 1800, // 30 min
      durationSeconds: 0,
      description:
          'An unknown exploit. Devastating but extremely costly to launch.',
    ),
  };
}

class AttackStats {
  final int baseDamage;
  final int cpuCost;
  final int bandwidthCost;
  final int cooldownSeconds;
  final int durationSeconds;
  final double creditStealPercent;
  final String description;

  const AttackStats({
    required this.baseDamage,
    required this.cpuCost,
    required this.bandwidthCost,
    required this.cooldownSeconds,
    required this.durationSeconds,
    this.creditStealPercent = 0.0,
    required this.description,
  });
}

// ─── Player progression ───────────────────────────────────────────────────
class ProgressionConfig {
  ProgressionConfig._();

  /// Base XP required to go from level 1 → 2.
  static const int baseXpToLevel = 200;

  /// Each level requires [multiplier] × previous XP.
  static const double xpMultiplier = 1.35;

  /// Starting resources for a brand‑new player.
  static const int startingCredits = 1000;
  static const int startingCpu = 200;
  static const int startingBandwidth = 200;

  /// Max player level.
  static const int maxLevel = 100;

  /// XP rewards.
  static const int xpPerAttack = 25;
  static const int xpPerNodeBuilt = 40;
  static const int xpPerNodeUpgraded = 60;
  static const int xpPerDefenseWin = 35;
  static const int xpPerClanCreated = 100;

  /// Daily login bonus.
  static const int dailyLoginCredits = 250;
  static const int dailyLoginCpu = 50;
  static const int dailyLoginBandwidth = 50;
  static const int dailyLoginXp = 30;

  /// Formula: XP needed for [level] = baseXp * multiplier^(level-1)
  static int xpRequiredForLevel(int level) {
    if (level <= 1) return baseXpToLevel;
    return (baseXpToLevel * math.pow(xpMultiplier, level - 1)).round();
  }
}

// ─── Clan configuration ────────────────────────────────────────────────────
class ClanConfig {
  ClanConfig._();

  static const int minMembersToCreate = 1;
  static const int maxMembers = 20;
  static const int createClanCostCredits = 5000;
  static const String defaultRole = 'member'; // member, officer, leader
  static const int maxClanLevel = 10;
}

// ─── Chat configuration ───────────────────────────────────────────────────
class ChatConfig {
  ChatConfig._();

  static const int maxMessageLength = 500;
  static const int globalChatRateLimitSeconds = 5;
  static const int maxHistoryFetchCount = 50;
  static const int maxClanChatRateLimitSeconds = 3;
}
