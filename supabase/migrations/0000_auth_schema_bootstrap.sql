-- Migration: 0000_auth_schema_bootstrap.sql
-- Creates stub auth schema objects so migrations can run against bare Postgres
-- (local dev, CI containers) as well as against a real Supabase project.
--
-- ON SUPABASE: the auth schema, auth.users table, and auth.uid() function all
-- exist already. Every statement here uses IF NOT EXISTS / OR REPLACE guards,
-- so this migration is a safe no-op on a live Supabase project.
--
-- ON BARE POSTGRES (local psql, GitHub Actions postgres service container):
-- Supabase's auth schema is absent. This migration creates minimal stubs so
-- that 0003_profiles.sql and later migrations can reference auth.users and
-- auth.uid() without errors.
--
-- The stub auth.users table contains only the columns our migrations reference.
-- The stub auth.uid() function returns NULL (no real session exists in bare
-- Postgres), which means all RLS policies evaluate to false for unauthenticated
-- queries — the correct secure default.

-- ── auth schema ───────────────────────────────────────────────────────────────
create schema if not exists auth;

-- ── auth.users stub ───────────────────────────────────────────────────────────
-- Only created if it doesn't exist; on Supabase the real table is already here.
create table if not exists auth.users (
  id            uuid        primary key default gen_random_uuid(),
  email         text        unique,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- ── auth.uid() stub ───────────────────────────────────────────────────────────
-- On Supabase, auth.uid() reads the JWT claim 'sub' from the request context.
-- On bare Postgres there is no request context, so we return NULL.
-- NULL is the safe default: all `auth.uid() = user_id` RLS checks become false,
-- meaning no rows are returned for an unauthenticated connection.
create or replace function auth.uid()
returns uuid
language sql
stable
as $$
  select null::uuid;
$$;

-- ── auth.role() stub ──────────────────────────────────────────────────────────
-- Used by some Supabase helper policies. Returns 'anon' on bare Postgres.
create or replace function auth.role()
returns text
language sql
stable
as $$
  select 'anon'::text;
$$;

-- ── auth.jwt() stub ───────────────────────────────────────────────────────────
-- Returns an empty JSONB on bare Postgres.
create or replace function auth.jwt()
returns jsonb
language sql
stable
as $$
  select '{}'::jsonb;
$$;
