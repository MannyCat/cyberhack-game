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
-- profiles RLS
-- ---------------------------------------------------------------------------
create or replace policy "Profiles are viewable by everyone"
  on public.profiles for select
  using (true);

create or replace policy "Users can update own profile"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

create or replace policy "Service role can insert profiles"
  on public.profiles for insert
  with check (true);

create or replace policy "Users can delete own profile"
  on public.profiles for delete
  using (auth.uid() = id);

-- ---------------------------------------------------------------------------
-- clans RLS
-- ---------------------------------------------------------------------------
create or replace policy "Clans are viewable by everyone"
  on public.clans for select
  using (true);

create or replace policy "Authenticated users can create clans"
  on public.clans for insert
  with check (auth.uid() = leader_id);

create or replace policy "Leaders can update own clan"
  on public.clans for update
  using (auth.uid() = leader_id)
  with check (auth.uid() = leader_id);

create or replace policy "Leaders can delete own clan"
  on public.clans for delete
  using (auth.uid() = leader_id);

-- ---------------------------------------------------------------------------
-- clan_members RLS
-- ---------------------------------------------------------------------------
create or replace policy "Clan members are viewable by everyone"
  on public.clan_members for select
  using (true);

create or replace policy "Users can join clans"
  on public.clan_members for insert
  with check (auth.uid() = player_id);

create or replace policy "Users can leave clans"
  on public.clan_members for delete
  using (auth.uid() = player_id);

create or replace policy "Officers can update clan members"
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
create or replace policy "Network nodes are viewable by everyone"
  on public.network_nodes for select
  using (true);

create or replace policy "Users can create own nodes"
  on public.network_nodes for insert
  with check (auth.uid() = player_id);

create or replace policy "Users can update their own nodes"
  on public.network_nodes for update
  using (auth.uid() = player_id)
  with check (auth.uid() = player_id);

create or replace policy "Users can delete their own nodes"
  on public.network_nodes for delete
  using (auth.uid() = player_id);

-- ---------------------------------------------------------------------------
-- attacks RLS
-- ---------------------------------------------------------------------------
create or replace policy "Users can view own attacks"
  on public.attacks for select
  using (auth.uid() = attacker_id or auth.uid() = defender_id);

create or replace policy "Users can create attacks"
  on public.attacks for insert
  with check (auth.uid() = attacker_id);

create or replace policy "Attackers can update own attacks"
  on public.attacks for update
  using (auth.uid() = attacker_id)
  with check (auth.uid() = attacker_id);

-- ---------------------------------------------------------------------------
-- chat_messages RLS
-- ---------------------------------------------------------------------------
create or replace policy "Global chat is viewable by everyone"
  on public.chat_messages for select
  using (clan_id is null or
    exists (
      select 1 from public.clan_members cm
      where cm.clan_id = chat_messages.clan_id
        and cm.player_id = auth.uid()
    )
  );

create or replace policy "Authenticated users can send messages"
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
create or replace policy "Market items are viewable by everyone"
  on public.market_items for select
  using (true);

create or replace policy "No anonymous market item inserts"
  on public.market_items for insert
  with check (false);

create or replace policy "No anonymous market item updates"
  on public.market_items for update
  using (false);

create or replace policy "No anonymous market item deletes"
  on public.market_items for delete
  using (false);

-- ---------------------------------------------------------------------------
-- player_inventory RLS
-- ---------------------------------------------------------------------------
create or replace policy "Users can view own inventory"
  on public.player_inventory for select
  using (auth.uid() = player_id);

create or replace policy "Users can add to own inventory"
  on public.player_inventory for insert
  with check (auth.uid() = player_id);

create or replace policy "Users can update their own inventory"
  on public.player_inventory for update
  using (auth.uid() = player_id)
  with check (auth.uid() = player_id);

-- ---------------------------------------------------------------------------
-- player_stats RLS
-- ---------------------------------------------------------------------------
create or replace policy "Player stats are viewable by everyone"
  on public.player_stats for select
  using (true);

create or replace policy "Stats cannot be inserted directly"
  on public.player_stats for insert
  with check (false);

create or replace policy "Stats cannot be updated directly"
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
