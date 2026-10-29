-- Migration: 0001_extensions.sql
-- Enable extensions needed by the app.

create extension if not exists "pgcrypto";   -- gen_random_uuid() (built-in on Postgres 13+)
create extension if not exists "pg_trgm";    -- similarity search for near-duplicate question bodies

-- ── Application schemas ────────────────────────────────────────────────────────
-- learning  : all application tables (syllabus, content, student state)
-- auth      : Supabase auth schema (created by 0000_auth_schema_bootstrap.sql)
create schema if not exists learning;
