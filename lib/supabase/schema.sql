-- =============================================================================
-- CyberHack — Supabase Database Schema (Idempotent)
-- =============================================================================
-- All statements use IF NOT EXISTS / CREATE OR REPLACE so this script
-- can be re-run safely against an existing database.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. ENABLE REQUIRED EXTENSIONS
-- ---------------------------------------------------------------------------
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------------
-- 2. PROFILES
-- ---------------------------------------------------------------------------
create table if not exists public.profiles (
  id            uuid        primary key references auth.users(id) on delete cascade,
  username      text        not null,
  credits       integer     not null default 1000 check (credits >= 0),
  cpu           integer     not null default 100  check (cpu >= 0),
  bandwidth     integer     not null default 100  check (bandwidth >= 0),
  level         integer     not null default 1    check (level >= 1),
  experience    integer     not null default 0    check (experience >= 0),
  clan_id       uuid,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),

  constraint profiles_username_unique unique (username)
);

-- ---------------------------------------------------------------------------
-- 3. CLANS
-- ---------------------------------------------------------------------------
create table if not exists public.clans (
  id             uuid        primary key default uuid_generate_v4(),
  name           text        not null,
  tag            text        not null,
  leader_id      uuid        not null,
  description    text,
  max_members    integer     not null default 20 check (max_members > 0),
  created_at     timestamptz not null default now(),

  constraint clans_name_unique unique (name),
  constraint clans_tag_unique unique (tag)
);

-- ---------------------------------------------------------------------------
-- Add FK constraints (avoid circular dependency)
-- ---------------------------------------------------------------------------
do $$ begin
  if not exists (
    select 1 from pg_constraint where conname = 'clans_leader_fkey'
  ) then
    alter table public.clans
      add constraint clans_leader_fkey foreign key (leader_id) references public.profiles(id) on delete cascade;
  end if;
end $$;

do $$ begin
  if not exists (
    select 1 from pg_constraint where conname = 'profiles_clan_fkey'
  ) then
    alter table public.profiles
      add constraint profiles_clan_fkey foreign key (clan_id) references public.clans(id) on delete set null;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 4. CLAN MEMBERS
-- ---------------------------------------------------------------------------
create table if not exists public.clan_members (
  id         uuid        primary key default uuid_generate_v4(),
  clan_id    uuid        not null references public.clans(id) on delete cascade,
  player_id  uuid        not null references public.profiles(id) on delete cascade,
  role       text        not null default 'member'
                          check (role in ('leader', 'officer', 'member')),
  joined_at  timestamptz not null default now(),

  constraint clan_members_unique unique (clan_id, player_id)
);

-- ---------------------------------------------------------------------------
-- 5. NETWORK NODES
-- ---------------------------------------------------------------------------
create table if not exists public.network_nodes (
  id            uuid        primary key default uuid_generate_v4(),
  player_id     uuid        not null references public.profiles(id) on delete cascade,
  node_type     text        not null
                            check (node_type in (
                              'server', 'firewall', 'router',
                              'database', 'mining_rig', 'proxy',
                              'scanner', 'terminal'
                            )),
  node_level    integer     not null default 1 check (node_level >= 1),
  health        integer     not null default 100 check (health >= 0),
  max_health    integer     not null default 100 check (max_health > 0),
  is_online     boolean     not null default true,
  created_at    timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 6. ATTACKS
-- ---------------------------------------------------------------------------
create table if not exists public.attacks (
  id              uuid        primary key default uuid_generate_v4(),
  attacker_id     uuid        not null references public.profiles(id) on delete cascade,
  defender_id     uuid        not null references public.profiles(id) on delete cascade,
  target_node_id  uuid        references public.network_nodes(id) on delete set null,
  attack_type     text        not null,
  damage          integer     not null default 0 check (damage >= 0),
  status          text        not null default 'pending'
                               check (status in ('pending', 'in_progress', 'success', 'failed')),
  credits_stolen  integer     not null default 0 check (credits_stolen >= 0),
  created_at      timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 7. CHAT MESSAGES
-- ---------------------------------------------------------------------------
create table if not exists public.chat_messages (
  id           uuid        primary key default uuid_generate_v4(),
  sender_id    uuid        not null references public.profiles(id) on delete cascade,
  sender_name  text        not null,
  content      text        not null check (char_length(content) <= 500),
  clan_id      uuid        references public.clans(id) on delete cascade,
  created_at   timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 8. MARKET ITEMS
-- ---------------------------------------------------------------------------
create table if not exists public.market_items (
  id           uuid        primary key default uuid_generate_v4(),
  name         text        not null,
  description  text,
  category     text        not null
                            check (category in ('hardware', 'software', 'exploits', 'tools')),
  price        integer     not null check (price > 0),
  effect_json  jsonb       not null default '{}'::jsonb,
  stock        integer     not null default -1,
  created_at   timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 9. PLAYER INVENTORY
-- ---------------------------------------------------------------------------
create table if not exists public.player_inventory (
  id           uuid        primary key default uuid_generate_v4(),
  player_id    uuid        not null references public.profiles(id) on delete cascade,
  item_id      uuid        not null references public.market_items(id) on delete cascade,
  quantity     integer     not null default 1 check (quantity > 0),
  purchased_at timestamptz not null default now(),

  constraint player_inventory_unique unique (player_id, item_id)
);

-- ---------------------------------------------------------------------------
-- 10. PLAYER STATS
-- ---------------------------------------------------------------------------
create table if not exists public.player_stats (
  id                  uuid        primary key default uuid_generate_v4(),
  player_id           uuid        not null references public.profiles(id) on delete cascade,
  total_attacks       integer     not null default 0 check (total_attacks >= 0),
  successful_attacks  integer     not null default 0 check (successful_attacks >= 0),
  credits_earned      integer     not null default 0 check (credits_earned >= 0),
  networks_destroyed  integer     not null default 0 check (networks_destroyed >= 0),
  total_damage         integer     not null default 0 check (total_damage >= 0),
  clan_score           integer     not null default 0 check (clan_score >= 0),
  highest_rank        integer     not null default 999 check (highest_rank > 0),

  constraint player_stats_unique unique (player_id)
);

-- ---------------------------------------------------------------------------
-- Ensure columns added in later migrations exist on older databases
-- ---------------------------------------------------------------------------
do $$ begin
  alter table public.player_stats add column if not exists total_damage  integer not null default 0 check (total_damage >= 0);
  alter table public.player_stats add column if not exists clan_score    integer not null default 0 check (clan_score >= 0);
exception when others then null;
end $$;


-- =============================================================================
-- INDEXES
-- =============================================================================

-- profiles
create index if not exists idx_profiles_username   on public.profiles (username);
create index if not exists idx_profiles_clan_id    on public.profiles (clan_id) where clan_id is not null;
create index if not exists idx_profiles_level      on public.profiles (level desc);

-- network_nodes
create index if not exists idx_nodes_player_id     on public.network_nodes (player_id);
create index if not exists idx_nodes_type          on public.network_nodes (node_type);
create index if not exists idx_nodes_online        on public.network_nodes (player_id, is_online);

-- attacks
create index if not exists idx_attacks_attacker    on public.attacks (attacker_id, created_at desc);
create index if not exists idx_attacks_defender    on public.attacks (defender_id, created_at desc);
create index if not exists idx_attacks_status      on public.attacks (status);
create index if not exists idx_attacks_created     on public.attacks (created_at desc);

-- clan_members
create index if not exists idx_clan_members_clan   on public.clan_members (clan_id);
create index if not exists idx_clan_members_player on public.clan_members (player_id);

-- chat_messages
create index if not exists idx_chat_clan_id        on public.chat_messages (clan_id) where clan_id is not null;
create index if not exists idx_chat_global         on public.chat_messages (created_at desc) where clan_id is null;
create index if not exists idx_chat_sender         on public.chat_messages (sender_id);

-- market_items
create index if not exists idx_market_category     on public.market_items (category);
create index if not exists idx_market_stock        on public.market_items (stock) where stock > 0;

-- player_inventory
create index if not exists idx_inventory_player    on public.player_inventory (player_id);
create index if not exists idx_inventory_item      on public.player_inventory (item_id);

-- player_stats
create index if not exists idx_stats_successful    on public.player_stats (successful_attacks desc);
create index if not exists idx_stats_credits       on public.player_stats (credits_earned desc);
create index if not exists idx_stats_clan_score    on public.player_stats (clan_score desc);
create index if not exists idx_stats_total_damage  on public.player_stats (total_damage desc);


-- =============================================================================
-- TRIGGERS
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Trigger 1: Auto-create profile on user signup
-- ---------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
  insert into public.profiles (id, username, credits, cpu, bandwidth, level, experience)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'username', split_part(new.email, '@', 1)),
    1000,
    100,
    100,
    1,
    0
  );

  insert into public.player_stats (player_id)
  values (new.id);

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row
  execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- Trigger 2: Auto-update profile level based on experience
-- ---------------------------------------------------------------------------
create or replace function public.update_profile_level()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
declare
  new_level integer;
begin
  new_level := (new.experience / 1000) + 1;

  if new_level != new.level then
    new.level := new_level;
  end if;

  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists on_profile_experience_change on public.profiles;
create trigger on_profile_experience_change
  before update of experience on public.profiles
  for each row
  execute function public.update_profile_level();

-- ---------------------------------------------------------------------------
-- Trigger 3: Auto-update player_stats on attack completion
-- ---------------------------------------------------------------------------
create or replace function public.update_attack_stats()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
  if new.status not in ('success', 'failed') then
    return new;
  end if;

  insert into public.player_stats (player_id, total_attacks, successful_attacks, credits_earned)
  values (new.attacker_id, 1, 1, new.credits_stolen)
  on conflict (player_id) do update set
    total_attacks      = player_stats.total_attacks + 1,
    successful_attacks = player_stats.successful_attacks + case when new.status = 'success' then 1 else 0 end,
    credits_earned     = player_stats.credits_earned + new.credits_stolen;

  if new.status = 'success' then
    declare
      remaining_nodes integer;
    begin
      select count(*) into remaining_nodes
      from public.network_nodes
      where player_id = new.defender_id and is_online = true;

      if remaining_nodes = 0 then
        insert into public.player_stats (player_id, networks_destroyed)
        values (new.attacker_id, 1)
        on conflict (player_id) do update set
          networks_destroyed = player_stats.networks_destroyed + 1;
      end if;
    end;
  end if;

  return new;
end;
$$;

drop trigger if exists on_attack_completed on public.attacks;
create trigger on_attack_completed
  after update of status on public.attacks
  for each row
  execute function public.update_attack_stats();

-- ---------------------------------------------------------------------------
-- Trigger 4: Set updated_at timestamp on profile changes
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists on_profile_update on public.profiles;
create trigger on_profile_update
  before update on public.profiles
  for each row
  execute function public.set_updated_at();


-- =============================================================================
-- ROW LEVEL SECURITY (RLS)
-- =============================================================================

-- Enable RLS on all tables (idempotent — safe to re-run)
do $$ begin
  alter table public.profiles        enable row level security;
  alter table public.clans           enable row level security;
  alter table public.clan_members    enable row level security;
  alter table public.network_nodes   enable row level security;
  alter table public.attacks         enable row level security;
  alter table public.chat_messages   enable row level security;
  alter table public.market_items    enable row level security;
  alter table public.player_inventory enable row level security;
  alter table public.player_stats    enable row level security;
exception when others then null;
end $$;

-- ---------------------------------------------------------------------------
-- profiles RLS  (DROP + CREATE — compatible with PostgreSQL 14+)
-- ---------------------------------------------------------------------------
drop policy if exists "Profiles are viewable by everyone" on public.profiles;
create policy "Profiles are viewable by everyone"
  on public.profiles for select
  using (true);

drop policy if exists "Users can update own profile" on public.profiles;
create policy "Users can update own profile"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

drop policy if exists "Service role can insert profiles" on public.profiles;
create policy "Service role can insert profiles"
  on public.profiles for insert
  with check (true);

drop policy if exists "Users can delete own profile" on public.profiles;
create policy "Users can delete own profile"
  on public.profiles for delete
  using (auth.uid() = id);

-- ---------------------------------------------------------------------------
-- clans RLS
-- ---------------------------------------------------------------------------
drop policy if exists "Clans are viewable by everyone" on public.clans;
create policy "Clans are viewable by everyone"
  on public.clans for select
  using (true);

drop policy if exists "Authenticated users can create clans" on public.clans;
create policy "Authenticated users can create clans"
  on public.clans for insert
  with check (auth.uid() = leader_id);

drop policy if exists "Leaders can update own clan" on public.clans;
create policy "Leaders can update own clan"
  on public.clans for update
  using (auth.uid() = leader_id)
  with check (auth.uid() = leader_id);

drop policy if exists "Leaders can delete own clan" on public.clans;
create policy "Leaders can delete own clan"
  on public.clans for delete
  using (auth.uid() = leader_id);

-- ---------------------------------------------------------------------------
-- clan_members RLS
-- ---------------------------------------------------------------------------
drop policy if exists "Clan members are viewable by everyone" on public.clan_members;
create policy "Clan members are viewable by everyone"
  on public.clan_members for select
  using (true);

drop policy if exists "Users can join clans" on public.clan_members;
create policy "Users can join clans"
  on public.clan_members for insert
  with check (auth.uid() = player_id);

drop policy if exists "Users can leave clans" on public.clan_members;
create policy "Users can leave clans"
  on public.clan_members for delete
  using (auth.uid() = player_id);

drop policy if exists "Officers can update clan members" on public.clan_members;
create policy "Officers can update clan members"
  on public.clan_members for update
  using (
    exists (
      select 1 from public.clan_members cm
      where cm.clan_id = clan_members.clan_id
        and cm.player_id = auth.uid()
        and cm.role in ('leader', 'officer')
    )
  )
  with check (
    exists (
      select 1 from public.clan_members cm
      where cm.clan_id = clan_members.clan_id
        and cm.player_id = auth.uid()
        and cm.role in ('leader', 'officer')
    )
  );

-- ---------------------------------------------------------------------------
-- network_nodes RLS
-- ---------------------------------------------------------------------------
drop policy if exists "Network nodes are viewable by everyone" on public.network_nodes;
create policy "Network nodes are viewable by everyone"
  on public.network_nodes for select
  using (true);

drop policy if exists "Users can create own nodes" on public.network_nodes;
create policy "Users can create own nodes"
  on public.network_nodes for insert
  with check (auth.uid() = player_id);

drop policy if exists "Users can update their own nodes" on public.network_nodes;
create policy "Users can update their own nodes"
  on public.network_nodes for update
  using (auth.uid() = player_id)
  with check (auth.uid() = player_id);

drop policy if exists "Users can delete their own nodes" on public.network_nodes;
create policy "Users can delete their own nodes"
  on public.network_nodes for delete
  using (auth.uid() = player_id);

-- ---------------------------------------------------------------------------
-- attacks RLS
-- ---------------------------------------------------------------------------
drop policy if exists "Users can view own attacks" on public.attacks;
create policy "Users can view own attacks"
  on public.attacks for select
  using (auth.uid() = attacker_id or auth.uid() = defender_id);

drop policy if exists "Users can create attacks" on public.attacks;
create policy "Users can create attacks"
  on public.attacks for insert
  with check (auth.uid() = attacker_id);

drop policy if exists "Attackers can update own attacks" on public.attacks;
create policy "Attackers can update own attacks"
  on public.attacks for update
  using (auth.uid() = attacker_id)
  with check (auth.uid() = attacker_id);

-- ---------------------------------------------------------------------------
-- chat_messages RLS
-- ---------------------------------------------------------------------------
drop policy if exists "Global chat is viewable by everyone" on public.chat_messages;
create policy "Global chat is viewable by everyone"
  on public.chat_messages for select
  using (clan_id is null or
    exists (
      select 1 from public.clan_members cm
      where cm.clan_id = chat_messages.clan_id
        and cm.player_id = auth.uid()
    )
  );

drop policy if exists "Authenticated users can send messages" on public.chat_messages;
create policy "Authenticated users can send messages"
  on public.chat_messages for insert
  with check (
    auth.uid() = sender_id
    and (
      clan_id is null
      or exists (
        select 1 from public.clan_members cm
        where cm.clan_id = chat_messages.clan_id
          and cm.player_id = auth.uid()
      )
    )
  );

-- ---------------------------------------------------------------------------
-- market_items RLS
-- ---------------------------------------------------------------------------
drop policy if exists "Market items are viewable by everyone" on public.market_items;
create policy "Market items are viewable by everyone"
  on public.market_items for select
  using (true);

drop policy if exists "No anonymous market item inserts" on public.market_items;
create policy "No anonymous market item inserts"
  on public.market_items for insert
  with check (false);

drop policy if exists "No anonymous market item updates" on public.market_items;
create policy "No anonymous market item updates"
  on public.market_items for update
  using (false);

drop policy if exists "No anonymous market item deletes" on public.market_items;
create policy "No anonymous market item deletes"
  on public.market_items for delete
  using (false);

-- ---------------------------------------------------------------------------
-- player_inventory RLS
-- ---------------------------------------------------------------------------
drop policy if exists "Users can view own inventory" on public.player_inventory;
create policy "Users can view own inventory"
  on public.player_inventory for select
  using (auth.uid() = player_id);

drop policy if exists "Users can add to own inventory" on public.player_inventory;
create policy "Users can add to own inventory"
  on public.player_inventory for insert
  with check (auth.uid() = player_id);

drop policy if exists "Users can update their own inventory" on public.player_inventory;
create policy "Users can update their own inventory"
  on public.player_inventory for update
  using (auth.uid() = player_id)
  with check (auth.uid() = player_id);

-- ---------------------------------------------------------------------------
-- player_stats RLS
-- ---------------------------------------------------------------------------
drop policy if exists "Player stats are viewable by everyone" on public.player_stats;
create policy "Player stats are viewable by everyone"
  on public.player_stats for select
  using (true);

drop policy if exists "Stats cannot be inserted directly" on public.player_stats;
create policy "Stats cannot be inserted directly"
  on public.player_stats for insert
  with check (false);

drop policy if exists "Stats cannot be updated directly" on public.player_stats;
create policy "Stats cannot be updated directly"
  on public.player_stats for update
  using (false);


-- =============================================================================
-- HELPER FUNCTIONS
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Calculate level from experience
-- ---------------------------------------------------------------------------
create or replace function public.calculate_level(xp integer)
returns integer
language sql
immutable
as $$
  select (xp / 1000) + 1
$$;

-- ---------------------------------------------------------------------------
-- XP needed for next level
-- ---------------------------------------------------------------------------
create or replace function public.xp_for_next_level(current_level integer)
returns integer
language sql
immutable
as $$
  select current_level * 1000
$$;

-- ---------------------------------------------------------------------------
-- Decrement market item stock safely
-- ---------------------------------------------------------------------------
create or replace function public.decrement_stock(p_item_id uuid)
returns integer
language plpgsql
security definer
as $$
declare
  new_stock integer;
begin
  update public.market_items
  set stock = greatest(stock - 1, 0)
  where id = p_item_id
  returning stock into new_stock;

  return new_stock;
end;
$$;

-- ---------------------------------------------------------------------------
-- Upgrade a network node (deducts credits, increases level/stats)
-- ---------------------------------------------------------------------------
create or replace function public.upgrade_network_node(
  p_node_id uuid,
  p_cost    integer
)
returns void
language plpgsql
security definer set search_path = ''
as $$
declare
  v_node    record;
  v_profile record;
  v_level   integer;
begin
  select * into v_node
  from public.network_nodes
  where id = p_node_id
  for update;

  if v_node is null then
    raise exception 'Node not found';
  end if;

  if auth.uid() is null or auth.uid() != v_node.player_id then
    raise exception 'Permission denied';
  end if;

  select credits into v_profile
  from public.profiles
  where id = auth.uid()
  for update;

  if v_profile.credits < p_cost then
    raise exception 'Insufficient credits';
  end if;

  v_level := v_node.node_level + 1;

  update public.profiles set credits = credits - p_cost
  where id = auth.uid();

  update public.network_nodes set
    node_level = v_level,
    max_health = v_node.max_health + 50,
    health = least(v_node.health + 50, v_node.max_health + 50)
  where id = p_node_id;

  update public.profiles set
    experience = experience + 60
  where id = auth.uid();
end;
$$;

-- ---------------------------------------------------------------------------
-- Purchase a market item
-- ---------------------------------------------------------------------------
create or replace function public.purchase_item(
  p_player_id uuid,
  p_item_id   uuid,
  p_price     integer
)
returns boolean
language plpgsql
security definer set search_path = ''
as $$
declare
  v_item    record;
  v_profile record;
  v_new_qty integer;
begin
  if auth.uid() is null or auth.uid() != p_player_id then
    raise exception 'Permission denied';
  end if;

  select * into v_item
  from public.market_items
  where id = p_item_id
  for update;

  if v_item is null then
    raise exception 'Item not found';
  end if;

  if v_item.stock = 0 then
    return false;
  end if;

  select credits into v_profile
  from public.profiles
  where id = p_player_id
  for update;

  if v_profile.credits < p_price then
    return false;
  end if;

  update public.profiles set credits = credits - p_price
  where id = p_player_id;

  if v_item.stock > 0 then
    update public.market_items set stock = stock - 1 where id = p_item_id;
  end if;

  insert into public.player_inventory (player_id, item_id, quantity)
  values (p_player_id, p_item_id, 1)
  on conflict (player_id, item_id) do update set
    quantity = player_inventory.quantity + 1;

  return true;
end;
$$;

-- ---------------------------------------------------------------------------
-- Process attack result
-- ---------------------------------------------------------------------------
create or replace function public.process_attack(
  p_attack_id uuid,
  p_success   boolean,
  p_stolen    integer default 0,
  p_xp_gain   integer default 50
)
returns void
language plpgsql
security definer
as $$
declare
  v_attack record;
  v_defender_credits integer;
  v_actual_stolen integer;
begin
  select * into v_attack
  from public.attacks
  where id = p_attack_id
  for update;

  if v_attack is null then
    raise exception 'Attack not found';
  end if;

  if v_attack.status != 'pending' then
    raise exception 'Attack already processed';
  end if;

  update public.attacks set
    status = case when p_success then 'success' else 'failed' end,
    credits_stolen = case when p_success then p_stolen else 0 end
  where id = p_attack_id;

  if p_success then
    select credits into v_defender_credits
    from public.profiles where id = v_attack.defender_id;

    v_actual_stolen := least(p_stolen, v_defender_credits);

    update public.profiles set
      credits = credits - v_actual_stolen
    where id = v_attack.defender_id;

    update public.profiles set
      credits = credits + v_actual_stolen,
      experience = experience + p_xp_gain
    where id = v_attack.attacker_id;

    if v_attack.target_node_id is not null then
      update public.network_nodes set
        health = greatest(health - v_attack.damage, 0),
        is_online = case when (health - v_attack.damage) <= 0 then false else is_online end
      where id = v_attack.target_node_id;
    end if;
  else
    update public.profiles set
      experience = experience + 10
    where id = v_attack.attacker_id;
  end if;
end;
$$;


-- =============================================================================
-- REALTIME SUBSCRIPTIONS
-- =============================================================================

do $$ begin
  alter publication supabase_realtime add table public.profiles;
exception when others then null;
end $$;

do $$ begin
  alter publication supabase_realtime add table public.attacks;
exception when others then null;
end $$;

do $$ begin
  alter publication supabase_realtime add table public.chat_messages;
exception when others then null;
end $$;

do $$ begin
  alter publication supabase_realtime add table public.network_nodes;
exception when others then null;
end $$;

do $$ begin
  alter publication supabase_realtime add table public.clan_members;
exception when others then null;
end $$;


-- =============================================================================
-- PVE CAMPAIGN SYSTEM — Tables, Indexes, RLS, Functions, Seed Data
-- =============================================================================
-- PvE campaign missions (like Vikings campaign), trainable programs ("troops"),
-- and campaign progress tracking.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- 11. CAMPAIGNS — PvE campaign missions
-- ---------------------------------------------------------------------------
create table if not exists public.campaigns (
  id               uuid        primary key default uuid_generate_v4(),
  name             text        not null,
  description      text,
  difficulty       integer     not null default 1 check (difficulty >= 1),
  required_level   integer     not null default 1 check (required_level >= 1),
  enemy_name       text        not null,
  enemy_strength   integer     not null default 50,
  reward_credits   integer     not null default 100 check (reward_credits >= 0),
  reward_xp        integer     not null default 50 check (reward_xp >= 0),
  reward_item_id   uuid        references public.market_items(id) on delete set null,
  sort_order       integer     not null default 0,
  is_active        boolean     not null default true,
  created_at       timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 12. CAMPAIGN PROGRESS — Tracks player progress on campaigns
-- ---------------------------------------------------------------------------
create table if not exists public.campaign_progress (
  id           uuid        primary key default uuid_generate_v4(),
  player_id    uuid        not null references public.profiles(id) on delete cascade,
  campaign_id  uuid        not null references public.campaigns(id) on delete cascade,
  status       text        not null default 'available'
                            check (status in ('available', 'in_progress', 'completed', 'failed')),
  attempts     integer     not null default 0 check (attempts >= 0),
  best_damage  integer     not null default 0 check (best_damage >= 0),
  completed_at timestamptz,
  created_at   timestamptz not null default now(),

  constraint campaign_progress_unique unique (player_id, campaign_id)
);

-- ---------------------------------------------------------------------------
-- 13. PLAYER PROGRAMS — Trainable hacking programs ("troops")
-- ---------------------------------------------------------------------------
create table if not exists public.player_programs (
  id            uuid        primary key default uuid_generate_v4(),
  player_id     uuid        not null references public.profiles(id) on delete cascade,
  program_type  text        not null
                             check (program_type in (
                               'trojan', 'worm', 'ransomware',
                               'spyware', 'botnet', 'rootkit'
                             )),
  quantity      integer     not null default 1 check (quantity >= 0),
  trained_at    timestamptz not null default now(),

  constraint player_programs_unique unique (player_id, program_type)
);

-- ---------------------------------------------------------------------------
-- 14. TRAINING QUEUE — Programs being trained
-- ---------------------------------------------------------------------------
create table if not exists public.training_queue (
  id                  uuid        primary key default uuid_generate_v4(),
  player_id           uuid        not null references public.profiles(id) on delete cascade,
  program_type        text        not null
                                  check (program_type in (
                                    'trojan', 'worm', 'ransomware',
                                    'spyware', 'botnet', 'rootkit'
                                  )),
  quantity            integer     not null default 1 check (quantity > 0),
  training_cost       integer     not null default 100 check (training_cost > 0),
  training_time_seconds integer   not null default 60 check (training_time_seconds > 0),
  started_at          timestamptz not null default now(),
  completes_at        timestamptz not null,
  status              text        not null default 'training'
                                  check (status in ('training', 'completed', 'cancelled'))
);


-- =============================================================================
-- CAMPAIGN SYSTEM — INDEXES
-- =============================================================================

-- campaigns
create index if not exists idx_campaigns_difficulty    on public.campaigns (difficulty);
create index if not exists idx_campaigns_required_lvl  on public.campaigns (required_level);
create index if not exists idx_campaigns_sort_order    on public.campaigns (sort_order);
create index if not exists idx_campaigns_active        on public.campaigns (is_active) where is_active = true;

-- campaign_progress
create index if not exists idx_camp_progress_player    on public.campaign_progress (player_id);
create index if not exists idx_camp_progress_campaign  on public.campaign_progress (campaign_id);
create index if not exists idx_camp_progress_status    on public.campaign_progress (player_id, status);

-- player_programs
create index if not exists idx_player_programs_player  on public.player_programs (player_id);
create index if not exists idx_player_programs_type    on public.player_programs (program_type);

-- training_queue
create index if not exists idx_training_queue_player   on public.training_queue (player_id);
create index if not exists idx_training_queue_status   on public.training_queue (player_id, status);
create index if not exists idx_training_queue_complete  on public.training_queue (status, completes_at) where status = 'training';


-- =============================================================================
-- CAMPAIGN SYSTEM — ROW LEVEL SECURITY (RLS)
-- =============================================================================

-- Enable RLS on campaign tables
do $$ begin
  alter table public.campaigns         enable row level security;
  alter table public.campaign_progress enable row level security;
  alter table public.player_programs   enable row level security;
  alter table public.training_queue    enable row level security;
exception when others then null;
end $$;

-- ---------------------------------------------------------------------------
-- campaigns RLS
-- ---------------------------------------------------------------------------
drop policy if exists "Campaigns are viewable by everyone" on public.campaigns;
create policy "Campaigns are viewable by everyone"
  on public.campaigns for select
  using (true);

drop policy if exists "No anonymous campaign inserts" on public.campaigns;
create policy "No anonymous campaign inserts"
  on public.campaigns for insert
  with check (false);

drop policy if exists "No anonymous campaign updates" on public.campaigns;
create policy "No anonymous campaign updates"
  on public.campaigns for update
  using (false);

drop policy if exists "No anonymous campaign deletes" on public.campaigns;
create policy "No anonymous campaign deletes"
  on public.campaigns for delete
  using (false);

-- ---------------------------------------------------------------------------
-- campaign_progress RLS
-- ---------------------------------------------------------------------------
drop policy if exists "Users can view own campaign progress" on public.campaign_progress;
create policy "Users can view own campaign progress"
  on public.campaign_progress for select
  using (auth.uid() = player_id);

drop policy if exists "Users can insert own campaign progress" on public.campaign_progress;
create policy "Users can insert own campaign progress"
  on public.campaign_progress for insert
  with check (auth.uid() = player_id);

drop policy if exists "Users can update own campaign progress" on public.campaign_progress;
create policy "Users can update own campaign progress"
  on public.campaign_progress for update
  using (auth.uid() = player_id)
  with check (auth.uid() = player_id);

-- ---------------------------------------------------------------------------
-- player_programs RLS
-- ---------------------------------------------------------------------------
drop policy if exists "Users can view own programs" on public.player_programs;
create policy "Users can view own programs"
  on public.player_programs for select
  using (auth.uid() = player_id);

drop policy if exists "Users can insert own programs" on public.player_programs;
create policy "Users can insert own programs"
  on public.player_programs for insert
  with check (auth.uid() = player_id);

drop policy if exists "Users can update own programs" on public.player_programs;
create policy "Users can update own programs"
  on public.player_programs for update
  using (auth.uid() = player_id)
  with check (auth.uid() = player_id);

-- ---------------------------------------------------------------------------
-- training_queue RLS
-- ---------------------------------------------------------------------------
drop policy if exists "Users can view own training queue" on public.training_queue;
create policy "Users can view own training queue"
  on public.training_queue for select
  using (auth.uid() = player_id);

drop policy if exists "Users can insert own training queue" on public.training_queue;
create policy "Users can insert own training queue"
  on public.training_queue for insert
  with check (auth.uid() = player_id);

drop policy if exists "Users can update own training queue" on public.training_queue;
create policy "Users can update own training queue"
  on public.training_queue for update
  using (auth.uid() = player_id)
  with check (auth.uid() = player_id);

drop policy if exists "Users can delete own training queue" on public.training_queue;
create policy "Users can delete own training queue"
  on public.training_queue for delete
  using (auth.uid() = player_id);


-- =============================================================================
-- CAMPAIGN SYSTEM — HELPER FUNCTIONS
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Complete a campaign mission
--   Updates campaign_progress, awards credits/xp on success, tracks stats.
-- ---------------------------------------------------------------------------
create or replace function public.complete_campaign(
  p_player_id    uuid,
  p_campaign_id  uuid,
  p_success      boolean,
  p_damage_dealt integer default 0
)
returns void
language plpgsql
security definer set search_path = ''
as $$
declare
  v_campaign record;
  v_status   text;
begin
  -- Fetch campaign details
  select * into v_campaign
  from public.campaigns
  where id = p_campaign_id;

  if v_campaign is null then
    raise exception 'Campaign not found';
  end if;

  -- Determine final status
  if p_success then
    v_status := 'completed';
  else
    v_status := 'failed';
  end if;

  -- Upsert campaign progress
  insert into public.campaign_progress (
    player_id, campaign_id, status, attempts, best_damage, completed_at
  ) values (
    p_player_id, p_campaign_id, v_status, 1,
    greatest(p_damage_dealt, 0),
    case when p_success then now() else null end
  )
  on conflict (player_id, campaign_id) do update set
    status       = excluded.status,
    attempts     = campaign_progress.attempts + 1,
    best_damage  = greatest(campaign_progress.best_damage, p_damage_dealt),
    completed_at = case
                      when excluded.status = 'completed' then now()
                      else campaign_progress.completed_at
                    end;

  -- Award rewards on success
  if p_success then
    -- Add credits
    update public.profiles
    set credits = credits + v_campaign.reward_credits
    where id = p_player_id;

    -- Add XP (trigger will auto-update level)
    update public.profiles
    set experience = experience + v_campaign.reward_xp
    where id = p_player_id;

    -- Update player stats
    insert into public.player_stats (
      player_id, total_attacks, successful_attacks,
      credits_earned, total_damage
    ) values (
      p_player_id, 1, 1,
      v_campaign.reward_credits, p_damage_dealt
    )
    on conflict (player_id) do update set
      total_attacks      = player_stats.total_attacks + 1,
      successful_attacks = player_stats.successful_attacks + 1,
      credits_earned     = player_stats.credits_earned + v_campaign.reward_credits,
      total_damage       = player_stats.total_damage + p_damage_dealt;
  else
    -- Still record the attempt in stats
    insert into public.player_stats (player_id, total_attacks)
    values (p_player_id, 1)
    on conflict (player_id) do update set
      total_attacks = player_stats.total_attacks + 1;
  end if;
end;
$$;


-- =============================================================================
-- CAMPAIGN SYSTEM — REALTIME SUBSCRIPTIONS
-- =============================================================================

do $$ begin
  alter publication supabase_realtime add table public.campaigns;
exception when others then null;
end $$;

do $$ begin
  alter publication supabase_realtime add table public.campaign_progress;
exception when others then null;
end $$;


-- =============================================================================
-- CAMPAIGN SYSTEM — SEED DATA (10 missions)
-- =============================================================================

-- Only insert if the campaigns table is empty
insert into public.campaigns (id, name, description, difficulty, required_level, enemy_name, enemy_strength, reward_credits, reward_xp, sort_order)
values
  (
    'a1b2c3d4-0001-4000-8000-000000000001',
    'Первый взлом',
    'Простая задача для новичков. Взломай unprotected сервер.',
    1, 1,
    'Скрипт-кидди',
    30,
    200, 50,
    1
  ),
  (
    'a1b2c3d4-0002-4000-8000-000000000002',
    'Корпоративная сеть',
    'Корпоративный firewall нужно обойти. Будь осторожен.',
    2, 2,
    'CORP-SEC-01',
    60,
    400, 100,
    2
  ),
  (
    'a1b2c3d4-0003-4000-8000-000000000003',
    'Финансовый сектор',
    'Банковские серверы защищены серьёзно. Покажи свои навыки.',
    3, 3,
    'BANK-GUARD',
    100,
    800, 150,
    3
  ),
  (
    'a1b2c3d4-0004-4000-8000-000000000004',
    'Государственные серверы',
    'Правительственная сеть с многоуровневой защитой. Только для опытных.',
    4, 5,
    'GOV-FIREWALL',
    150,
    1500, 250,
    4
  ),
  (
    'a1b2c3d4-0005-4000-8000-000000000005',
    'Тёмная сеть',
    'Тёмные узлы интернета — опасная территория для хакеров.',
    5, 7,
    'DARK-NODE',
    200,
    2500, 400,
    5
  ),
  (
    'a1b2c3d4-0006-4000-8000-000000000006',
    'Военная база',
    'Военные серверы с максимальной защитой. Только элита.',
    6, 10,
    'MIL-SERVER',
    300,
    5000, 600,
    6
  ),
  (
    'a1b2c3d4-0007-4000-8000-000000000007',
    'Квантовый центр',
    'Квантовые вычисления — новый frontier. Взломай будущее.',
    7, 13,
    'QUANTUM-AI',
    400,
    8000, 800,
    7
  ),
  (
    'a1b2c3d4-0008-4000-8000-000000000008',
    'Спутниковая сеть',
    'Спутниковые системы управления. Одна ошибка — и ты потерян.',
    8, 16,
    'SAT-CTRL',
    500,
    12000, 1000,
    8
  ),
  (
    'a1b2c3d4-0009-4000-8000-000000000009',
    'Подводный кабель',
    'Подводные коммуникационные кабели — уязвимое звено мировой сети.',
    9, 20,
    'DEEP-WEB',
    650,
    20000, 1500,
    9
  ),
  (
    'a1b2c3d4-0010-4000-8000-000000000010',
    'Главный сервер',
    'Финальная миссия. Главный сервер — ядро всей системы. Удачи.',
    10, 25,
    'OMEGA-CORE',
    1000,
    50000, 3000,
    10
  )
on conflict do nothing;


-- ═══════════════════════════════════════════════════════════════════════
-- WEEKLY EVENTS SYSTEM
-- ═══════════════════════════════════════════════════════════════════════

create table if not exists public.weekly_events (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    description text,
    event_type text not null check (event_type in ('pvp_tournament', 'black_friday', 'clan_raid', 'bug_hunt')),
    start_date timestamptz not null,
    end_date timestamptz not null,
    is_active boolean default false,
    reward_credits int default 0,
    reward_xp int default 0,
    reward_item_id uuid references public.market_items(id),
    bonus_modifier jsonb default '{}'::jsonb,
    created_at timestamptz default now()
);

create table if not exists public.event_participation (
    id uuid primary key default gen_random_uuid(),
    player_id uuid not null references public.profiles(id) on delete cascade,
    event_id uuid not null references public.weekly_events(id) on delete cascade,
    score int default 0,
    attempts int default 0,
    best_score int default 0,
    has_claimed_reward boolean default false,
    rank_position int default 0,
    created_at timestamptz default now(),
    updated_at timestamptz default now(),
    unique(player_id, event_id)
);

-- ═══════════════════════════════════════════════════════════════════════
-- DAILY REWARDS (Streak System)
-- ═══════════════════════════════════════════════════════════════════════

create table if not exists public.daily_rewards (
    id uuid primary key default gen_random_uuid(),
    player_id uuid not null references public.profiles(id) on delete cascade,
    streak_day int not null default 1,
    last_claim_date date,
    current_streak int not null default 0,
    best_streak int not null default 0,
    total_claimed int not null default 0,
    created_at timestamptz default now(),
    updated_at timestamptz default now(),
    unique(player_id)
);

-- ═══════════════════════════════════════════════════════════════════════
-- ACHIEVEMENTS SYSTEM
-- ═══════════════════════════════════════════════════════════════════════

create table if not exists public.achievements (
    id uuid primary key default gen_random_uuid(),
    key text not null unique,
    name text not null,
    description text,
    icon text not null default 'star',
    category text not null default 'general' check (category in ('network', 'combat', 'economy', 'social', 'special')),
    requirement jsonb not null default '{}'::jsonb,
    reward_credits int default 0,
    reward_xp int default 0,
    sort_order int default 0,
    is_hidden boolean default false
);

create table if not exists public.player_achievements (
    id uuid primary key default gen_random_uuid(),
    player_id uuid not null references public.profiles(id) on delete cascade,
    achievement_id uuid not null references public.achievements(id) on delete cascade,
    progress jsonb not null default '{}'::jsonb,
    is_completed boolean default false,
    is_claimed boolean default false,
    completed_at timestamptz,
    claimed_at timestamptz,
    created_at timestamptz default now(),
    unique(player_id, achievement_id)
);

-- ═══════════════════════════════════════════════════════════════════════
-- RPC FUNCTIONS FOR NEW SYSTEMS
-- ═══════════════════════════════════════════════════════════════════════

-- Claim daily reward (with streak tracking)
create or replace function public.claim_daily_reward(p_player_id uuid)
returns jsonb as $$
declare
    v_reward record;
    v_today date := current_date;
    v_streak int;
    v_rewards jsonb := '[
        {"day":1,"credits":100,"xp":10},
        {"day":2,"credits":200,"xp":20},
        {"day":3,"credits":300,"xp":30},
        {"day":4,"credits":500,"xp":50},
        {"day":5,"credits":800,"xp":80},
        {"day":6,"credits":1200,"xp":120},
        {"day":7,"credits":2000,"xp":250}
    ]'::jsonb;
begin
    -- Upsert daily reward record
    insert into public.daily_rewards (player_id, streak_day, last_claim_date, current_streak, total_claimed)
    values (p_player_id, 1, null, 0, 0)
    on conflict (player_id) do nothing;

    select * into v_reward from public.daily_rewards where player_id = p_player_id;

    -- Check if already claimed today
    if v_reward.last_claim_date = v_today then
        return jsonb_build_object('success', false, 'message', 'Награда уже получена сегодня');
    end if;

    -- Calculate streak
    if v_reward.last_claim_date = v_today - 1 then
        v_streak := least(v_reward.current_streak + 1, 7);
    elsif v_reward.last_claim_date < v_today - 1 then
        v_streak := 1;
    else
        v_streak := 1;
    end if;

    -- Get reward for current day
    v_reward.streak_day := v_streak;
    v_reward.current_streak := v_streak;
    v_reward.last_claim_date := v_today;
    v_reward.total_claimed := v_reward.total_claimed + 1;
    if v_streak > v_reward.best_streak then
        v_reward.best_streak := v_streak;
    end if;

    -- Apply credits and xp reward
    update public.profiles
    set credits = credits + (v_rewards->>(v_streak-1)->>'credits')::int,
        experience = experience + (v_rewards->>(v_streak-1)->>'xp')::int
    where id = p_player_id;

    -- Save daily reward state
    update public.daily_rewards
    set streak_day = v_streak,
        last_claim_date = v_today,
        current_streak = v_streak,
        best_streak = greatest(best_streak, v_streak),
        total_claimed = total_claimed + 1,
        updated_at = now()
    where player_id = p_player_id;

    return jsonb_build_object(
        'success', true,
        'streak', v_streak,
        'credits', (v_rewards->>(v_streak-1)->>'credits')::int,
        'xp', (v_rewards->>(v_streak-1)->>'xp')::int,
        'total_claimed', v_reward.total_claimed + 1
    );
end;
$$ language plpgsql security definer;

-- Get active weekly events
create or replace function public.get_active_events()
returns setof public.weekly_events as $$
begin
    return query
    select * from public.weekly_events
    where is_active = true
      and start_date <= now()
      and end_date >= now()
    order by start_date;
end;
$$ language plpgsql security definer stable;

-- Join event
create or replace function public.join_event(p_player_id uuid, p_event_id uuid)
returns boolean as $$
begin
    insert into public.event_participation (player_id, event_id)
    values (p_player_id, p_event_id)
    on conflict (player_id, event_id) do nothing;
    return true;
end;
$$ language plpgsql security definer;

-- Update event score
create or replace function public.update_event_score(p_player_id uuid, p_event_id uuid, p_score int)
returns boolean as $$
begin
    update public.event_participation
    set score = score + p_score,
        attempts = attempts + 1,
        best_score = greatest(best_score, p_score),
        updated_at = now()
    where player_id = p_player_id and event_id = p_event_id;
    return true;
end;
$$ language plpgsql security definer;

-- Check and unlock achievements
create or replace function public.check_achievements(p_player_id uuid)
returns setof uuid as $$
declare
    v_profile record;
    v_node_count int;
    v_attack_count int;
    v_max_streak int;
begin
    select * into v_profile from public.profiles where id = p_player_id;
    select count(*) into v_node_count from public.network_nodes where player_id = p_player_id;
    select count(*) into v_attack_count from public.attacks where attacker_id = p_player_id;
    select coalesce(best_streak, 0) into v_max_streak from public.daily_rewards where player_id = p_player_id;

    -- First Node
    if v_node_count >= 1 then
        insert into public.player_achievements (player_id, achievement_id, progress, is_completed, completed_at)
        select p_player_id, id, '{"nodes":1}'::jsonb, true, now()
        from public.achievements where key = 'first_node'
        on conflict (player_id, achievement_id) do nothing
        returning achievement_id;
    end if;

    -- Network Builder (5 nodes)
    if v_node_count >= 5 then
        insert into public.player_achievements (player_id, achievement_id, progress, is_completed, completed_at)
        select p_player_id, id, jsonb_build_object('nodes', v_node_count)::jsonb, true, now()
        from public.achievements where key = 'network_builder'
        on conflict (player_id, achievement_id) do nothing
        returning achievement_id;
    end if;

    -- First Blood (first attack)
    if v_attack_count >= 1 then
        insert into public.player_achievements (player_id, achievement_id, progress, is_completed, completed_at)
        select p_player_id, id, jsonb_build_object('attacks', v_attack_count)::jsonb, true, now()
        from public.achievements where key = 'first_blood'
        on conflict (player_id, achievement_id) do nothing
        returning achievement_id;
    end if;

    -- Veteran (100 attacks)
    if v_attack_count >= 100 then
        insert into public.player_achievements (player_id, achievement_id, progress, is_completed, completed_at)
        select p_player_id, id, jsonb_build_object('attacks', v_attack_count)::jsonb, true, now()
        from public.achievements where key = 'veteran'
        on conflict (player_id, achievement_id) do nothing
        returning achievement_id;
    end if;

    -- Millionaire (1M credits)
    if v_profile.credits >= 1000000 then
        insert into public.player_achievements (player_id, achievement_id, progress, is_completed, completed_at)
        select p_player_id, id, jsonb_build_object('credits', v_profile.credits)::jsonb, true, now()
        from public.achievements where key = 'millionaire'
        on conflict (player_id, achievement_id) do nothing
        returning achievement_id;
    end if;

    -- Streak Master (7 day streak)
    if v_max_streak >= 7 then
        insert into public.player_achievements (player_id, achievement_id, progress, is_completed, completed_at)
        select p_player_id, id, jsonb_build_object('streak', v_max_streak)::jsonb, true, now()
        from public.achievements where key = 'streak_master'
        on conflict (player_id, achievement_id) do nothing
        returning achievement_id;
    end if;

    return;
end;
$$ language plpgsql security definer;

-- Seed default achievements
create or replace function public.seed_achievements()
returns void as $$
begin
    insert into public.achievements (key, name, description, icon, category, reward_credits, reward_xp, sort_order) values
    ('first_node', 'Первый узел', 'Разверните свой первый сетевой узел', 'dns', 'network', 500, 50, 1),
    ('network_builder', 'Строитель сети', 'Разверните 5 или более узлов', 'account_tree', 'network', 2000, 200, 2),
    ('network_empire', 'Сетевая империя', 'Разверните 15 или более узлов', 'hub', 'network', 10000, 500, 3),
    ('first_blood', 'Первая кровь', 'Проведите свою первую атаку', 'gps_fixed', 'combat', 300, 25, 10),
    ('aggressor', 'Агрессор', 'Проведите 25 атак', 'flash_on', 'combat', 1500, 100, 11),
    ('veteran', 'Ветеран', 'Проведите 100 атак', 'military_tech', 'combat', 5000, 300, 12),
    ('millionaire', 'Миллионер', 'Накопите 1,000,000 кредитов', 'monetization_on', 'economy', 0, 1000, 20),
    'trader', 'Торговец', 'Купите 10 товаров на рынке', 'storefront', 'economy', 1000, 100, 21),
    ('clan_founder', 'Основатель', 'Создайте свой клан', 'groups', 'social', 500, 50, 30),
    ('streak_master', 'Мастер streak''а', 'Добейтесь 7-дневной серии наград', 'local_fire_department', 'special', 3000, 200, 40)
    on conflict (key) do nothing;
end;
$$ language plpgsql security definer;

-- RLS for new tables
alter table public.weekly_events enable row level security;
alter table public.event_participation enable row level security;
alter table public.daily_rewards enable row level security;
alter table public.achievements enable row level security;
alter table public.player_achievements enable row level security;

create policy "weekly_events_select" on public.weekly_events for select using (true);
create policy "event_participation_select" on public.event_participation for select using (player_id = auth.uid());
create policy "event_participation_insert" on public.event_participation for insert with check (player_id = auth.uid());
create policy "event_participation_update" on public.event_participation for update using (player_id = auth.uid());
create policy "daily_rewards_select" on public.daily_rewards for select using (player_id = auth.uid());
create policy "daily_rewards_insert" on public.daily_rewards for insert with check (player_id = auth.uid());
create policy "daily_rewards_update" on public.daily_rewards for update using (player_id = auth.uid());
create policy "achievements_select" on public.achievements for select using (true);
create policy "player_achievements_select" on public.player_achievements for select using (player_id = auth.uid());
create policy "player_achievements_insert" on public.player_achievements for insert with check (player_id = auth.uid());
create policy "player_achievements_update" on public.player_achievements for update using (player_id = auth.uid());

-- Seed events and achievements on first run
select public.seed_achievements();
