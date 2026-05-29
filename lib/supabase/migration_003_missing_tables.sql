-- ============================================================================
-- Migration 003: Missing Tables for CyberHack Game (FIXED v2)
-- Creates: campaigns, campaign_progress, player_programs, training_queue,
--          weekly_events, event_participation, daily_rewards,
--          achievements, player_achievements
-- Plus: RLS policies, indexes, seed data, RPC functions
-- Compatible with PostgreSQL 14+ / Supabase
-- All statements are IDEMPOTENT
-- FIX: Removed BEGIN/COMMIT (Supabase SQL Editor runs each statement separately)
-- FIX: All function bodies use public. prefix for table references
-- FIX: Removed SET search_path='' from functions
-- ============================================================================


-- ============================================================================
-- 1. TABLES
-- ============================================================================

-- 1a. campaigns — PvE campaign missions
CREATE TABLE IF NOT EXISTS public.campaigns (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  difficulty int NOT NULL DEFAULT 1 CHECK (difficulty >= 1),
  required_level int NOT NULL DEFAULT 1 CHECK (required_level >= 0),
  enemy_name text NOT NULL DEFAULT '',
  enemy_strength int NOT NULL DEFAULT 100 CHECK (enemy_strength >= 0),
  reward_credits int NOT NULL DEFAULT 0 CHECK (reward_credits >= 0),
  reward_xp int NOT NULL DEFAULT 0 CHECK (reward_xp >= 0),
  reward_item_id uuid REFERENCES public.market_items(id) ON DELETE SET NULL,
  sort_order int NOT NULL DEFAULT 0,
  is_active bool NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- 1b. campaign_progress — player progress per campaign
CREATE TABLE IF NOT EXISTS public.campaign_progress (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  campaign_id uuid NOT NULL REFERENCES public.campaigns(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'available'
    CHECK (status IN ('available', 'in_progress', 'completed', 'failed')),
  attempts int NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  best_damage int NOT NULL DEFAULT 0 CHECK (best_damage >= 0),
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(player_id, campaign_id)
);

-- 1c. player_programs — trainable hacking programs
CREATE TABLE IF NOT EXISTS public.player_programs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  program_type text NOT NULL
    CHECK (program_type IN ('trojan', 'worm', 'ransomware', 'spyware', 'botnet', 'rootkit')),
  quantity int NOT NULL DEFAULT 0 CHECK (quantity >= 0),
  trained_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(player_id, program_type)
);

-- 1d. training_queue — programs being trained
CREATE TABLE IF NOT EXISTS public.training_queue (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  program_type text NOT NULL
    CHECK (program_type IN ('trojan', 'worm', 'ransomware', 'spyware', 'botnet', 'rootkit')),
  quantity int NOT NULL DEFAULT 1 CHECK (quantity >= 1),
  training_cost int NOT NULL DEFAULT 0 CHECK (training_cost >= 0),
  training_time_seconds int NOT NULL DEFAULT 0 CHECK (training_time_seconds >= 0),
  started_at timestamptz NOT NULL DEFAULT now(),
  completes_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'training'
    CHECK (status IN ('training', 'completed', 'cancelled'))
);

-- 1e. weekly_events — weekly event definitions
CREATE TABLE IF NOT EXISTS public.weekly_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  event_type text NOT NULL
    CHECK (event_type IN ('pvp_tournament', 'black_friday', 'clan_raid', 'bug_hunt')),
  start_date timestamptz NOT NULL DEFAULT now(),
  end_date timestamptz NOT NULL DEFAULT now() + interval '7 days',
  is_active bool NOT NULL DEFAULT true,
  reward_credits int NOT NULL DEFAULT 0 CHECK (reward_credits >= 0),
  reward_xp int NOT NULL DEFAULT 0 CHECK (reward_xp >= 0),
  reward_item_id uuid REFERENCES public.market_items(id) ON DELETE SET NULL,
  bonus_modifier jsonb DEFAULT '{}',
  created_at timestamptz NOT NULL DEFAULT now()
);

-- 1f. event_participation — player participation in events
CREATE TABLE IF NOT EXISTS public.event_participation (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  event_id uuid NOT NULL REFERENCES public.weekly_events(id) ON DELETE CASCADE,
  score int NOT NULL DEFAULT 0,
  attempts int NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  best_score int NOT NULL DEFAULT 0,
  has_claimed_reward bool NOT NULL DEFAULT false,
  rank_position int,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(player_id, event_id)
);

-- 1g. daily_rewards — daily reward tracking per player
CREATE TABLE IF NOT EXISTS public.daily_rewards (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  streak_day int NOT NULL DEFAULT 1,
  last_claim_date timestamptz,
  current_streak int NOT NULL DEFAULT 0,
  best_streak int NOT NULL DEFAULT 0,
  total_claimed int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(player_id)
);

-- 1h. achievements — achievement definitions
CREATE TABLE IF NOT EXISTS public.achievements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  key text NOT NULL UNIQUE,
  name text NOT NULL,
  description text,
  icon text,
  category text NOT NULL
    CHECK (category IN ('network', 'combat', 'economy', 'social', 'special')),
  reward_credits int NOT NULL DEFAULT 0 CHECK (reward_credits >= 0),
  reward_xp int NOT NULL DEFAULT 0 CHECK (reward_xp >= 0),
  sort_order int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- 1i. player_achievements — player achievement progress
CREATE TABLE IF NOT EXISTS public.player_achievements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  achievement_id uuid NOT NULL REFERENCES public.achievements(id) ON DELETE CASCADE,
  progress jsonb DEFAULT '{}',
  is_completed bool NOT NULL DEFAULT false,
  is_claimed bool NOT NULL DEFAULT false,
  claimed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(player_id, achievement_id)
);


-- ============================================================================
-- 2. INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_campaigns_sort_order ON public.campaigns(sort_order);
CREATE INDEX IF NOT EXISTS idx_campaigns_is_active ON public.campaigns(is_active);
CREATE INDEX IF NOT EXISTS idx_campaigns_difficulty ON public.campaigns(difficulty);
CREATE INDEX IF NOT EXISTS idx_campaigns_required_level ON public.campaigns(required_level);

CREATE INDEX IF NOT EXISTS idx_campaign_progress_player ON public.campaign_progress(player_id);
CREATE INDEX IF NOT EXISTS idx_campaign_progress_campaign ON public.campaign_progress(campaign_id);
CREATE INDEX IF NOT EXISTS idx_campaign_progress_status ON public.campaign_progress(status);
CREATE INDEX IF NOT EXISTS idx_campaign_progress_player_status ON public.campaign_progress(player_id, status);

CREATE INDEX IF NOT EXISTS idx_player_programs_player ON public.player_programs(player_id);
CREATE INDEX IF NOT EXISTS idx_player_programs_type ON public.player_programs(program_type);
CREATE INDEX IF NOT EXISTS idx_player_programs_player_type ON public.player_programs(player_id, program_type);

CREATE INDEX IF NOT EXISTS idx_training_queue_player ON public.training_queue(player_id);
CREATE INDEX IF NOT EXISTS idx_training_queue_status ON public.training_queue(status);
CREATE INDEX IF NOT EXISTS idx_training_queue_completes ON public.training_queue(completes_at);
CREATE INDEX IF NOT EXISTS idx_training_queue_player_status ON public.training_queue(player_id, status);

CREATE INDEX IF NOT EXISTS idx_weekly_events_type ON public.weekly_events(event_type);
CREATE INDEX IF NOT EXISTS idx_weekly_events_active ON public.weekly_events(is_active);
CREATE INDEX IF NOT EXISTS idx_weekly_events_dates ON public.weekly_events(start_date, end_date);

CREATE INDEX IF NOT EXISTS idx_event_participation_player ON public.event_participation(player_id);
CREATE INDEX IF NOT EXISTS idx_event_participation_event ON public.event_participation(event_id);
CREATE INDEX IF NOT EXISTS idx_event_participation_player_event ON public.event_participation(player_id, event_id);
CREATE INDEX IF NOT EXISTS idx_event_participation_score ON public.event_participation(score DESC);

CREATE INDEX IF NOT EXISTS idx_daily_rewards_player ON public.daily_rewards(player_id);

CREATE INDEX IF NOT EXISTS idx_achievements_category ON public.achievements(category);
CREATE INDEX IF NOT EXISTS idx_achievements_key ON public.achievements(key);
CREATE INDEX IF NOT EXISTS idx_achievements_sort ON public.achievements(sort_order);

CREATE INDEX IF NOT EXISTS idx_player_achievements_player ON public.player_achievements(player_id);
CREATE INDEX IF NOT EXISTS idx_player_achievements_achievement ON public.player_achievements(achievement_id);
CREATE INDEX IF NOT EXISTS idx_player_achievements_completed ON public.player_achievements(is_completed);
CREATE INDEX IF NOT EXISTS idx_player_achievements_player_achievement ON public.player_achievements(player_id, achievement_id);


-- ============================================================================
-- 3. ROW LEVEL SECURITY (RLS)
-- ============================================================================

ALTER TABLE public.campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.campaign_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.player_programs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.training_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.weekly_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_participation ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.player_achievements ENABLE ROW LEVEL SECURITY;

-- campaigns — server-managed, read-only
DO $$ BEGIN CREATE POLICY "campaigns_select_all" ON public.campaigns FOR SELECT USING (true); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "campaigns_no_insert" ON public.campaigns FOR INSERT WITH CHECK (false); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "campaigns_no_update" ON public.campaigns FOR UPDATE USING (false); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "campaigns_no_delete" ON public.campaigns FOR DELETE USING (false); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- campaign_progress — own data
DO $$ BEGIN CREATE POLICY "campaign_progress_select_own" ON public.campaign_progress FOR SELECT USING (auth.uid() = player_id); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "campaign_progress_insert_own" ON public.campaign_progress FOR INSERT WITH CHECK (auth.uid() = player_id); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "campaign_progress_update_own" ON public.campaign_progress FOR UPDATE USING (auth.uid() = player_id); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "campaign_progress_delete_own" ON public.campaign_progress FOR DELETE USING (auth.uid() = player_id); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- player_programs — own data
DO $$ BEGIN CREATE POLICY "player_programs_select_own" ON public.player_programs FOR SELECT USING (auth.uid() = player_id); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "player_programs_insert_own" ON public.player_programs FOR INSERT WITH CHECK (auth.uid() = player_id); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "player_programs_update_own" ON public.player_programs FOR UPDATE USING (auth.uid() = player_id); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "player_programs_delete_own" ON public.player_programs FOR DELETE USING (auth.uid() = player_id); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- training_queue — own data
DO $$ BEGIN CREATE POLICY "training_queue_select_own" ON public.training_queue FOR SELECT USING (auth.uid() = player_id); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "training_queue_insert_own" ON public.training_queue FOR INSERT WITH CHECK (auth.uid() = player_id); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "training_queue_update_own" ON public.training_queue FOR UPDATE USING (auth.uid() = player_id); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "training_queue_delete_own" ON public.training_queue FOR DELETE USING (auth.uid() = player_id); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- weekly_events — server-managed, read-only
DO $$ BEGIN CREATE POLICY "weekly_events_select_all" ON public.weekly_events FOR SELECT USING (true); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "weekly_events_no_insert" ON public.weekly_events FOR INSERT WITH CHECK (false); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "weekly_events_no_update" ON public.weekly_events FOR UPDATE USING (false); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "weekly_events_no_delete" ON public.weekly_events FOR DELETE USING (false); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- event_participation — own data
DO $$ BEGIN CREATE POLICY "event_participation_select_own" ON public.event_participation FOR SELECT USING (auth.uid() = player_id); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "event_participation_insert_own" ON public.event_participation FOR INSERT WITH CHECK (auth.uid() = player_id); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "event_participation_update_own" ON public.event_participation FOR UPDATE USING (auth.uid() = player_id); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "event_participation_delete_own" ON public.event_participation FOR DELETE USING (auth.uid() = player_id); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- daily_rewards — own data
DO $$ BEGIN CREATE POLICY "daily_rewards_select_own" ON public.daily_rewards FOR SELECT USING (auth.uid() = player_id); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "daily_rewards_insert_own" ON public.daily_rewards FOR INSERT WITH CHECK (auth.uid() = player_id); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "daily_rewards_update_own" ON public.daily_rewards FOR UPDATE USING (auth.uid() = player_id); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "daily_rewards_delete_own" ON public.daily_rewards FOR DELETE USING (auth.uid() = player_id); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- achievements — server-managed, read-only
DO $$ BEGIN CREATE POLICY "achievements_select_all" ON public.achievements FOR SELECT USING (true); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "achievements_no_insert" ON public.achievements FOR INSERT WITH CHECK (false); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "achievements_no_update" ON public.achievements FOR UPDATE USING (false); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "achievements_no_delete" ON public.achievements FOR DELETE USING (false); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- player_achievements — own data
DO $$ BEGIN CREATE POLICY "player_achievements_select_own" ON public.player_achievements FOR SELECT USING (auth.uid() = player_id); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "player_achievements_insert_own" ON public.player_achievements FOR INSERT WITH CHECK (auth.uid() = player_id); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "player_achievements_update_own" ON public.player_achievements FOR UPDATE USING (auth.uid() = player_id); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "player_achievements_delete_own" ON public.player_achievements FOR DELETE USING (auth.uid() = player_id); EXCEPTION WHEN duplicate_object THEN NULL; END $$;


-- ============================================================================
-- 4. SEED DATA
-- ============================================================================

-- 4a. Campaign missions (10)
INSERT INTO public.campaigns (id, name, description, difficulty, required_level, enemy_name, enemy_strength, reward_credits, reward_xp, sort_order, is_active)
VALUES
  ('a1b2c3d4-0001-4000-8000-000000000001', 'Первый взлом', 'Ваша первая миссия — взломать простой тестовый сервер.', 1, 1, 'Тестовый бот', 30, 200, 50, 1, true),
  ('a1b2c3d4-0002-4000-8000-000000000002', 'Корпоративная сеть', 'Проникните в корпоративную сеть и получите доступ к файлам.', 2, 3, 'Файрвол корпорации', 60, 500, 100, 2, true),
  ('a1b2c3d4-0003-4000-8000-000000000003', 'Финансовый сектор', 'Взломайте банковский сервер и перехватите транзакции.', 3, 5, 'Безопасность банка', 120, 1000, 200, 3, true),
  ('a1b2c3d4-0004-4000-8000-000000000004', 'Государственные серверы', 'Получите доступ к правительственным базам данных.', 4, 7, 'Гос. кибервойска', 200, 2000, 400, 4, true),
  ('a1b2c3d4-0005-4000-8000-000000000005', 'Тёмная сеть', 'Найдите скрытый сервер в даркнете.', 5, 10, 'Теневой хакер', 300, 5000, 600, 5, true),
  ('a1b2c3d4-0006-4000-8000-000000000006', 'Военная база', 'Взломайте систему управления военной базой.', 6, 13, 'Военный ИИ', 400, 8000, 800, 6, true),
  ('a1b2c3d4-0007-4000-8000-000000000007', 'Квантовый центр', 'Проникните в квантовый вычислительный центр.', 7, 16, 'Квантовый щит', 550, 15000, 1200, 7, true),
  ('a1b2c3d4-0008-4000-8000-000000000008', 'Спутниковая сеть', 'Перехватите управление спутниковой связью.', 8, 19, 'Спутниковый ИИ', 700, 25000, 1800, 8, true),
  ('a1b2c3d4-0009-4000-8000-000000000009', 'Подводный кабель', 'Доступ к трансокеанскому кабелю связи.', 9, 22, 'Глубоководный сервер', 850, 40000, 2400, 9, true),
  ('a1b2c3d4-0010-4000-8000-000000000010', 'Главный сервер', 'Финальная миссия — взлом главного сервера.', 10, 25, 'Главный ИИ', 1000, 50000, 3000, 10, true)
ON CONFLICT DO NOTHING;

-- 4b. Weekly events (4 types)
INSERT INTO public.weekly_events (id, name, description, event_type, start_date, end_date, is_active, reward_credits, reward_xp, bonus_modifier)
VALUES
  ('b2c3d4e5-0001-4000-8000-000000000001', 'Турнир хакеров', 'Соревнуйтесь с другими хакерами в PvP турнире.', 'pvp_tournament', now(), now() + interval '7 days', true, 5000, 500, '{}'),
  ('b2c3d4e5-0002-4000-8000-000000000002', 'Чёрная пятница', 'Скидки на товары в магазине.', 'black_friday', now(), now() + interval '7 days', true, 3000, 300, '{"discount_percent": 30}'),
  ('b2c3d4e5-0003-4000-8000-000000000003', 'Клановый рейд', 'Совместный клановый рейд на мощный сервер.', 'clan_raid', now(), now() + interval '7 days', true, 8000, 800, '{}'),
  ('b2c3d4e5-0004-4000-8000-000000000004', 'Охота на баги', 'Найдите и эксплуатируйте баги в системе.', 'bug_hunt', now(), now() + interval '7 days', true, 4000, 400, '{}')
ON CONFLICT DO NOTHING;

-- 4c. Achievements (10)
INSERT INTO public.achievements (id, key, name, description, icon, category, reward_credits, reward_xp, sort_order)
VALUES
  ('c3d4e5f6-0001-4000-8000-000000000001', 'first_node',     'Первый узел',      'Разверните первый сетевой узел',       'antenna', 'network', 200,   40,   1),
  ('c3d4e5f6-0002-4000-8000-000000000002', 'network_builder', 'Строитель сети',    'Разверните 10 узлов',                   'globe',   'network', 1000,  200,  2),
  ('c3d4e5f6-0003-4000-8000-000000000003', 'first_attack',    'Первый взлом',      'Проведите первую атаку',               'swords',  'combat',  300,   50,   3),
  ('c3d4e5f6-0004-4000-8000-000000000004', 'cyber_warrior',   'Кибервоин',         'Проведите 100 атак',                   'shield',  'combat',  5000,  1000, 4),
  ('c3d4e5f6-0005-4000-8000-000000000005', 'wealthy_hacker',  'Богатый хакер',     'Накопите 100,000 кредитов',            'coins',   'economy', 3000,  500,  5),
  ('c3d4e5f6-0006-4000-8000-000000000006', 'market_shark',    'Акула рынка',       'Купите 20 товаров',                    'cart',    'economy', 2000,  400,  6),
  ('c3d4e5f6-0007-4000-8000-000000000007', 'clan_founder',    'Основатель',        'Создайте клан',                        'crown',   'social',  5000,  500,  7),
  ('c3d4e5f6-0008-4000-8000-000000000008', 'clan_leader',     'Лидер клана',       'Достигните 10 уровня клана',           'trophy',  'social',  8000,  800,  8),
  ('c3d4e5f6-0009-4000-8000-000000000009', 'high_level',      'Ветеран',           'Достигните 25 уровня',                 'star',    'special', 10000, 2000, 9),
  ('c3d4e5f6-0010-4000-8000-000000000010', 'legend',          'Легенда',           'Достигните 50 уровня',                 'trophy',  'special', 50000, 5000, 10)
ON CONFLICT DO NOTHING;


-- ============================================================================
-- 5. RPC FUNCTIONS (after all tables are created!)
-- ============================================================================

-- 5a. get_active_events() — returns active weekly events
CREATE OR REPLACE FUNCTION public.get_active_events()
RETURNS SETOF public.weekly_events
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
  SELECT * FROM public.weekly_events
  WHERE is_active = true AND end_date > now()
  ORDER BY start_date;
$$;

-- 5b. claim_daily_reward(p_player_id uuid) — FIXED: uses public. prefix, no SET search_path
CREATE OR REPLACE FUNCTION public.claim_daily_reward(p_player_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_reward record;
  v_tier_credits int;
  v_tier_xp int;
  v_tier_day int;
  v_streak_broken boolean;
BEGIN
  -- Get current state from public.daily_rewards
  SELECT * INTO v_reward FROM public.daily_rewards WHERE player_id = p_player_id;

  -- Determine tier based on day of week (1=Mon, 7=Sun)
  v_tier_day := (EXTRACT(ISODOW FROM now())::int);

  IF v_reward IS NULL THEN
    v_streak_broken := false;
    INSERT INTO public.daily_rewards (player_id, streak_day, current_streak, best_streak, total_claimed)
    VALUES (p_player_id, v_tier_day, 1, 1, 1) RETURNING * INTO v_reward;
  ELSE
    -- Check if streak is broken (last claim was not today or yesterday)
    IF v_reward.last_claim_date IS NULL OR
       v_reward.last_claim_date < date_trunc('day', now()) - interval '1 day' THEN
      IF v_reward.last_claim_date < date_trunc('day', now()) - interval '1 day' THEN
        v_streak_broken := true;
      END IF;
      UPDATE public.daily_rewards SET current_streak = 0 WHERE player_id = p_player_id;
      v_reward.current_streak := 0;
    END IF;

    -- Check if already claimed today
    IF v_reward.last_claim_date >= date_trunc('day', now()) THEN
      RETURN jsonb_build_object('success', false, 'message', 'Награда уже получена сегодня');
    END IF;

    v_reward.current_streak := v_reward.current_streak + 1;
    v_reward.best_streak := GREATEST(v_reward.best_streak, v_reward.current_streak);
    v_reward.total_claimed := v_reward.total_claimed + 1;
    v_reward.streak_day := v_tier_day;
    v_reward.last_claim_date := now();

    UPDATE public.daily_rewards SET
      streak_day = v_reward.streak_day,
      last_claim_date = v_reward.last_claim_date,
      current_streak = v_reward.current_streak,
      best_streak = v_reward.best_streak,
      total_claimed = v_reward.total_claimed,
      updated_at = now()
    WHERE player_id = p_player_id;
  END IF;

  -- Calculate rewards based on streak
  v_tier_credits := CASE v_reward.current_streak
    WHEN 1 THEN 100 WHEN 2 THEN 200 WHEN 3 THEN 300
    WHEN 4 THEN 500 WHEN 5 THEN 800 WHEN 6 THEN 1200
    ELSE 2000 END;
  v_tier_xp := CASE v_reward.current_streak
    WHEN 1 THEN 10 WHEN 2 THEN 20 WHEN 3 THEN 30
    WHEN 4 THEN 50 WHEN 5 THEN 80 WHEN 6 THEN 120
    ELSE 250 END;

  -- Award resources to public.profiles
  UPDATE public.profiles SET credits = credits + v_tier_credits, experience = experience + v_tier_xp WHERE id = p_player_id;

  RETURN jsonb_build_object(
    'success', true,
    'streak', v_reward.current_streak,
    'best_streak', v_reward.best_streak,
    'credits', v_tier_credits,
    'xp', v_tier_xp,
    'streak_broken', COALESCE(v_streak_broken, false)
  );
END;
$$;

-- 5c. join_event(p_player_id uuid, p_event_id uuid) — FIXED: uses public. prefix, no SET search_path
CREATE OR REPLACE FUNCTION public.join_event(p_player_id uuid, p_event_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO public.event_participation (player_id, event_id)
  VALUES (p_player_id, p_event_id)
  ON CONFLICT (player_id, event_id) DO NOTHING;
END;
$$;


-- ============================================================================
-- 6. REALTIME SUBSCRIPTIONS
-- ============================================================================

DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.campaigns; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.weekly_events; EXCEPTION WHEN OTHERS THEN NULL; END $$;
