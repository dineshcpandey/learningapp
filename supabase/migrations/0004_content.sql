-- Migration: 0004_content.sql
-- Content tables: misconceptions, question_families, questions, question_options.
-- Includes the trigger that enforces:
--   (a) exactly one correct option per question
--   (b) every incorrect option has misconception_id set OR is_random_distractor = true

-- ── Misconceptions ────────────────────────────────────────────────────────────
create table misconceptions (
  id               uuid primary key default gen_random_uuid(),
  topic_id         uuid not null references topics(id),
  description      text not null,        -- e.g. "forgot to divide by coefficient"
  remediation_note text                  -- short hint shown after a hit
);

-- ── Question families ─────────────────────────────────────────────────────────
create table question_families (
  id          uuid primary key default gen_random_uuid(),
  topic_id    uuid not null references topics(id),
  description text                       -- shared concept or skill
);

-- ── Question status enum ──────────────────────────────────────────────────────
create type question_status as enum
  ('draft', 'reviewed', 'approved', 'live', 'quarantined');

-- ── Questions ─────────────────────────────────────────────────────────────────
create table questions (
  id          uuid            primary key default gen_random_uuid(),
  family_id   uuid            not null references question_families(id),
  chapter_id  uuid            not null references chapters(id),
  topic_id    uuid            not null references topics(id),
  difficulty  smallint        not null check (difficulty between 1 and 3),
  body        text            not null,
  explanation text            not null,
  status      question_status not null default 'draft',
  source      text            not null,
  reviewed_by uuid            references auth.users(id),
  version     int             not null default 1,
  created_at  timestamptz     not null default now(),
  updated_at  timestamptz     not null default now()
);

-- Auto-update updated_at on every row change.
create or replace function set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger questions_updated_at
  before update on questions
  for each row execute procedure set_updated_at();

-- ── Question options ──────────────────────────────────────────────────────────
create table question_options (
  id                   uuid     primary key default gen_random_uuid(),
  question_id          uuid     not null references questions(id) on delete cascade,
  option_key           char(1)  not null check (option_key in ('A', 'B', 'C', 'D')),
  text                 text     not null,
  is_correct           boolean  not null default false,
  misconception_id     uuid     references misconceptions(id),
  is_random_distractor boolean  not null default false,
  unique (question_id, option_key)
);

-- ── Option integrity trigger ──────────────────────────────────────────────────
-- Fires after any INSERT or UPDATE on question_options.
-- Checks the full option set for the affected question:
--   1. Exactly one option is correct.
--   2. Every incorrect option has misconception_id IS NOT NULL
--      or is_random_distractor = true  (or both).
-- We defer the check to statement level so that loading all 4 options in a
-- single batch does not fail mid-insert.

create or replace function check_question_options()
returns trigger
language plpgsql
as $$
declare
  v_question_id    uuid;
  v_correct_count  int;
  v_invalid_count  int;
begin
  -- Determine which question to validate.
  if tg_op = 'DELETE' then
    v_question_id := old.question_id;
  else
    v_question_id := new.question_id;
  end if;

  -- (a) Exactly one correct option.
  select count(*) into v_correct_count
  from question_options
  where question_id = v_question_id and is_correct = true;

  if v_correct_count <> 1 then
    raise exception
      'Question % must have exactly 1 correct option; found %.',
      v_question_id, v_correct_count
      using errcode = 'check_violation';
  end if;

  -- (b) Every incorrect option must have misconception_id OR is_random_distractor.
  select count(*) into v_invalid_count
  from question_options
  where question_id    = v_question_id
    and is_correct     = false
    and misconception_id is null
    and is_random_distractor = false;

  if v_invalid_count > 0 then
    raise exception
      'Question % has % incorrect option(s) with neither misconception_id nor is_random_distractor.',
      v_question_id, v_invalid_count
      using errcode = 'check_violation';
  end if;

  return null;  -- AFTER trigger; return value is ignored
end;
$$;

-- Statement-level trigger so batch inserts are validated once after all rows land.
create constraint trigger question_options_integrity
  after insert or update or delete on question_options
  deferrable initially deferred
  for each row execute procedure check_question_options();

-- ── Indexes ───────────────────────────────────────────────────────────────────
create index on questions (chapter_id, difficulty, status);
create index on questions (topic_id);
create index on questions (family_id);
create index on question_options (question_id);

-- ── RLS ───────────────────────────────────────────────────────────────────────
alter table misconceptions     enable row level security;
alter table question_families  enable row level security;
alter table questions          enable row level security;
alter table question_options   enable row level security;

-- current_user_role() is defined in 0003b_role_helper_and_syllabus_write_rls.sql
-- (must run before this migration).

-- ── misconceptions ────────────────────────────────────────────────────────────
-- Students can read misconceptions (needed for remediation display).
create policy "misconceptions_read_all_authenticated"
  on misconceptions for select
  using (auth.uid() is not null);

create policy "misconceptions_write_reviewer_admin"
  on misconceptions for insert
  with check (current_user_role() in ('reviewer', 'admin'));

create policy "misconceptions_update_reviewer_admin"
  on misconceptions for update
  using (current_user_role() in ('reviewer', 'admin'));

create policy "misconceptions_delete_admin"
  on misconceptions for delete
  using (current_user_role() = 'admin');

-- ── question_families ─────────────────────────────────────────────────────────
create policy "families_read_all_authenticated"
  on question_families for select
  using (auth.uid() is not null);

create policy "families_write_reviewer_admin"
  on question_families for insert
  with check (current_user_role() in ('reviewer', 'admin'));

create policy "families_update_reviewer_admin"
  on question_families for update
  using (current_user_role() in ('reviewer', 'admin'));

create policy "families_delete_admin"
  on question_families for delete
  using (current_user_role() = 'admin');

-- ── questions ─────────────────────────────────────────────────────────────────
-- Students can only read 'live' questions.
create policy "questions_student_read_live"
  on questions for select
  using (
    status = 'live'
    or current_user_role() in ('reviewer', 'admin')
  );

-- Reviewers and admins can insert questions.
create policy "questions_insert_reviewer_admin"
  on questions for insert
  with check (current_user_role() in ('reviewer', 'admin'));

-- Reviewers can edit questions and change status up to 'approved'.
-- Admins can set any status (live, quarantined).
create policy "questions_update_reviewer"
  on questions for update
  using (current_user_role() = 'reviewer')
  with check (
    status in ('draft', 'reviewed', 'approved')
    -- admin can bypass this policy (see admin policy below)
  );

create policy "questions_update_admin"
  on questions for update
  using (current_user_role() = 'admin');

create policy "questions_delete_admin"
  on questions for delete
  using (current_user_role() = 'admin');

-- ── question_options ──────────────────────────────────────────────────────────
-- Students see options only for live questions; is_correct is NOT filtered here —
-- the API layer omits it when VALIDATE_ON_SERVER=true.
create policy "options_student_read_live"
  on question_options for select
  using (
    exists (
      select 1 from questions q
      where q.id = question_options.question_id
        and (q.status = 'live' or current_user_role() in ('reviewer', 'admin'))
    )
  );

create policy "options_insert_reviewer_admin"
  on question_options for insert
  with check (current_user_role() in ('reviewer', 'admin'));

create policy "options_update_reviewer_admin"
  on question_options for update
  using (current_user_role() in ('reviewer', 'admin'));

create policy "options_delete_reviewer_admin"
  on question_options for delete
  using (current_user_role() in ('reviewer', 'admin'));
