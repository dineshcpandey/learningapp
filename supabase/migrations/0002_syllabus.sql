-- Migration: 0002_syllabus.sql
-- Syllabus structure: subjects, chapters, topics, topic prerequisites.
-- All tables live in the learning schema.
-- RLS write policies are in 0003b (deferred until profiles + current_user_role exist).

set search_path to learning, public;

-- ── Subjects ──────────────────────────────────────────────────────────────────
create table learning.subjects (
  id   uuid primary key default gen_random_uuid(),
  name text not null unique
);

-- ── Chapters ──────────────────────────────────────────────────────────────────
create table learning.chapters (
  id          uuid     primary key default gen_random_uuid(),
  class_level smallint not null check (class_level between 5 and 10),
  subject_id  uuid     not null references learning.subjects(id),
  number      smallint not null,
  title       text     not null,
  unique (class_level, subject_id, number)
);

-- ── Topics ────────────────────────────────────────────────────────────────────
create table learning.topics (
  id               uuid primary key default gen_random_uuid(),
  chapter_id       uuid not null references learning.chapters(id),
  title            text not null,
  learning_outcome text
);

-- ── Topic prerequisites ───────────────────────────────────────────────────────
create table learning.topic_prerequisites (
  topic_id          uuid not null references learning.topics(id),
  requires_topic_id uuid not null references learning.topics(id),
  primary key (topic_id, requires_topic_id),
  check (topic_id <> requires_topic_id)
);

-- ── RLS ───────────────────────────────────────────────────────────────────────
alter table learning.subjects            enable row level security;
alter table learning.chapters            enable row level security;
alter table learning.topics              enable row level security;
alter table learning.topic_prerequisites enable row level security;

-- Read policies: syllabus is public (supports guest mode).
create policy "syllabus_read_all" on learning.subjects            for select using (true);
create policy "syllabus_read_all" on learning.chapters            for select using (true);
create policy "syllabus_read_all" on learning.topics              for select using (true);
create policy "syllabus_read_all" on learning.topic_prerequisites for select using (true);

-- Write policies deferred to 0003b (depend on learning.current_user_role()).
