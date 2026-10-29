-- Migration: 0003b_role_helper_and_syllabus_write_rls.sql
-- Runs after 0003_profiles.sql (profiles table exists).
-- Runs before 0004_content.sql (content tables don't exist yet, not referenced here).
--
-- This file does two things:
--
--   1. Defines current_user_role() — a SECURITY DEFINER helper used by every
--      subsequent RLS policy that checks the caller's role. Using SECURITY DEFINER
--      means the sub-select on profiles always runs as the function owner (postgres),
--      so it is never blocked by RLS on profiles and never causes recursion.
--
--   2. Adds the admin write-policies on syllabus tables (subjects, chapters, topics,
--      topic_prerequisites) and the admin read/update policies on profiles.
--      These were deferred from 0002 and 0003 because they all depend on
--      current_user_role() or profiles existing first.
--
-- Why not just inline `select role from profiles where id = auth.uid()` in each policy?
-- Answer: on the profiles table itself that causes infinite recursion (the policy
-- expression calls SELECT on the same table being guarded). Using a SECURITY DEFINER
-- function breaks the recursion because Postgres evaluates the function body under
-- the function owner's privileges, not as an RLS policy expression.

-- ═════════════════════════════════════════════════════════════════════════════
-- 1. Role helper function
-- ═════════════════════════════════════════════════════════════════════════════

create or replace function current_user_role()
returns text
language sql
stable
security definer set search_path = public
as $$
  select role from profiles where id = auth.uid();
$$;

-- Grant execute to authenticated and anon roles so RLS policies can call it.
grant execute on function current_user_role() to authenticated, anon;

-- ═════════════════════════════════════════════════════════════════════════════
-- 2. profiles — admin policies
-- ═════════════════════════════════════════════════════════════════════════════

-- Admin can read all profiles (e.g. for pool depth report, role management).
create policy "profiles_admin_select_all"
  on profiles for select
  using (current_user_role() = 'admin');

-- Admin can update any profile (e.g. to promote a user to reviewer).
create policy "profiles_admin_update_all"
  on profiles for update
  using (current_user_role() = 'admin');

-- ═════════════════════════════════════════════════════════════════════════════
-- 3. Syllabus write policies (subjects, chapters, topics, topic_prerequisites)
-- ═════════════════════════════════════════════════════════════════════════════

-- ── subjects ──────────────────────────────────────────────────────────────────
create policy "syllabus_admin_insert"
  on subjects for insert
  with check (current_user_role() = 'admin');

create policy "syllabus_admin_update"
  on subjects for update
  using (current_user_role() = 'admin');

create policy "syllabus_admin_delete"
  on subjects for delete
  using (current_user_role() = 'admin');

-- ── chapters ──────────────────────────────────────────────────────────────────
create policy "syllabus_admin_insert"
  on chapters for insert
  with check (current_user_role() = 'admin');

create policy "syllabus_admin_update"
  on chapters for update
  using (current_user_role() = 'admin');

create policy "syllabus_admin_delete"
  on chapters for delete
  using (current_user_role() = 'admin');

-- ── topics ────────────────────────────────────────────────────────────────────
create policy "syllabus_admin_insert"
  on topics for insert
  with check (current_user_role() = 'admin');

create policy "syllabus_admin_update"
  on topics for update
  using (current_user_role() = 'admin');

create policy "syllabus_admin_delete"
  on topics for delete
  using (current_user_role() = 'admin');

-- ── topic_prerequisites ───────────────────────────────────────────────────────
create policy "syllabus_admin_insert"
  on topic_prerequisites for insert
  with check (current_user_role() = 'admin');

create policy "syllabus_admin_delete"
  on topic_prerequisites for delete
  using (current_user_role() = 'admin');
