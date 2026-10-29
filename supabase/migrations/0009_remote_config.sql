-- Migration: 0009_remote_config.sql
-- Remote config table: key/value store for server-side feature flags.
-- Decision D-018: supports APP_MIN_VERSION check and VALIDATE_ON_SERVER flag.
--
-- This is a lightweight alternative to a full feature-flag service.
-- The API reads this table at startup (cached); values can be updated without
-- a code deploy.

create table remote_config (
  key         text        primary key,
  value       text        not null,
  description text,
  updated_at  timestamptz not null default now()
);

-- Seed initial values.
insert into remote_config (key, value, description) values
  ('APP_MIN_VERSION',     '1.0.0', 'Minimum mobile app version. Older versions receive a 426 Upgrade Required response.'),
  ('VALIDATE_ON_SERVER',  'false', 'When true, is_correct is stripped from quiz batch payloads.'),
  ('GUEST_DAILY_LIMIT',   '20',    'Max questions per day for anonymous/guest users.')
on conflict (key) do nothing;

-- ── RLS ───────────────────────────────────────────────────────────────────────
alter table remote_config enable row level security;

-- Anyone (including anonymous) can read config — needed for the version check.
create policy "remote_config_read_all"
  on remote_config for select
  using (true);

-- Only admins can write config.
create policy "remote_config_write_admin"
  on remote_config for insert
  with check (current_user_role() = 'admin');

create policy "remote_config_update_admin"
  on remote_config for update
  using (current_user_role() = 'admin');

create policy "remote_config_delete_admin"
  on remote_config for delete
  using (current_user_role() = 'admin');
