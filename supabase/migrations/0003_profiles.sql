-- Migration: 0003_profiles.sql
-- profiles lives in the learning schema; it references auth.users (auth schema).
-- RLS own-row policies only here. Admin policies are in 0003b.

set search_path to learning, public;

create table learning.profiles (
  id                   uuid      primary key references auth.users(id) on delete cascade,
  nickname             text,
  class_level          smallint  check (class_level between 5 and 10),
  parent_contact       text,
  consent_recorded_at  timestamptz,
  xp                   int       not null default 0,
  streak_days          int       not null default 0,
  last_active_date     date,
  role                 text      not null default 'student'
                                 check (role in ('student', 'reviewer', 'admin'))
);

-- Trigger: auto-create a profile row when a new user signs up via Supabase Auth.
-- SECURITY DEFINER so the insert bypasses RLS on learning.profiles.
create or replace function learning.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = learning, public
as $$
begin
  insert into learning.profiles (id)
  values (new.id)
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure learning.handle_new_user();

-- ── RLS ───────────────────────────────────────────────────────────────────────
alter table learning.profiles enable row level security;

-- Own-row policies: simple direct equality, no sub-select on profiles needed.
create policy "profiles_select_own"
  on learning.profiles for select
  using (auth.uid() = id);

create policy "profiles_update_own"
  on learning.profiles for update
  using (auth.uid() = id);

-- Admin policies are in 0003b (use learning.current_user_role() to avoid
-- infinite recursion when querying this table from within its own policy).
