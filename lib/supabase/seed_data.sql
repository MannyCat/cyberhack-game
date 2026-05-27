-- =============================================================================
-- CyberHack — Seed Data
-- =============================================================================

-- ---------------------------------------------------------------------------
-- UTILITY: Level calculation from experience (1000 XP per level)
-- ---------------------------------------------------------------------------
-- This function is idempotent; the version in schema.sql is the canonical one.
create or replace function public.calculate_level(xp integer)
returns integer
language sql
immutable
as $$
  select (xp / 1000) + 1;
$$;


-- =============================================================================
-- MARKET ITEMS
-- =============================================================================

-- ---------------------------------------------------------------------------
-- HARDWARE
-- ---------------------------------------------------------------------------
insert into public.market_items (name, description, category, price, effect_json, stock) values
(
  'Basic Server',
  'A standard server node. Provides +50 CPU power to your network.',
  'hardware',
  500,
  '{"cpu_bonus": 50, "node_type": "server", "health": 100, "max_health": 100}',
  -1
),
(
  'Advanced Server',
  'A high-performance server. Provides +150 CPU and extra processing power.',
  'hardware',
  2000,
  '{"cpu_bonus": 150, "node_type": "server", "health": 250, "max_health": 250}',
  -1
),
(
  'Mining Rig',
  'Dedicated mining hardware. Generates +10 credits per hour passively.',
  'hardware',
  3000,
  '{"credits_per_hour": 10, "node_type": "mining_rig", "health": 80, "max_health": 80}',
  15
),
(
  'Proxy Server',
  'Routes your traffic through multiple proxies. +30% chance to evade detection during attacks.',
  'hardware',
  1500,
  '{"evasion_bonus": 0.30, "node_type": "proxy", "health": 120, "max_health": 120}',
  -1
),
(
  'Enterprise Firewall',
  'Military-grade firewall. Absorbs 200 damage before going offline.',
  'hardware',
  2500,
  '{"damage_absorption": 200, "node_type": "firewall", "health": 200, "max_health": 200}',
  -1
),
(
  'Network Router',
  'High-speed router. +100 bandwidth for faster attack execution.',
  'hardware',
  800,
  '{"bandwidth_bonus": 100, "node_type": "router", "health": 150, "max_health": 150}',
  -1
),
(
  'Encrypted Database',
  'Secure storage for stolen data. +20% credits from successful attacks.',
  'hardware',
  4000,
  '{"credit_bonus_percent": 0.20, "node_type": "database", "health": 180, "max_health": 180}',
  10
);

-- ---------------------------------------------------------------------------
-- SOFTWARE
-- ---------------------------------------------------------------------------
insert into public.market_items (name, description, category, price, effect_json, stock) values
(
  'Firewall v1',
  'Basic perimeter defense. Reduces incoming damage by 15%.',
  'software',
  300,
  '{"damage_reduction": 0.15, "duration": "permanent"}',
  -1
),
(
  'Firewall v2',
  'Improved perimeter defense. Reduces incoming damage by 30%.',
  'software',
  800,
  '{"damage_reduction": 0.30, "duration": "permanent"}',
  -1
),
(
  'Firewall v3',
  'Advanced perimeter defense. Reduces incoming damage by 50%.',
  'software',
  2000,
  '{"damage_reduction": 0.50, "duration": "permanent"}',
  -1
),
(
  'Antivirus Pro',
  'Detects and neutralizes malware. 25% chance to auto-block attacks.',
  'software',
  600,
  '{"block_chance": 0.25, "duration": "permanent"}',
  -1
),
(
  'Network Scanner',
  'Reveals enemy node types and health before attacking. Essential recon tool.',
  'software',
  200,
  '{"reveals": ["node_type", "health", "max_health", "is_online"], "duration": "permanent"}',
  -1
),
(
  'Intrusion Detection System',
  'Alerts you when under attack and identifies the attacker. 40% detection rate.',
  'software',
  1200,
  '{"detection_rate": 0.40, "duration": "permanent"}',
  -1
);

-- ---------------------------------------------------------------------------
-- EXPLOITS
-- ---------------------------------------------------------------------------
insert into public.market_items (name, description, category, price, effect_json, stock) values
(
  'DDoS Script',
  'Overwhelms target with traffic. Deals 30 damage to any node type.',
  'exploits',
  400,
  '{"damage": 30, "attack_type": "ddos", "target": "any"}',
  -1
),
(
  'Malware Kit',
  'Infects target systems. Deals 50 damage and steals 5% of defender credits.',
  'exploits',
  1200,
  '{"damage": 50, "credit_steal_percent": 0.05, "attack_type": "malware", "target": "server"}',
  -1
),
(
  'Phishing Template',
  'Social engineering attack. Low damage (20) but steals 10% of defender credits.',
  'exploits',
  800,
  '{"damage": 20, "credit_steal_percent": 0.10, "attack_type": "phishing", "target": "any"}',
  -1
),
(
  'Brute Forcer',
  'Brute-force password attack. 70 damage to servers and databases.',
  'exploits',
  1000,
  '{"damage": 70, "attack_type": "brute_force", "target": ["server", "database"]}',
  -1
),
(
  'SQL Injector',
  'Exploits database vulnerabilities. 100 damage to databases, steals 8% credits.',
  'exploits',
  1500,
  '{"damage": 100, "credit_steal_percent": 0.08, "attack_type": "sql_injection", "target": "database"}',
  -1
),
(
  'Zero Day Exploit',
  'Undetectable attack using unknown vulnerability. 150 damage to any target.',
  'exploits',
  5000,
  '{"damage": 150, "stealth": true, "attack_type": "zero_day", "target": "any"}',
  3
),
(
  'Ransomware',
  'Encrypts target data. Deals 40 damage and locks credits for 1 hour.',
  'exploits',
  2000,
  '{"damage": 40, "credit_lock_duration": 3600, "attack_type": "ransomware", "target": "server"}',
  8
),
(
  'Rootkit',
  'Gains persistent access. Deals 60 damage and gives 15% of future defender income.',
  'exploits',
  3500,
  '{"damage": 60, "passive_income_percent": 0.15, "attack_type": "rootkit", "target": "any"}',
  5
);

-- ---------------------------------------------------------------------------
-- TOOLS
-- ---------------------------------------------------------------------------
insert into public.market_items (name, description, category, price, effect_json, stock) values
(
  'Network Mapper',
  'Maps out entire enemy networks. Reveals all nodes and their connections.',
  'tools',
  500,
  '{"reveals": "full_network", "duration": "permanent"}',
  -1
),
(
  'Decryptor',
  'Breaks encrypted communications. Increases credit steal by 25%.',
  'tools',
  1800,
  '{"credit_steal_bonus": 0.25, "duration": "permanent"}',
  -1
),
(
  'Botnet',
  'Army of compromised machines. Doubles attack damage for one attack.',
  'tools',
  3000,
  '{"damage_multiplier": 2.0, "uses": 1, "attack_type": "botnet_boost"}',
  10
),
(
  'Credit Launderer',
  'Launder stolen credits to avoid tracking. +15% more credits from attacks.',
  'tools',
  2200,
  '{"credit_launder_bonus": 0.15, "duration": "permanent"}',
  -1
),
(
  'Exploit Builder',
  'Craft custom exploits. Unlocks ability to combine two exploits into one attack.',
  'tools',
  4000,
  '{"ability": "combine_exploits", "duration": "permanent"}',
  5
),
(
  'EMP Device',
  'Electronic pulse. Temporarily disables all enemy nodes for 5 minutes.',
  'tools',
  6000,
  '{"effect": "disable_all_nodes", "duration_seconds": 300, "uses": 1}',
  2
);


-- =============================================================================
-- REALTIME SUBSCRIPTIONS SETUP
-- =============================================================================

-- Enable realtime for specific tables
alter publication supabase_realtime add table public.profiles;
alter publication supabase_realtime add table public.attacks;
alter publication supabase_realtime add table public.chat_messages;
alter publication supabase_realtime add table public.network_nodes;
alter publication supabase_realtime add table public.clan_members;
