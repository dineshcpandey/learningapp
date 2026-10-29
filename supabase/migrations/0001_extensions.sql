-- Migration: 0001_extensions.sql
-- Enable extensions needed by the app.

create extension if not exists "pgcrypto";   -- gen_random_uuid() (built-in on Postgres 13+)
create extension if not exists "pg_trgm";    -- similarity search for near-duplicate question bodies
