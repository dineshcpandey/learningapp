-- Migration: 0002_syllabus.sql
-- Syllabus structure: subjects, chapters, topics, topic prerequisites.
-- RLS: read policies only (open to all).
-- Write policies are in 0003b_role_helper_and_syllabus_write_rls.sql,
-- which runs after profiles and current_user_role() exist.

-- ── Subjects ──────────────────────────────────────────────────────────────────
create table subjects (
  id   uuid primary key default gen_random_uuid(),
  name text not null unique
);

-- ── Chapters ──────────────────────────────────────────────────────────────────
create table chapters (
  id          uuid     primary key default gen_random_uuid(),
  class_level smallint not null check (class_level between 5 and 10),
  subject_id  uuid     not null references subjects(id),
  number      smallint not null,
  title       text     not null,
  unique (class_level, subject_id, number)
);

-- ── Topics ────────────────────────────────────────────────────────────────────
create table topics (
  id               uuid primary key default gen_random_uuid(),
  chapter_id       uuid not null references chapters(id),
  title            text not null,
  learning_outcome text
);

-- ── Topic prerequisites ───────────────────────────────────────────────────────
create table topic_prerequisites (
  topic_id          uuid not null references topics(id),
  requires_topic_id uuid not null references topics(id),
  primary key (topic_id, requires_topic_id),
  check (topic_id <> requires_topic_id)   -- a topic cannot require itself
);

-- ── RLS — enable on all tables ────────────────────────────────────────────────
alter table subjects            enable row level security;
alter table chapters            enable row level security;
alter table topics              enable row level security;
alter table topic_prerequisites enable row level security;

-- Read policies: syllabus is public (supports guest mode).
create policy "syllabus_read_all" on subjects           for select using (true);
create policy "syllabus_read_all" on chapters           for select using (true);
create policy "syllabus_read_all" on topics             for select using (true);
create policy "syllabus_read_all" on topic_prerequisites for select using (true);

-- Write policies are deferred to 0003b_role_helper_and_syllabus_write_rls.sql
-- because they depend on current_user_role(), which requires profiles to exist.
