-- Migration 002: Add missing columns and types
-- Run this migration on existing databases to fix leaderboard and network nodes.

-- Add missing columns to player_stats
ALTER TABLE public.player_stats
  ADD COLUMN IF NOT EXISTS total_damage integer NOT NULL DEFAULT 0 CHECK (total_damage >= 0);
ALTER TABLE public.player_stats
  ADD COLUMN IF NOT EXISTS clan_score integer NOT NULL DEFAULT 0 CHECK (clan_score >= 0);

-- Update network_nodes type check to include scanner and terminal
ALTER TABLE public.network_nodes
  DROP CONSTRAINT IF EXISTS network_nodes_node_type_check;
ALTER TABLE public.network_nodes
  ADD CONSTRAINT network_nodes_node_type_check
  CHECK (node_type IN (
    'server', 'firewall', 'router',
    'database', 'mining_rig', 'proxy',
    'scanner', 'terminal'
  ));
