-- Migration: 0003_profiles.sql
-- User profiles (must exist before content tables that reference auth.users).
-- Note: profiles.id mirrors auth.users.id; created by a trigger on signup.

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

-- Automatically create a profile row when a new user signs up.
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
create policy "profiles_select_own"
  on profiles for select
  using (auth.uid() = id);

create policy "profiles_update_own"
  on profiles for update
  using (auth.uid() = id);

-- Admin can read all profiles (e.g. for pool depth report).
create policy "profiles_admin_select_all"
  on profiles for select
  using (
    exists (select 1 from profiles where id = auth.uid() and role = 'admin')
  );

-- Admin can update any profile (e.g. to promote a user to reviewer).
create policy "profiles_admin_update_all"
  on profiles for update
  using (
    exists (select 1 from profiles where id = auth.uid() and role = 'admin')
  );
