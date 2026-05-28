-- =============================================================================
-- CyberHack — Migration: Add missing columns to player_stats
-- =============================================================================

-- Add clan_score column (sum of clan members' stats)
alter table public.player_stats
  add column if not exists clan_score integer not null default 0 check (clan_score >= 0);

-- Add total_damage column
alter table public.player_stats
  add column if not exists total_damage integer not null default 0 check (total_damage >= 0);

-- Update leaderboard indexes
create index if not exists idx_stats_clan_score on public.player_stats (clan_score desc);
create index if not exists idx_stats_total_damage on public.player_stats (total_damage desc);

-- Enable Realtime for chat_messages (required for live chat)
alter publication supabase_realtime add table public.chat_messages;
