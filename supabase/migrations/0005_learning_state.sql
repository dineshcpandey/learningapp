-- Migration: 0005_learning_state.sql
-- Tables that track a student's learning progress:
-- sessions, attempts, mastery, student_misconceptions, review_queue, question_reports.

-- ── Sessions ──────────────────────────────────────────────────────────────────
create table sessions (
  id         uuid        primary key default gen_random_uuid(),
  user_id    uuid        not null references profiles(id) on delete cascade,
  chapter_id uuid        references chapters(id),   -- null = Mixed
  started_at timestamptz not null default now(),
  ended_at   timestamptz
);

-- ── Attempts ──────────────────────────────────────────────────────────────────
create table attempts (
  id            uuid        primary key default gen_random_uuid(),
  user_id       uuid        not null references profiles(id) on delete cascade,
  question_id   uuid        not null references questions(id),
  session_id    uuid        references sessions(id),
  chosen_option char(1)     not null check (chosen_option in ('A', 'B', 'C', 'D')),
  is_correct    boolean     not null,
  time_ms       int         check (time_ms > 0),
  answered_at   timestamptz not null default now()
);

create index on attempts (user_id, question_id);
create index on attempts (user_id, answered_at);
create index on attempts (question_id);

-- ── Mastery ───────────────────────────────────────────────────────────────────
create table mastery (
  user_id        uuid     not null references profiles(id) on delete cascade,
  chapter_id     uuid     not null references chapters(id),
  level          smallint not null default 1 check (level between 1 and 3),
  score          smallint not null default 0 check (score between 0 and 100),
  correct_streak smallint not null default 0,
  wrong_streak   smallint not null default 0,
  primary key (user_id, chapter_id)
);

-- ── Student misconceptions ────────────────────────────────────────────────────
create table student_misconceptions (
  user_id          uuid        not null references profiles(id) on delete cascade,
  misconception_id uuid        not null references misconceptions(id),
  hit_count        int         not null default 0,
  success_count    int         not null default 0,
  last_hit_at      timestamptz,
  resolved         boolean     not null default false,
  primary key (user_id, misconception_id)
);

-- ── Review queue ──────────────────────────────────────────────────────────────
create table review_queue (
  user_id     uuid        not null references profiles(id) on delete cascade,
  question_id uuid        not null references questions(id),
  due_at      timestamptz not null,
  stage       smallint    not null default 0,
  primary key (user_id, question_id)
);

-- ── Question reports ──────────────────────────────────────────────────────────
create table question_reports (
  id          uuid        primary key default gen_random_uuid(),
  question_id uuid        not null references questions(id),
  user_id     uuid        references profiles(id) on delete set null,
  reason      text        not null check (reason in ('wrong_answer', 'unclear', 'typo', 'other')),
  note        text,
  created_at  timestamptz not null default now(),
  resolved    boolean     not null default false
);

-- ── RLS ───────────────────────────────────────────────────────────────────────
alter table sessions              enable row level security;
alter table attempts              enable row level security;
alter table mastery               enable row level security;
alter table student_misconceptions enable row level security;
alter table review_queue          enable row level security;
alter table question_reports      enable row level security;

-- ── sessions ──────────────────────────────────────────────────────────────────
create policy "sessions_own_select"
  on sessions for select
  using (auth.uid() = user_id);

create policy "sessions_own_insert"
  on sessions for insert
  with check (auth.uid() = user_id);

create policy "sessions_own_update"
  on sessions for update
  using (auth.uid() = user_id);

create policy "sessions_own_delete"
  on sessions for delete
  using (auth.uid() = user_id);

-- Admin can read all sessions for analytics.
create policy "sessions_admin_select"
  on sessions for select
  using (current_user_role() = 'admin');

-- ── attempts ──────────────────────────────────────────────────────────────────
create policy "attempts_own_select"
  on attempts for select
  using (auth.uid() = user_id);

create policy "attempts_own_insert"
  on attempts for insert
  with check (auth.uid() = user_id);

-- Students cannot update or delete attempts (immutable history).
-- Admin can read all attempts for analytics.
create policy "attempts_admin_select"
  on attempts for select
  using (current_user_role() = 'admin');

-- ── mastery ───────────────────────────────────────────────────────────────────
create policy "mastery_own_select"
  on mastery for select
  using (auth.uid() = user_id);

create policy "mastery_own_insert"
  on mastery for insert
  with check (auth.uid() = user_id);

create policy "mastery_own_update"
  on mastery for update
  using (auth.uid() = user_id);

create policy "mastery_admin_select"
  on mastery for select
  using (current_user_role() = 'admin');

-- ── student_misconceptions ────────────────────────────────────────────────────
create policy "sm_own_select"
  on student_misconceptions for select
  using (auth.uid() = user_id);

create policy "sm_own_insert"
  on student_misconceptions for insert
  with check (auth.uid() = user_id);

create policy "sm_own_update"
  on student_misconceptions for update
  using (auth.uid() = user_id);

create policy "sm_admin_select"
  on student_misconceptions for select
  using (current_user_role() = 'admin');

-- ── review_queue ──────────────────────────────────────────────────────────────
create policy "rq_own_select"
  on review_queue for select
  using (auth.uid() = user_id);

create policy "rq_own_insert"
  on review_queue for insert
  with check (auth.uid() = user_id);

create policy "rq_own_update"
  on review_queue for update
  using (auth.uid() = user_id);

create policy "rq_own_delete"
  on review_queue for delete
  using (auth.uid() = user_id);

create policy "rq_admin_select"
  on review_queue for select
  using (current_user_role() = 'admin');

-- ── question_reports ──────────────────────────────────────────────────────────
-- Any authenticated user can insert a report.
create policy "reports_insert_authenticated"
  on question_reports for insert
  with check (auth.uid() is not null);

-- Only reviewers and admins can read reports.
create policy "reports_read_reviewer_admin"
  on question_reports for select
  using (current_user_role() in ('reviewer', 'admin'));

-- Admin can update reports (mark resolved).
create policy "reports_update_admin"
  on question_reports for update
  using (current_user_role() = 'admin');

create policy "reports_delete_admin"
  on question_reports for delete
  using (current_user_role() = 'admin');
