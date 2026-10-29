-- Migration: 0005_learning_state.sql
-- Tables that track a student's learning progress. All in the learning schema.

set search_path to learning, public;

-- ── Sessions ──────────────────────────────────────────────────────────────────
create table learning.sessions (
  id         uuid        primary key default gen_random_uuid(),
  user_id    uuid        not null references learning.profiles(id) on delete cascade,
  chapter_id uuid        references learning.chapters(id),
  started_at timestamptz not null default now(),
  ended_at   timestamptz
);

-- ── Attempts ──────────────────────────────────────────────────────────────────
create table learning.attempts (
  id            uuid        primary key default gen_random_uuid(),
  user_id       uuid        not null references learning.profiles(id) on delete cascade,
  question_id   uuid        not null references learning.questions(id),
  session_id    uuid        references learning.sessions(id),
  chosen_option char(1)     not null check (chosen_option in ('A', 'B', 'C', 'D')),
  is_correct    boolean     not null,
  time_ms       int         check (time_ms > 0),
  answered_at   timestamptz not null default now()
);

create index on learning.attempts (user_id, question_id);
create index on learning.attempts (user_id, answered_at);
create index on learning.attempts (question_id);

-- ── Mastery ───────────────────────────────────────────────────────────────────
create table learning.mastery (
  user_id        uuid     not null references learning.profiles(id) on delete cascade,
  chapter_id     uuid     not null references learning.chapters(id),
  level          smallint not null default 1 check (level between 1 and 3),
  score          smallint not null default 0 check (score between 0 and 100),
  correct_streak smallint not null default 0,
  wrong_streak   smallint not null default 0,
  primary key (user_id, chapter_id)
);

-- ── Student misconceptions ────────────────────────────────────────────────────
create table learning.student_misconceptions (
  user_id          uuid        not null references learning.profiles(id) on delete cascade,
  misconception_id uuid        not null references learning.misconceptions(id),
  hit_count        int         not null default 0,
  success_count    int         not null default 0,
  last_hit_at      timestamptz,
  resolved         boolean     not null default false,
  primary key (user_id, misconception_id)
);

-- ── Review queue ──────────────────────────────────────────────────────────────
create table learning.review_queue (
  user_id     uuid        not null references learning.profiles(id) on delete cascade,
  question_id uuid        not null references learning.questions(id),
  due_at      timestamptz not null,
  stage       smallint    not null default 0,
  primary key (user_id, question_id)
);

-- ── Question reports ──────────────────────────────────────────────────────────
create table learning.question_reports (
  id          uuid        primary key default gen_random_uuid(),
  question_id uuid        not null references learning.questions(id),
  user_id     uuid        references learning.profiles(id) on delete set null,
  reason      text        not null check (reason in ('wrong_answer', 'unclear', 'typo', 'other')),
  note        text,
  created_at  timestamptz not null default now(),
  resolved    boolean     not null default false
);

-- ── RLS ───────────────────────────────────────────────────────────────────────
alter table learning.sessions               enable row level security;
alter table learning.attempts               enable row level security;
alter table learning.mastery                enable row level security;
alter table learning.student_misconceptions enable row level security;
alter table learning.review_queue           enable row level security;
alter table learning.question_reports       enable row level security;

-- ── learning.sessions ─────────────────────────────────────────────────────────
create policy "sessions_own_select"
  on learning.sessions for select
  using (auth.uid() = user_id);

create policy "sessions_own_insert"
  on learning.sessions for insert
  with check (auth.uid() = user_id);

create policy "sessions_own_update"
  on learning.sessions for update
  using (auth.uid() = user_id);

create policy "sessions_own_delete"
  on learning.sessions for delete
  using (auth.uid() = user_id);

create policy "sessions_admin_select"
  on learning.sessions for select
  using (learning.current_user_role() = 'admin');

-- ── learning.attempts ─────────────────────────────────────────────────────────
create policy "attempts_own_select"
  on learning.attempts for select
  using (auth.uid() = user_id);

create policy "attempts_own_insert"
  on learning.attempts for insert
  with check (auth.uid() = user_id);

create policy "attempts_admin_select"
  on learning.attempts for select
  using (learning.current_user_role() = 'admin');

-- ── learning.mastery ──────────────────────────────────────────────────────────
create policy "mastery_own_select"
  on learning.mastery for select
  using (auth.uid() = user_id);

create policy "mastery_own_insert"
  on learning.mastery for insert
  with check (auth.uid() = user_id);

create policy "mastery_own_update"
  on learning.mastery for update
  using (auth.uid() = user_id);

create policy "mastery_admin_select"
  on learning.mastery for select
  using (learning.current_user_role() = 'admin');

-- ── learning.student_misconceptions ───────────────────────────────────────────
create policy "sm_own_select"
  on learning.student_misconceptions for select
  using (auth.uid() = user_id);

create policy "sm_own_insert"
  on learning.student_misconceptions for insert
  with check (auth.uid() = user_id);

create policy "sm_own_update"
  on learning.student_misconceptions for update
  using (auth.uid() = user_id);

create policy "sm_admin_select"
  on learning.student_misconceptions for select
  using (learning.current_user_role() = 'admin');

-- ── learning.review_queue ─────────────────────────────────────────────────────
create policy "rq_own_select"
  on learning.review_queue for select
  using (auth.uid() = user_id);

create policy "rq_own_insert"
  on learning.review_queue for insert
  with check (auth.uid() = user_id);

create policy "rq_own_update"
  on learning.review_queue for update
  using (auth.uid() = user_id);

create policy "rq_own_delete"
  on learning.review_queue for delete
  using (auth.uid() = user_id);

create policy "rq_admin_select"
  on learning.review_queue for select
  using (learning.current_user_role() = 'admin');

-- ── learning.question_reports ─────────────────────────────────────────────────
create policy "reports_insert_authenticated"
  on learning.question_reports for insert
  with check (auth.uid() is not null);

create policy "reports_read_reviewer_admin"
  on learning.question_reports for select
  using (learning.current_user_role() in ('reviewer', 'admin'));

create policy "reports_update_admin"
  on learning.question_reports for update
  using (learning.current_user_role() = 'admin');

create policy "reports_delete_admin"
  on learning.question_reports for delete
  using (learning.current_user_role() = 'admin');
