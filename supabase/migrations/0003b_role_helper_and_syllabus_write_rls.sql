-- Migration: 0003b_role_helper_and_syllabus_write_rls.sql
-- Runs after 0003_profiles.sql. Defines learning.current_user_role() and all
-- admin-level RLS policies that depend on it.
--
-- All functions and policies are schema-qualified as learning.*

set search_path to learning, public;

-- ═════════════════════════════════════════════════════════════════════════════
-- 1. Role helper
-- ═════════════════════════════════════════════════════════════════════════════
-- SECURITY DEFINER: runs as the function owner, bypasses RLS on learning.profiles.
-- This is required to avoid infinite recursion when the function is called from
-- a policy on learning.profiles itself.

create or replace function learning.current_user_role()
returns text
language sql
stable
security definer set search_path = learning, public
as $$
  select role from learning.profiles where id = auth.uid();
$$;

grant execute on function learning.current_user_role() to public;

-- ═════════════════════════════════════════════════════════════════════════════
-- 2. learning.profiles — admin policies
-- ═════════════════════════════════════════════════════════════════════════════

create policy "profiles_admin_select_all"
  on learning.profiles for select
  using (learning.current_user_role() = 'admin');

create policy "profiles_admin_update_all"
  on learning.profiles for update
  using (learning.current_user_role() = 'admin');

-- ═════════════════════════════════════════════════════════════════════════════
-- 3. Syllabus write policies
-- ═════════════════════════════════════════════════════════════════════════════

-- ── learning.subjects ─────────────────────────────────────────────────────────
create policy "syllabus_admin_insert"
  on learning.subjects for insert
  with check (learning.current_user_role() = 'admin');

create policy "syllabus_admin_update"
  on learning.subjects for update
  using (learning.current_user_role() = 'admin');

create policy "syllabus_admin_delete"
  on learning.subjects for delete
  using (learning.current_user_role() = 'admin');

-- ── learning.chapters ─────────────────────────────────────────────────────────
create policy "syllabus_admin_insert"
  on learning.chapters for insert
  with check (learning.current_user_role() = 'admin');

create policy "syllabus_admin_update"
  on learning.chapters for update
  using (learning.current_user_role() = 'admin');

create policy "syllabus_admin_delete"
  on learning.chapters for delete
  using (learning.current_user_role() = 'admin');

-- ── learning.topics ───────────────────────────────────────────────────────────
create policy "syllabus_admin_insert"
  on learning.topics for insert
  with check (learning.current_user_role() = 'admin');

create policy "syllabus_admin_update"
  on learning.topics for update
  using (learning.current_user_role() = 'admin');

create policy "syllabus_admin_delete"
  on learning.topics for delete
  using (learning.current_user_role() = 'admin');

-- ── learning.topic_prerequisites ──────────────────────────────────────────────
create policy "syllabus_admin_insert"
  on learning.topic_prerequisites for insert
  with check (learning.current_user_role() = 'admin');

create policy "syllabus_admin_delete"
  on learning.topic_prerequisites for delete
  using (learning.current_user_role() = 'admin');
