-- Migration: 0004_content.sql
-- Content tables: misconceptions, question_families, questions, question_options.
-- All tables in the learning schema.

set search_path to learning, public;

-- ── Misconceptions ────────────────────────────────────────────────────────────
create table learning.misconceptions (
  id               uuid primary key default gen_random_uuid(),
  topic_id         uuid not null references learning.topics(id),
  description      text not null,
  remediation_note text
);

-- ── Question families ─────────────────────────────────────────────────────────
create table learning.question_families (
  id          uuid primary key default gen_random_uuid(),
  topic_id    uuid not null references learning.topics(id),
  description text
);

-- ── Question status enum ──────────────────────────────────────────────────────
create type learning.question_status as enum
  ('draft', 'reviewed', 'approved', 'live', 'quarantined');

-- ── Questions ─────────────────────────────────────────────────────────────────
create table learning.questions (
  id          uuid                    primary key default gen_random_uuid(),
  family_id   uuid                    not null references learning.question_families(id),
  chapter_id  uuid                    not null references learning.chapters(id),
  topic_id    uuid                    not null references learning.topics(id),
  difficulty  smallint                not null check (difficulty between 1 and 3),
  body        text                    not null,
  explanation text                    not null,
  status      learning.question_status not null default 'draft',
  source      text                    not null,
  reviewed_by uuid                    references auth.users(id),
  version     int                     not null default 1,
  created_at  timestamptz             not null default now(),
  updated_at  timestamptz             not null default now()
);

create or replace function learning.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger questions_updated_at
  before update on learning.questions
  for each row execute procedure learning.set_updated_at();

-- ── Question options ──────────────────────────────────────────────────────────
create table learning.question_options (
  id                   uuid     primary key default gen_random_uuid(),
  question_id          uuid     not null references learning.questions(id) on delete cascade,
  option_key           char(1)  not null check (option_key in ('A', 'B', 'C', 'D')),
  text                 text     not null,
  is_correct           boolean  not null default false,
  misconception_id     uuid     references learning.misconceptions(id),
  is_random_distractor boolean  not null default false,
  unique (question_id, option_key)
);

-- ── Option integrity trigger ──────────────────────────────────────────────────
create or replace function learning.check_question_options()
returns trigger
language plpgsql
as $$
declare
  v_question_id    uuid;
  v_correct_count  int;
  v_invalid_count  int;
begin
  if tg_op = 'DELETE' then
    v_question_id := old.question_id;
  else
    v_question_id := new.question_id;
  end if;

  select count(*) into v_correct_count
  from learning.question_options
  where question_id = v_question_id and is_correct = true;

  if v_correct_count <> 1 then
    raise exception
      'Question % must have exactly 1 correct option; found %.',
      v_question_id, v_correct_count
      using errcode = 'check_violation';
  end if;

  select count(*) into v_invalid_count
  from learning.question_options
  where question_id        = v_question_id
    and is_correct         = false
    and misconception_id   is null
    and is_random_distractor = false;

  if v_invalid_count > 0 then
    raise exception
      'Question % has % incorrect option(s) with neither misconception_id nor is_random_distractor.',
      v_question_id, v_invalid_count
      using errcode = 'check_violation';
  end if;

  return null;
end;
$$;

create constraint trigger question_options_integrity
  after insert or update or delete on learning.question_options
  deferrable initially deferred
  for each row execute procedure learning.check_question_options();

-- ── Indexes ───────────────────────────────────────────────────────────────────
create index on learning.questions (chapter_id, difficulty, status);
create index on learning.questions (topic_id);
create index on learning.questions (family_id);
create index on learning.question_options (question_id);

-- ── RLS ───────────────────────────────────────────────────────────────────────
alter table learning.misconceptions    enable row level security;
alter table learning.question_families enable row level security;
alter table learning.questions         enable row level security;
alter table learning.question_options  enable row level security;

-- ── learning.misconceptions ───────────────────────────────────────────────────
create policy "misconceptions_read_all_authenticated"
  on learning.misconceptions for select
  using (auth.uid() is not null);

create policy "misconceptions_write_reviewer_admin"
  on learning.misconceptions for insert
  with check (learning.current_user_role() in ('reviewer', 'admin'));

create policy "misconceptions_update_reviewer_admin"
  on learning.misconceptions for update
  using (learning.current_user_role() in ('reviewer', 'admin'));

create policy "misconceptions_delete_admin"
  on learning.misconceptions for delete
  using (learning.current_user_role() = 'admin');

-- ── learning.question_families ────────────────────────────────────────────────
create policy "families_read_all_authenticated"
  on learning.question_families for select
  using (auth.uid() is not null);

create policy "families_write_reviewer_admin"
  on learning.question_families for insert
  with check (learning.current_user_role() in ('reviewer', 'admin'));

create policy "families_update_reviewer_admin"
  on learning.question_families for update
  using (learning.current_user_role() in ('reviewer', 'admin'));

create policy "families_delete_admin"
  on learning.question_families for delete
  using (learning.current_user_role() = 'admin');

-- ── learning.questions ────────────────────────────────────────────────────────
create policy "questions_student_read_live"
  on learning.questions for select
  using (
    status = 'live'
    or learning.current_user_role() in ('reviewer', 'admin')
  );

create policy "questions_insert_reviewer_admin"
  on learning.questions for insert
  with check (learning.current_user_role() in ('reviewer', 'admin'));

create policy "questions_update_reviewer"
  on learning.questions for update
  using (learning.current_user_role() = 'reviewer')
  with check (status in ('draft', 'reviewed', 'approved'));

create policy "questions_update_admin"
  on learning.questions for update
  using (learning.current_user_role() = 'admin');

create policy "questions_delete_admin"
  on learning.questions for delete
  using (learning.current_user_role() = 'admin');

-- ── learning.question_options ─────────────────────────────────────────────────
create policy "options_student_read_live"
  on learning.question_options for select
  using (
    exists (
      select 1 from learning.questions q
      where q.id = question_options.question_id
        and (q.status = 'live' or learning.current_user_role() in ('reviewer', 'admin'))
    )
  );

create policy "options_insert_reviewer_admin"
  on learning.question_options for insert
  with check (learning.current_user_role() in ('reviewer', 'admin'));

create policy "options_update_reviewer_admin"
  on learning.question_options for update
  using (learning.current_user_role() in ('reviewer', 'admin'));

create policy "options_delete_reviewer_admin"
  on learning.question_options for delete
  using (learning.current_user_role() in ('reviewer', 'admin'));
