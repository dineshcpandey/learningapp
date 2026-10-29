-- Migration: 0002_syllabus.sql
-- Syllabus structure: subjects, chapters, topics, topic prerequisites.

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

-- ── RLS ───────────────────────────────────────────────────────────────────────
alter table subjects           enable row level security;
alter table chapters           enable row level security;
alter table topics             enable row level security;
alter table topic_prerequisites enable row level security;

-- Syllabus is read-only for all authenticated users (and anon for guest mode).
create policy "syllabus_read_all"
  on subjects for select using (true);

create policy "syllabus_read_all"
  on chapters for select using (true);

create policy "syllabus_read_all"
  on topics for select using (true);

create policy "syllabus_read_all"
  on topic_prerequisites for select using (true);

-- Only admin can modify syllabus.
create policy "syllabus_admin_insert"
  on subjects for insert
  with check (
    exists (select 1 from profiles where id = auth.uid() and role = 'admin')
  );

create policy "syllabus_admin_update"
  on subjects for update
  using (
    exists (select 1 from profiles where id = auth.uid() and role = 'admin')
  );

create policy "syllabus_admin_delete"
  on subjects for delete
  using (
    exists (select 1 from profiles where id = auth.uid() and role = 'admin')
  );

create policy "syllabus_admin_insert"
  on chapters for insert
  with check (
    exists (select 1 from profiles where id = auth.uid() and role = 'admin')
  );

create policy "syllabus_admin_update"
  on chapters for update
  using (
    exists (select 1 from profiles where id = auth.uid() and role = 'admin')
  );

create policy "syllabus_admin_delete"
  on chapters for delete
  using (
    exists (select 1 from profiles where id = auth.uid() and role = 'admin')
  );

create policy "syllabus_admin_insert"
  on topics for insert
  with check (
    exists (select 1 from profiles where id = auth.uid() and role = 'admin')
  );

create policy "syllabus_admin_update"
  on topics for update
  using (
    exists (select 1 from profiles where id = auth.uid() and role = 'admin')
  );

create policy "syllabus_admin_delete"
  on topics for delete
  using (
    exists (select 1 from profiles where id = auth.uid() and role = 'admin')
  );

create policy "syllabus_admin_insert"
  on topic_prerequisites for insert
  with check (
    exists (select 1 from profiles where id = auth.uid() and role = 'admin')
  );

create policy "syllabus_admin_delete"
  on topic_prerequisites for delete
  using (
    exists (select 1 from profiles where id = auth.uid() and role = 'admin')
  );
