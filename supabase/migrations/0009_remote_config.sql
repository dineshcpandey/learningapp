-- Migration: 0009_remote_config.sql
-- Remote config key/value store for feature flags. Lives in the learning schema.

set search_path to learning, public;

create table learning.remote_config (
  key         text        primary key,
  value       text        not null,
  description text,
  updated_at  timestamptz not null default now()
);

insert into learning.remote_config (key, value, description) values
  ('APP_MIN_VERSION',    '1.0.0', 'Minimum mobile app version accepted by the API.'),
  ('VALIDATE_ON_SERVER', 'false', 'When true, is_correct is stripped from quiz batch payloads.'),
  ('GUEST_DAILY_LIMIT',  '20',    'Max questions per day for anonymous/guest users.')
on conflict (key) do nothing;

-- ── RLS ───────────────────────────────────────────────────────────────────────
alter table learning.remote_config enable row level security;

create policy "remote_config_read_all"
  on learning.remote_config for select
  using (true);

create policy "remote_config_write_admin"
  on learning.remote_config for insert
  with check (learning.current_user_role() = 'admin');

create policy "remote_config_update_admin"
  on learning.remote_config for update
  using (learning.current_user_role() = 'admin');

create policy "remote_config_delete_admin"
  on learning.remote_config for delete
  using (learning.current_user_role() = 'admin');
