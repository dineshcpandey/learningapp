-- Migration: 0003_profiles.sql
-- User profiles (extends auth.users, which is owned by the Supabase auth schema
-- and exists automatically — it is never created in application migrations).
-- Note: profiles.id mirrors auth.users.id; the row is created by a trigger on signup.
--
-- RLS: own-row policies only in this file.
-- Admin-level policies (which need current_user_role()) are in 0003b.

create table profiles (
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

-- Automatically create a profile row when a new user signs up via Supabase Auth.
-- Uses SECURITY DEFINER so the trigger runs as the function owner (postgres),
-- not as the calling user, bypassing RLS on profiles during the insert.
create or replace function handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id)
  values (new.id)
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure handle_new_user();

-- ── RLS ───────────────────────────────────────────────────────────────────────
alter table profiles enable row level security;

-- Each user can read and update only their own profile row.
-- Simple direct checks — no sub-select on profiles needed here.
create policy "profiles_select_own"
  on profiles for select
  using (auth.uid() = id);

create policy "profiles_update_own"
  on profiles for update
  using (auth.uid() = id);

-- Admin policies (profiles_admin_select_all, profiles_admin_update_all) are in
-- 0003b_role_helper_and_syllabus_write_rls.sql, which defines current_user_role()
-- using SECURITY DEFINER to avoid infinite recursion on this table.
