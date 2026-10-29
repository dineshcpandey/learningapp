# Learning App: Build Spec for Code Assistant (v1 MVP)

Version 1.0 | Audience: AI code assistant and developer | Scope: MVP for one class and one subject

## 0. How to use this document

You are building the v1 MVP described below. Work milestone by milestone (Section 11). After each milestone, stop, summarise what was built, list any assumptions made, and wait for confirmation before continuing. Do not add features outside Section 2. If something is ambiguous, pick the simplest option, record it in `DECISIONS.md`, and continue.

## 1. Product summary

An endless adaptive quiz for students in classes 5 to 10 (Indian curriculum, CBSE/NCERT-aligned, English first). The student picks a class, subject and chapter (or Mixed) and receives a continuous stream of questions with no fixed end. Difficulty adapts to performance. Every answer gets an instant 1 to 2 line explanation.

The two promises that define the product:

1. **Never show a question the student has already seen**, except deliberate review of past mistakes.
2. **Target what the student actually gets wrong**, by tracking which wrong option (misconception) they chose, not just which topic.

## 2. Scope

### In scope (MVP)

- Pilot content: **Class 8, Maths** (about 10 chapters). The schema must support all classes and subjects.
- MCQ questions only (4 options, exactly 1 correct).
- Guest mode (local progress) and email or phone login via Supabase Auth.
- Endless quiz with adaptive difficulty (3 levels).
- Unseen-question guarantee, misconception remediation, spaced review of wrong answers.
- Instant feedback with explanation.
- XP, daily streak, per-chapter progress and mastery.
- Session summary screen.
- Report-a-question button.
- Admin panel: create, edit, review and approve questions; view flagged questions.
- Basic analytics events.

### Out of scope (do not build)

Leaderboards, friend challenges, badges, parent or teacher dashboards, timed challenge mode, non-MCQ formats, image or diagram questions, regional languages, payments, full offline sync, native mobile apps.

## 3. Tech stack

| Layer | Choice |
| --- | --- |
| Client | Next.js (App Router) + TypeScript + Tailwind CSS, installable PWA |
| Backend | Supabase: Postgres, Auth, Row Level Security, Edge Functions or Next.js route handlers |
| Selector | Pure TypeScript module (`/packages/selector`), unit tested, with a thin database adapter |
| Admin | Separate route group `/admin` in the same Next.js app, role-gated |
| Analytics | PostHog (or a no-op wrapper behind an interface) |
| Testing | Vitest for unit tests, Playwright for one end-to-end quiz flow |
| Tooling | pnpm, ESLint, Prettier, GitHub Actions running lint and tests |

Keep it a single repo and a single deployable. No microservices.

## 4. Repository structure

```
/apps/web                 Next.js app (student client + /admin)
/packages/selector        Question selection logic (pure TS, no DB imports)
/packages/types           Shared types generated from DB schema
/supabase/migrations      SQL migrations (source of truth for schema)
/supabase/seed            Seed data: syllabus map + sample questions
/scripts                  Import and validation scripts
DECISIONS.md              Running log of assumptions
```

## 5. Data model (Postgres)

Use migrations in `/supabase/migrations`. All primary keys are UUID unless stated. Enable RLS on every table.

```sql
-- Syllabus structure
create table subjects (
  id uuid primary key default gen_random_uuid(),
  name text not null unique
);

create table chapters (
  id uuid primary key default gen_random_uuid(),
  class_level smallint not null check (class_level between 5 and 10),
  subject_id uuid not null references subjects(id),
  number smallint not null,
  title text not null,
  unique (class_level, subject_id, number)
);

create table topics (
  id uuid primary key default gen_random_uuid(),
  chapter_id uuid not null references chapters(id),
  title text not null,
  learning_outcome text
);

create table topic_prerequisites (
  topic_id uuid not null references topics(id),
  requires_topic_id uuid not null references topics(id),
  primary key (topic_id, requires_topic_id)
);

-- Misconceptions (what a wrong option represents)
create table misconceptions (
  id uuid primary key default gen_random_uuid(),
  topic_id uuid not null references topics(id),
  description text not null,        -- e.g. forgot to divide by coefficient
  remediation_note text             -- short hint shown after a hit
);

-- Content
create table question_families (
  id uuid primary key default gen_random_uuid(),
  topic_id uuid not null references topics(id),
  description text                  -- the shared concept or skill
);

create type question_status as enum
  ('draft','reviewed','approved','live','quarantined');

create table questions (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references question_families(id),
  chapter_id uuid not null references chapters(id),
  topic_id uuid not null references topics(id),
  difficulty smallint not null check (difficulty between 1 and 3),
  body text not null,
  explanation text not null,
  status question_status not null default 'draft',
  source text not null,             -- e.g. original-writer, ai-draft-reviewed
  reviewed_by uuid references auth.users(id),
  version int not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table question_options (
  id uuid primary key default gen_random_uuid(),
  question_id uuid not null references questions(id) on delete cascade,
  option_key char(1) not null check (option_key in ('A','B','C','D')),
  text text not null,
  is_correct boolean not null default false,
  misconception_id uuid references misconceptions(id),  -- null only if correct or marked random
  is_random_distractor boolean not null default false,
  unique (question_id, option_key)
);
-- Constraint to enforce in a trigger: exactly one correct option per question;
-- every incorrect option has a misconception_id or is_random_distractor = true.

-- Users and learning state
create table profiles (
  id uuid primary key references auth.users(id),
  nickname text,
  class_level smallint check (class_level between 5 and 10),
  parent_contact text,
  consent_recorded_at timestamptz,
  xp int not null default 0,
  streak_days int not null default 0,
  last_active_date date,
  role text not null default 'student' check (role in ('student','reviewer','admin'))
);

create table sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id),
  chapter_id uuid references chapters(id),   -- null means Mixed
  started_at timestamptz not null default now(),
  ended_at timestamptz
);

create table attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id),
  question_id uuid not null references questions(id),
  session_id uuid references sessions(id),
  chosen_option char(1) not null,
  is_correct boolean not null,
  time_ms int,
  answered_at timestamptz not null default now()
);
create index on attempts (user_id, question_id);
create index on attempts (user_id, answered_at);
create index on attempts (question_id);

create table mastery (
  user_id uuid not null references profiles(id),
  chapter_id uuid not null references chapters(id),
  level smallint not null default 1 check (level between 1 and 3),
  score smallint not null default 0 check (score between 0 and 100),
  correct_streak smallint not null default 0,
  wrong_streak smallint not null default 0,
  primary key (user_id, chapter_id)
);

create table student_misconceptions (
  user_id uuid not null references profiles(id),
  misconception_id uuid not null references misconceptions(id),
  hit_count int not null default 0,
  success_count int not null default 0,   -- correct answers on questions testing it
  last_hit_at timestamptz,
  resolved boolean not null default false,
  primary key (user_id, misconception_id)
);

create table review_queue (
  user_id uuid not null references profiles(id),
  question_id uuid not null references questions(id),
  due_at timestamptz not null,
  stage smallint not null default 0,      -- 0: after 5-8 questions, 1: next day
  primary key (user_id, question_id)
);

create table question_reports (
  id uuid primary key default gen_random_uuid(),
  question_id uuid not null references questions(id),
  user_id uuid references profiles(id),
  reason text not null check (reason in ('wrong_answer','unclear','typo','other')),
  note text,
  created_at timestamptz not null default now(),
  resolved boolean not null default false
);
```

Also create a view `question_stats` with, per question: attempts, accuracy, pick-rate per option, median time. Refresh it on a schedule (hourly is fine) or compute on demand for the admin panel.

### RLS rules

- Students can read only `live` questions and their options (never other users' data) and can read and write only their own `attempts`, `mastery`, `sessions`, `student_misconceptions`, `review_queue` and `profiles` rows.
- `reviewer` can read and edit all questions and change status up to `approved`. `admin` can set `live` and `quarantined`.
- `question_reports` insert is allowed for any authenticated user; read is for reviewers and admins.

## 6. The question selector (core engine)

Implement in `/packages/selector` as pure functions that take data in and return question IDs. The database adapter fetches candidates and persists results. Unit test every rule below.

### 6.1 Inputs

- `userId`, `chapterId` (or null for Mixed), current `level` from `mastery`
- Seen set: distinct `question_id` from `attempts` for the user
- Due review items (`review_queue.due_at <= now()`)
- Active misconceptions (`student_misconceptions` where `resolved = false` and `hit_count >= 1`)
- Recently served family IDs (last 5 questions of the session)

### 6.2 Batch composition (batch size 10)

| Slot | Share | Source |
| --- | --- | --- |
| New at current level | about 60% | Unseen live questions in scope at the student's level |
| Misconception remediation | about 25% | Questions whose options include an active misconception's distractor, or questions tagged to that misconception's topic, unseen where possible |
| Spaced review | about 15% | Due `review_queue` items |

Empty slots fall back to new questions.

### 6.3 Rules

1. A question the user has attempted is never served again, except from the review queue or the last-resort fallback (6.4 step 3).
2. Never serve two questions from the same `family_id` back-to-back.
3. Never serve more than 2 remediation questions in a row. After 3 consecutive wrong answers, insert one Level 1 confidence question.
4. If the student has been stuck on the same topic for 8 questions, drop one level and return a short concept note (the topic's `learning_outcome` is acceptable for MVP).
5. If a topic fails repeatedly, check `topic_prerequisites` and serve a question from the prerequisite topic.
6. Shuffle within a batch but respect rules 2 and 3.

### 6.4 Pool exhaustion order

1. Unseen question from a different level in the same chapter.
2. Unseen sibling in the same family (if not already used).
3. Question the student previously got wrong, oldest first.
4. Oldest-seen question.
5. If the chapter is fully mastered, return a `chapter_complete` signal so the UI suggests the next chapter.

### 6.5 Adaptive level rule (v1)

- 3 correct in a row: level + 1 (max 3), reset streak counters.
- 2 wrong in a row: level - 1 (min 1), reset streak counters.
- Chapter `score` (0 to 100): +4 for a correct answer at level 1, +6 at level 2, +8 at level 3; -3 for a wrong answer; clamp to 0 to 100.

### 6.6 Misconception tracking

On each wrong answer, if the chosen option has a `misconception_id`: upsert `student_misconceptions`, increment `hit_count`, set `last_hit_at`, set `resolved = false`. On a correct answer to a question that contains that misconception as a distractor: increment `success_count`. Mark `resolved = true` when `success_count >= 2` since the last hit.

Add the wrong question to `review_queue` (stage 0, due after 5 to 8 more questions in the session). After it is answered correctly at stage 0, reschedule once for the next day (stage 1), then remove it.

## 7. API

All endpoints require auth except guest mode, which uses local storage and a limited anonymous question endpoint.

| Endpoint | Purpose |
| --- | --- |
| `POST /api/session/start` | Body: `chapterId` or null. Returns `sessionId`, first batch, current level |
| `GET /api/quiz/next?sessionId=` | Returns the next batch of 10 questions (options without `is_correct` in the payload when server validation is on) |
| `POST /api/attempts` | Body: array of attempts (`questionId`, `chosenOption`, `timeMs`). Updates mastery, misconceptions, review queue, XP. Idempotent by client-generated attempt ID |
| `POST /api/session/end` | Closes session, returns summary |
| `GET /api/progress` | Per-chapter score, level, accuracy, streak, XP |
| `POST /api/reports` | Report a question |

For MVP practice mode, correct answers and explanations may be sent with the batch so feedback is instant and works on weak networks. Keep a config flag `VALIDATE_ON_SERVER` so this can be flipped later for leaderboards.

## 8. Student client requirements

- Mobile-first, one-handed use, large tap targets, works at 360px width.
- Screens: Onboarding (class, subject, chapter or Mixed) → Quiz → Session summary → Progress home.
- Quiz screen: question, 4 options, submit on tap, then show correct or wrong, the 1 to 2 line explanation, and a Next button. Show a level indicator (Basic, Standard, Challenge), XP earned and current streak.
- Prefetch the next batch when 3 questions remain. Queue attempts locally and sync in the background; retry on failure.
- Encouraging tone only: no lives, no penalties, no public shaming.
- Session summary: questions answered, accuracy, XP, and up to 3 topics to revisit (from active misconceptions).
- PWA: installable manifest, service worker caching app shell and the current batch.
- Accessibility: keyboard navigable, sufficient contrast, no information conveyed by colour alone.

## 9. Admin panel requirements

- Role-gated (`reviewer`, `admin`).
- Question editor: body, 4 options, mark correct one, tag each wrong option with a misconception (or mark random), explanation, topic, family, difficulty, source.
- Status workflow: `draft → reviewed → approved → live`, plus `quarantined`. Only admin can set `live`.
- Review queue view: list of `draft` and `reviewed` questions with filters by chapter, topic and status.
- Flagged view: questions with accuracy below 15%, above 95%, a distractor picked more than the correct answer, a distractor picked by about 0%, or open reports. Quarantine action removes the question from serving immediately.
- Bulk import from CSV or JSON into `draft` using the validation script (Section 10).
- Pool depth report: unseen live questions per chapter and level, with an alert when below 20 per active student.

## 10. Content pipeline and validation

### 10.1 Question JSON format (used for import and AI drafts)

```json
{
  "class_level": 8,
  "subject": "Maths",
  "chapter_number": 2,
  "topic": "Solving equations with variables on both sides",
  "family_key": "lin-eq-both-sides-01",
  "difficulty": 2,
  "body": "Solve: 3x - 5 = 10",
  "options": [
    {"key": "A", "text": "x = 5", "is_correct": true},
    {"key": "B", "text": "x = 15", "misconception": "forgot to divide by the coefficient"},
    {"key": "C", "text": "x = 5/3", "misconception": "subtracted 5 instead of adding 5"},
    {"key": "D", "text": "x = -5", "misconception": "sign error when moving terms"}
  ],
  "explanation": "Add 5 to both sides to get 3x = 15, then divide by 3 to get x = 5.",
  "source": "ai-draft-reviewed"
}
```

### 10.2 Automated validation (`/scripts/validate-questions`)

Reject an item if any of these fail:

- Missing fields, wrong option count, not exactly one correct option, duplicate option text.
- Incorrect option without a misconception tag and not marked random.
- Exact or near-duplicate `body` text (normalised comparison plus a similarity threshold) within the same chapter.
- Explanation empty or longer than about 300 characters.
- Body contains banned patterns: `all of the above`, `none of the above`, and negative phrasing such as `which is NOT` (configurable list).
- For Maths items that include a machine-checkable expression field, recompute the answer and compare it with the marked correct option.

### 10.3 Seed data

Provide in `/supabase/seed`: the Class 8 Maths syllabus map (chapters and topics), 10 to 15 misconceptions, and 30 sample questions in the JSON format above covering at least 3 chapters, at least 2 families with 4 variants each, to exercise the selector.

## 11. Milestones and acceptance criteria

**M1: Foundations.** Repo, tooling, CI, migrations for all tables in Section 5, RLS policies, seed data loads cleanly. *Accept when:* `pnpm test` and lint pass in CI; a fresh database builds from migrations and seed with no errors; RLS tests prove a student cannot read another student's attempts.

**M2: Selector package.** Full Section 6 logic as a pure module with a database adapter. *Accept when:* unit tests cover every rule in 6.3 to 6.6; a simulation test runs 500 synthetic attempts for one user and asserts zero repeats outside the review queue and fallback paths; a second test shows a student who repeatedly picks one misconception receives remediation questions for it within the next two batches.

**M3: API.** Endpoints in Section 7 with auth, idempotent attempt sync, mastery, XP and streak updates. *Accept when:* integration tests cover the full session lifecycle; replaying the same attempt ID does not double count.

**M4: Student client.** Onboarding, quiz, feedback, summary, progress, PWA install, local attempt queue. *Accept when:* a Playwright test completes onboarding and 15 questions; attempts survive going offline mid-quiz and sync on reconnect; Lighthouse PWA and accessibility scores are at least 90.

**M5: Admin panel.** Editor, workflow, flagged view, CSV or JSON import with validation, pool depth report. *Accept when:* a reviewer can take a draft question to `approved`, an admin can make it `live`, and quarantining a question stops it being served on the next request.

**M6: Analytics and pilot readiness.** Event tracking, report-a-question flow, privacy basics, README with setup instructions. *Accept when:* events listed in Section 12 fire correctly; a delete-my-data action removes a user's rows; the app deploys from a clean environment using the README alone.

## 12. Analytics events

`session_started`, `question_served`, `question_answered` (is\_correct, level, time\_ms), `level_changed`, `misconception_hit`, `misconception_resolved`, `chapter_complete`, `question_reported`, `session_ended`, `streak_extended`.

Derived health metrics to expose in the admin panel: repeat rate (target near 0 outside deliberate review), misconception resolution rate within 14 days, accuracy on previously wrong questions when re-asked after a day, pool depth per chapter and level.

## 13. Privacy and compliance requirements

Users are minors. Collect the minimum: nickname, class, parent contact. Record parental consent timestamp before storing anything beyond the nickname and class. Provide a delete-my-data path. No third-party advertising trackers. Do not log personal data in analytics events. Legal review against India's DPDP Act is required before public launch (outside this build).

## 14. Non-functional requirements

- Quiz batch endpoint responds under 300 ms at pilot scale (about 5,000 users).
- Question payloads are cacheable; invalidate when a question is quarantined or edited.
- All schema changes through migrations. No manual database edits.
- Secrets only in environment variables; provide `.env.example`.
- Content versioning: editing a live question increments `version`; attempts keep the question ID so history is preserved.

## 15. Starting prompt for the code assistant

Paste this to begin:

> Read the full spec above. Start with Milestone M1 only. Create the repo structure, tooling, the SQL migrations for every table in Section 5 including the trigger that enforces one correct option per question and misconception-or-random on every wrong option, the RLS policies, and the seed data. Write tests for the RLS rules. When done, summarise what you built, list assumptions in DECISIONS.md, and wait for my go-ahead before starting M2.

## 16. Open decisions to confirm with the product owner

1. Board and pilot subject (assumed CBSE, Class 8 Maths).
2. Guest mode limits (assumed 20 questions per day without login).
3. Hosting region for data (assumed India region if available).
4. Final names for levels shown to students (assumed Basic, Standard, Challenge).
