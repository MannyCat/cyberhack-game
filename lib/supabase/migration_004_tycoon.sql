-- =============================================================================
-- CyberHack Tycoon — Migration 004: Tycoon-style tables
-- All corporation names are 100% FICTIONAL
-- =============================================================================

create extension if not exists "uuid-ossp";

-- ---------------------------------------------------------------------------
-- 1. SERVER TYPES (ship types analogue)
-- ---------------------------------------------------------------------------
create table if not exists public.server_types (
  id              uuid primary key default uuid_generate_v4(),
  name            text not null,
  server_class    text not null
                  check (server_class in (
                    'basic','advanced','premium','elite','legendary'
                  )),
  max_bandwidth   integer not null default 100,
  power_cost      integer not null default 10,
  security_rating integer not null default 50,
  storage_tb      integer not null default 1,
  price_credits   integer not null default 500,
  emoji           text not null default '',
  sort_order      integer not null default 0,
  created_at      timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 2. PLAYER SERVERS (ships analogue)
-- ---------------------------------------------------------------------------
create table if not exists public.player_servers (
  id              uuid primary key default uuid_generate_v4(),
  player_id       uuid not null references public.profiles(id) on delete cascade,
  server_type_id  uuid not null references public.server_types(id),
  name            text not null default 'Server',
  health          integer not null default 100 check (health >= 0),
  max_health      integer not null default 100 check (max_health > 0),
  current_load    integer not null default 0 check (current_load >= 0),
  is_active       boolean not null default true,
  purchased_at    timestamptz not null default now(),
  created_at      timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 3. TARGETS (ports analogue) — ALL FICTIONAL CORPORATIONS
-- ---------------------------------------------------------------------------
create table if not exists public.targets (
  id              uuid primary key default uuid_generate_v4(),
  name            text not null,
  corp_name       text not null,
  target_class    text not null
                  check (target_class in (
                    'bank','tech','energy','logistics','retail','pharma','media','gov'
                  )),
  difficulty      integer not null default 1 check (difficulty between 1 and 10),
  base_reward     integer not null default 100 check (base_reward >= 0),
  base_xp         integer not null default 20 check (base_xp >= 0),
  security_level  integer not null default 50 check (security_level between 1 and 100),
  region          text not null default 'global',
  description     text,
  sort_order      integer not null default 0,
  is_active       boolean not null default true,
  created_at      timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 4. OPERATIONS (routes analogue)
-- ---------------------------------------------------------------------------
create table if not exists public.operations (
  id              uuid primary key default uuid_generate_v4(),
  player_id       uuid not null references public.profiles(id) on delete cascade,
  server_id       uuid not null references public.player_servers(id) on delete cascade,
  target_id       uuid not null references public.targets(id),
  op_type         text not null
                  check (op_type in (
                    'data_theft','ddos','ransomware','espionage',
                    'crypto_mining','identity_theft'
                  )),
  status          text not null default 'planning'
                  check (status in (
                    'planning','active','completed','failed','cancelled'
                  )),
  duration_minutes integer not null default 10 check (duration_minutes > 0),
  started_at      timestamptz,
  completes_at    timestamptz,
  power_used       integer not null default 0 check (power_used >= 0),
  reward_credits   integer not null default 0 check (reward_credits >= 0),
  reward_xp        integer not null default 0 check (reward_xp >= 0),
  heat_generated   integer not null default 0 check (heat_generated >= 0),
  created_at       timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 5. AGENTS (staff analogue)
-- ---------------------------------------------------------------------------
create table if not exists public.agents (
  id              uuid primary key default uuid_generate_v4(),
  player_id       uuid not null references public.profiles(id) on delete cascade,
  agent_name      text not null,
  agent_class     text not null
                  check (agent_class in (
                    'script_kiddie','hacker','analyst','engineer',
                    'mastermind','ghost'
                  )),
  skill_level     integer not null default 1 check (skill_level between 1 and 100),
  salary_credits  integer not null default 50 check (salary_credits >= 0),
  efficiency       integer not null default 70 check (efficiency between 0 and 100),
  specialty        text
                  check (specialty in (
                    'offense','defense','stealth','economy','research',null
                  )),
  is_active        boolean not null default true,
  hired_at         timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 6. RESEARCH (research/tech tree)
-- ---------------------------------------------------------------------------
create table if not exists public.research (
  id              uuid primary key default uuid_generate_v4(),
  name            text not null,
  category        text not null
                  check (category in (
                    'offense','defense','economy','infrastructure','stealth'
                  )),
  tier            integer not null default 1 check (tier between 1 and 5),
  cost_credits    integer not null default 500 check (cost_credits > 0),
  cost_time_hours integer not null default 1 check (cost_time_hours > 0),
  effect_json     jsonb not null default '{}'::jsonb,
  required_research_id uuid references public.research(id) on delete set null,
  description     text,
  sort_order      integer not null default 0,
  is_active       boolean not null default true,
  created_at      timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 7. PLAYER RESEARCH PROGRESS
-- ---------------------------------------------------------------------------
create table if not exists public.player_research (
  id              uuid primary key default uuid_generate_v4(),
  player_id       uuid not null references public.profiles(id) on delete cascade,
  research_id     uuid not null references public.research(id) on delete cascade,
  status          text not null default 'available'
                  check (status in (
                    'available','researching','completed'
                  )),
  started_at      timestamptz,
  completes_at    timestamptz,
  created_at      timestamptz not null default now(),

  constraint player_research_unique unique (player_id, research_id)
);

-- ---------------------------------------------------------------------------
-- 8. Add heat column to profiles
-- ---------------------------------------------------------------------------
do $$ begin
  alter table public.profiles add column if not exists heat integer not null default 0 check (heat >= 0);
  alter table public.profiles add column if not exists power integer not null default 200 check (power >= 0);
  alter table public.profiles add column if not exists max_power integer not null default 200 check (max_power > 0);
  alter table public.profiles add column if not exists total_earnings bigint not null default 0;
  alter table public.profiles add column if not exists reputation integer not null default 0;
exception when others then null;
end $$;


-- =============================================================================
-- INDEXES
-- =============================================================================

create index if not exists idx_server_types_class on public.server_types (server_class);
create index if not exists idx_player_servers_player on public.player_servers (player_id);
create index if not exists idx_player_servers_active on public.player_servers (player_id, is_active);
create index if not exists idx_targets_class on public.targets (target_class);
create index if not exists idx_targets_difficulty on public.targets (difficulty);
create index if not exists idx_targets_active on public.targets (is_active) where is_active = true;
create index if not exists idx_operations_player on public.operations (player_id);
create index if not exists idx_operations_status on public.operations (player_id, status);
create index if not exists idx_operations_active on public.operations (status, completes_at) where status = 'active';
create index if not exists idx_agents_player on public.agents (player_id);
create index if not exists idx_agents_active on public.agents (player_id, is_active);
create index if not exists idx_research_category on public.research (category, tier);
create index if not exists idx_research_tier on public.research (tier);
create index if not exists idx_player_research_player on public.player_research (player_id);
create index if not exists idx_player_research_status on public.player_research (player_id, status);


-- =============================================================================
-- ROW LEVEL SECURITY (RLS)
-- =============================================================================

do $$ begin
  alter table public.server_types      enable row level security;
  alter table public.player_servers    enable row level security;
  alter table public.targets           enable row level security;
  alter table public.operations        enable row level security;
  alter table public.agents            enable row level security;
  alter table public.research          enable row level security;
  alter table public.player_research   enable row level security;
exception when others then null;
end $$;

-- server_types — read-only for all
drop policy if exists "Server types viewable by all" on public.server_types;
create policy "Server types viewable by all" on public.server_types for select using (true);
drop policy if exists "No inserts to server_types" on public.server_types;
create policy "No inserts to server_types" on public.server_types for insert with check (false);
drop policy if exists "No updates to server_types" on public.server_types;
create policy "No updates to server_types" on public.server_types for update using (false);
drop policy if exists "No deletes to server_types" on public.server_types;
create policy "No deletes to server_types" on public.server_types for delete using (false);

-- player_servers — own only
drop policy if exists "View own servers" on public.player_servers;
create policy "View own servers" on public.player_servers for select using (true);
drop policy if exists "Insert own servers" on public.player_servers;
create policy "Insert own servers" on public.player_servers for insert with check (true);
drop policy if exists "Update own servers" on public.player_servers;
create policy "Update own servers" on public.player_servers for update using (true) with check (true);
drop policy if exists "Delete own servers" on public.player_servers;
create policy "Delete own servers" on public.player_servers for delete using (true);

-- targets — read-only for all
drop policy if exists "Targets viewable by all" on public.targets;
create policy "Targets viewable by all" on public.targets for select using (true);
drop policy if exists "No inserts to targets" on public.targets;
create policy "No inserts to targets" on public.targets for insert with check (false);
drop policy if exists "No updates to targets" on public.targets;
create policy "No updates to targets" on public.targets for update using (false);
drop policy if exists "No deletes to targets" on public.targets;
create policy "No deletes to targets" on public.targets for delete using (false);

-- operations — own only
drop policy if exists "View own operations" on public.operations;
create policy "View own operations" on public.operations for select using (auth.uid() = player_id);
drop policy if exists "Insert own operations" on public.operations;
create policy "Insert own operations" on public.operations for insert with check (auth.uid() = player_id);
drop policy if exists "Update own operations" on public.operations;
create policy "Update own operations" on public.operations for update using (auth.uid() = player_id) with check (auth.uid() = player_id);

-- agents — own only
drop policy if exists "View own agents" on public.agents;
create policy "View own agents" on public.agents for select using (auth.uid() = player_id);
drop policy if exists "Insert own agents" on public.agents;
create policy "Insert own agents" on public.agents for insert with check (true);
drop policy if exists "Update own agents" on public.agents;
create policy "Update own agents" on public.agents for update using (auth.uid() = player_id) with check (auth.uid() = player_id);
drop policy if exists "Delete own agents" on public.agents;
create policy "Delete own agents" on public.agents for delete using (auth.uid() = player_id);

-- research — read-only for all
drop policy if exists "Research viewable by all" on public.research;
create policy "Research viewable by all" on public.research for select using (true);
drop policy if exists "No inserts to research" on public.research;
create policy "No inserts to research" on public.research for insert with check (false);
drop policy if exists "No updates to research" on public.research;
create policy "No updates to research" on public.research for update using (false);
drop policy if exists "No deletes to research" on public.research;
create policy "No deletes to research" on public.research for delete using (false);

-- player_research — own only
drop policy if exists "View own research" on public.player_research;
create policy "View own research" on public.player_research for select using (auth.uid() = player_id);
drop policy if exists "Insert own research" on public.player_research;
create policy "Insert own research" on public.player_research for insert with check (auth.uid() = player_id);
drop policy if exists "Update own research" on public.player_research;
create policy "Update own research" on public.player_research for update using (auth.uid() = player_id) with check (auth.uid() = player_id);


-- =============================================================================
-- HELPER FUNCTIONS
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Buy a server (deduct credits, create server)
-- ---------------------------------------------------------------------------
create or replace function public.buy_server(
  p_type_id uuid,
  p_name    text default 'My Server'
)
returns uuid
language plpgsql
security definer set search_path = ''
as $$
declare
  v_type    record;
  v_credits integer;
  v_id      uuid;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;

  select * into v_type from public.server_types where id = p_type_id;
  if v_type is null then raise exception 'Server type not found'; end if;

  select credits into v_credits from public.profiles where id = auth.uid();
  if v_credits < v_type.price_credits then raise exception 'Insufficient credits'; end if;

  update public.profiles set credits = credits - v_type.price_credits where id = auth.uid();

  insert into public.player_servers (player_id, server_type_id, name, max_health, current_load)
  values (auth.uid(), p_type_id, p_name, 100 + v_type.security_rating, 0)
  returning id into v_id;

  return v_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Start an operation (deduct power, set timer)
-- ---------------------------------------------------------------------------
create or replace function public.start_operation(
  p_server_id uuid,
  p_target_id uuid,
  p_op_type   text
)
returns uuid
language plpgsql
security definer set search_path = ''
as $$
declare
  v_server    record;
  v_target    record;
  v_profile   record;
  v_id        uuid;
  v_duration  integer;
  v_reward    integer;
  v_xp        integer;
  v_heat      integer;
  v_power     integer;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;

  select ps.*, st.power_cost, st.max_bandwidth
  into v_server
  from public.player_servers ps
  join public.server_types st on st.id = ps.server_type_id
  where ps.id = p_server_id and ps.player_id = auth.uid() and ps.is_active = true;
  if v_server is null then raise exception 'Server not available'; end if;

  select * into v_target from public.targets where id = p_target_id and is_active = true;
  if v_target is null then raise exception 'Target not available'; end if;

  select power into v_profile from public.profiles where id = auth.uid();
  if v_profile < v_server.power_cost then raise exception 'Insufficient power'; end if;

  -- Calculate duration/reward based on difficulty
  v_duration := 5 + v_target.difficulty * 5;
  v_reward := v_target.base_reward + v_target.difficulty * 50;
  v_xp := v_target.base_xp + v_target.difficulty * 10;
  v_heat := v_target.difficulty * 2;
  v_power := v_server.power_cost;

  update public.profiles set power = power - v_power where id = auth.uid();

  insert into public.operations (
    player_id, server_id, target_id, op_type,
    status, duration_minutes,
    started_at, completes_at,
    power_used, reward_credits, reward_xp, heat_generated
  ) values (
    auth.uid(), p_server_id, p_target_id, p_op_type,
    'active', v_duration,
    now(), now() + (v_duration || ' minutes')::interval,
    v_power, v_reward, v_xp, v_heat
  ) returning id into v_id;

  return v_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Complete an operation (add rewards, XP, heat)
-- ---------------------------------------------------------------------------
create or replace function public.complete_operation(p_op_id uuid)
returns void
language plpgsql
security definer set search_path = ''
as $$
declare
  v_op record;
  v_success boolean;
  v_roll integer;
begin
  select * into v_op from public.operations where id = p_op_id and status = 'active';
  if v_op is null then raise exception 'Operation not found or not active'; end if;
  if auth.uid() is null or auth.uid() != v_op.player_id then raise exception 'Permission denied'; end if;

  -- Random success based on target security vs server rating
  v_roll := (random() * 100)::integer;

  select security_rating into v_roll
  from public.player_servers ps
  join public.server_types st on st.id = ps.server_type_id
  where ps.id = v_op.server_id;

  v_success := v_roll > (100 - v_op.reward_credits::integer / 3);

  if v_success then
    update public.profiles set
      credits = credits + v_op.reward_credits,
      experience = experience + v_op.reward_xp,
      heat = heat + v_op.heat_generated,
      total_earnings = total_earnings + v_op.reward_credits,
      reputation = reputation + 1
    where id = auth.uid();

    update public.operations set status = 'completed' where id = p_op_id;
  else
    update public.profiles set
      experience = experience + (v_op.reward_xp / 4),
      heat = heat + greatest(v_op.heat_generated - 1, 0)
    where id = auth.uid();

    update public.operations set status = 'failed' where id = p_op_id;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Hire an agent
-- ---------------------------------------------------------------------------
create or replace function public.hire_agent(
  p_name      text,
  p_class     text,
  p_salary    integer default 50,
  p_specialty text default null
)
returns uuid
language plpgsql
security definer set search_path = ''
as $$
declare
  v_id uuid;
  v_credits integer;
  v_hire_cost integer;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;

  v_hire_cost := p_salary * 10;
  select credits into v_credits from public.profiles where id = auth.uid();
  if v_credits < v_hire_cost then raise exception 'Insufficient credits'; end if;

  update public.profiles set credits = credits - v_hire_cost where id = auth.uid();

  insert into public.agents (player_id, agent_name, agent_class, salary_credits, efficiency, specialty)
  values (auth.uid(), p_name, p_class, p_salary, 70, p_specialty)
  returning id into v_id;

  return v_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Start research
-- ---------------------------------------------------------------------------
create or replace function public.start_research(p_research_id uuid)
returns uuid
language plpgsql
security definer set search_path = ''
as $$
declare
  v_res record;
  v_credits integer;
  v_existing record;
  v_id uuid;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;

  select * into v_res from public.research where id = p_research_id;
  if v_res is null then raise exception 'Research not found'; end if;

  -- Check if already researching or completed
  select * into v_existing from public.player_research
  where player_id = auth.uid() and research_id = p_research_id;
  if v_existing is not null then raise exception 'Already started'; end if;

  -- Check prerequisite
  if v_res.required_research_id is not null then
    select * into v_existing from public.player_research
    where player_id = auth.uid() and research_id = v_res.required_research_id and status = 'completed';
    if v_existing is null then raise exception 'Prerequisite not met'; end if;
  end if;

  select credits into v_credits from public.profiles where id = auth.uid();
  if v_credits < v_res.cost_credits then raise exception 'Insufficient credits'; end if;

  update public.profiles set credits = credits - v_res.cost_credits where id = auth.uid();

  insert into public.player_research (player_id, research_id, status, started_at, completes_at)
  values (auth.uid(), p_research_id, 'researching', now(), now() + (v_res.cost_time_hours || ' hours')::interval)
  returning id into v_id;

  return v_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Pay salaries (run periodically)
-- ---------------------------------------------------------------------------
create or replace function public.pay_agent_salaries()
returns void
language plpgsql
security definer set search_path = ''
as $$
begin
  update public.profiles p
  set credits = greatest(0, credits - (
    select coalesce(sum(a.salary_credits), 0)
    from public.agents a
    where a.player_id = p.id and a.is_active = true
  ))
  where id in (
    select distinct player_id from public.agents where is_active = true
  );

  -- Deactivate agents if player has 0 credits and can't pay
  update public.agents
  set is_active = false
  where is_active = true
    and player_id in (
      select id from public.profiles where credits = 0
    );
end;
$$;

-- ---------------------------------------------------------------------------
-- Decay heat over time (run periodically)
-- ---------------------------------------------------------------------------
create or replace function public.decay_heat()
returns void
language plpgsql
security definer set search_path = ''
as $$
begin
  update public.profiles
  set heat = greatest(0, heat - 1)
  where heat > 0;
end;
$$;

-- ---------------------------------------------------------------------------
-- Recharge power (run periodically)
-- ---------------------------------------------------------------------------
create or replace function public.recharge_power()
returns void
language plpgsql
security definer set search_path = ''
as $$
begin
  update public.profiles
  set power = least(power + 5, max_power)
  where power < max_power;
end;
$$;


-- =============================================================================
-- SEED DATA — Fictional corporations and servers
-- =============================================================================

-- Server types
insert into public.server_types (name, server_class, max_bandwidth, power_cost, security_rating, storage_tb, price_credits, emoji, sort_order) values
  ('Raspberry Pi',      'basic',    50,  5,   10,  1,   200,   'R', 1),
  ('Home Desktop',      'basic',   100, 10,   25,  2,   500,   'H', 2),
  ('Workstation',        'advanced', 200, 20,  45,  5,   1500,  'W', 3),
  ('Rack Server',        'advanced', 400, 35,  60,  10,  4000,  'S', 4),
  ('Cloud VPS',          'premium',  600, 50,  75,  20,  8000,  'C', 5),
  ('Mainframe',          'premium',  800, 70,  85,  50,  15000, 'M', 6),
  ('Quantum Node',       'elite',   1000,100,  95, 100, 30000, 'Q', 7),
  ('Neural Core',        'legendary',2000,150, 99, 500, 100000,'N', 8)
on conflict do nothing;

-- Fictional targets
insert into public.targets (name, corp_name, target_class, difficulty, base_reward, base_xp, security_level, region, description) values
  ('NeonBank ATM',                'NeonBank Corp',             'bank',      1,  200,  30,  20, 'Europe',    'Слабозащищённый банкомат сети вымышленного банка НеонБанк'),
  ('NovaTech Internal Wiki',      'NovaTech Industries',        'tech',      1,  150,  25,  15, 'N. America','Открытая вики-система НоваТек'),
  ('GreenGrid Power Control',     'GreenGrid Energy',           'energy',    2,  300,  40,  30, 'Europe',    'Система управления электросетью ГринГрид'),
  ('Oceanus Shipping Database',   'Oceanus Maritime Ltd',      'logistics', 2,  350,  45,  35, 'Asia',      'База данных морских маршрутов вымышленной компании Океанус'),
  ('MegaMart Customer DB',         'MegaMart Global Inc',       'retail',    2,  250,  35,  25, 'Global',    'Клиентская база гипотетического супермаркета МегаМарт'),
  ('CureWell Pharma Research',     'CureWell Pharmaceuticals',   'pharma',    3,  500,  60,  45, 'Europe',    'Сервер исследований вымышленной фармацевтической компании КюрВелл'),
  ('VertexSoft Source Code',       'VertexSoft Technologies',   'tech',      3,  600,  65,  50, 'N. America','Репозиторий исходного кода VertexSoft'),
  ('Atlas Logistics Hub',          'Atlas Global Logistics',    'logistics', 3,  450,  55,  40, 'Asia',      'Центральная логистическая система Атлас'),
  ('BrightMedia Ad Server',        'BrightMedia Corporation',   'media',     2,  300,  40,  30, 'Global',    'Рекламный сервер медиа-корпорации БрайтМедиа'),
  ('TitanBank Mainframe',         'TitanBank International',   'bank',      5,  1500,150,  75, 'Europe',    'Главная бухгалтерская система вымышленного банка ТитанБанк'),
  ('Zenith Cloud Platform',       'Zenith Cloud Services',     'tech',      5,  1200,130,  70, 'N. America','Облачная платформа ЗенитКлауд'),
  ('PhantomNet DNS Root',          'PhantomNet Networks',      'tech',      6,  2000,180,  80, 'Global',    'Корневой DNS-сервер фиктивного провайдера ФантомНет'),
  ('Polaris Defense Satellite',   'Polaris Defense Corp',      'gov',       8,  5000,400,  95, 'Global',    'Спутниковый канал связи вымышленной оборонной корпорации Поларис'),
  ('CypherVault Global Ledger',   'CypherVault Holdings',      'bank',      7,  4000,300,  90, 'Europe',    'Глобальная бухгалтерская книга КайферВолт'),
  ('NovaGen Biotech Lab',         'NovaGen Biotechnologies',    'pharma',    6,  2500,200,  75, 'Asia',      'Сервер лаборатории генной инженерии НоваГен'),
  ('OrbitSpace Station Control',  'OrbitSpace Technologies',   'gov',       9,  8000,600,  98, 'Global',    'Система управления орбитальной станцией ОрбитСпейс'),
  ('DarkNet Nexus Market',        'DarkNet Nexus (fictional)',  'retail',    4,  1000,100,  60, 'Dark Web',  'Маркетплейс даркнета (вымышленный)')
on conflict do nothing;

-- Research tree
insert into public.research (name, category, tier, cost_credits, cost_time_hours, effect_json, description, sort_order) values
  ('Improved Scanning',     'offense',        1, 300,   1, '{"bonus_reward": 10}'::jsonb,  '+10% к награде за операции', 1),
  ('Firewall Basics',       'defense',         1, 200,   1, '{"heat_reduction": 2}'::jsonb,'-2 к теплоте за операцию', 2),
  ('Power Efficiency',      'economy',         1, 400,   2, '{"power_bonus": 20}'::jsonb,  '+20 макс. энергии', 3),
  ('Bandwidth Boost',       'infrastructure',  1, 500,   2, '{"bandwidth_bonus": 50}'::jsonb,'+50 к пропускной способности серверов', 4),
  ('Cloak Protocol',        'stealth',         1, 600,   3, '{"heat_reduction": 5}'::jsonb,'-5 к теплоте за операцию', 5),
  ('Advanced Exploits',     'offense',         2, 1000,  4, '{"bonus_reward": 25}'::jsonb, '+25% к награде', 6),
  ('Intrusion Countermeasures','defense',       2, 800,  4, '{"heat_reduction": 8}'::jsonb,'-8 к теплоте', 7),
  ('Auto-Repair Systems',   'infrastructure',  2, 1200,  5, '{"auto_repair": 5}'::jsonb,  'Автовосстановление серверов +5 HP', 8),
  ('Market Analysis',       'economy',         2, 900,   3, '{"salary_reduction": 10}'::jsonb,'-10% к зарплате агентов', 9),
  ('Ghost Network',         'stealth',         2, 1500,  6, '{"heat_reduction": 12}'::jsonb,'-12 к теплоте', 10),
  ('Neural Hacking',        'offense',         3, 3000,  8, '{"bonus_reward": 50}'::jsonb, '+50% к награде', 11),
  ('Quantum Encryption',    'defense',         3, 2500,  8, '{"heat_reduction": 20}'::jsonb,'-20 к теплоте', 12),
  ('Crypto Mining AI',      'economy',         3, 2000,  6, '{"passive_income": 50}'::jsonb,'Пассивный доход +50 кредитов/цикл', 13),
  ('Distributed Grid',      'infrastructure',  3, 3500, 10, '{"bandwidth_bonus": 200}'::jsonb,'+200 к пропускной способности', 14),
  ('Zero-Day Arsenal',      'offense',         4, 8000, 16, '{"bonus_reward": 100}'::jsonb,'+100% к награде', 15),
  ('Shadow Operative',       'stealth',         4, 7000, 14, '{"heat_reduction": 30}'::jsonb,'-30 к теплоте', 16)
on conflict do nothing;


-- =============================================================================
-- REALTIME
-- =============================================================================

do $$ begin
  alter publication supabase_realtime add table public.operations;
  alter publication supabase_realtime add table public.agents;
  alter publication supabase_realtime add table public.player_servers;
exception when others then null;
end $$;
