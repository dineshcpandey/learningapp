# PROJECT.md — Learning App: Project Knowledge Base

> Single source of truth for anyone (human or AI assistant) picking up this codebase.
> Update this file whenever a significant decision is made or the architecture shifts.
> Cross-reference `DECISIONS.md` for the detailed rationale behind each choice.

---

## 1. What this is

An **endless adaptive quiz app** for CBSE students in classes 5–10 (pilot: Class 8 Maths).
Students pick a class, subject and chapter — or Mixed — and receive a continuous stream of
MCQ questions. Difficulty adapts in real-time. Every wrong answer is tracked to a specific
**misconception**, and the system targets those misconceptions in subsequent questions.

Two product promises that must never be broken:
1. **Never repeat a question** the student has already seen (outside deliberate review).
2. **Track which wrong option** was chosen, not just which topic was failed.

---

## 2. Current build status

| Milestone | Status | Notes |
|-----------|--------|-------|
| **M1 — Foundations** | ✅ Done | Schema, RLS, seed, tooling, CI |
| M2 — Selector + State engine | ⬜ Not started | Waiting for PO go-ahead |
| M3 — Quiz API | ⬜ Not started | All routes prefixed `/api/v1/` |
| M4 — Student client | ⬜ Not started | React Native (Expo) — mobile-first ✅ confirmed |
| M5 — Admin panel + content pipeline | ⬜ Not started | Includes math/LaTeX validation |
| M6 — Analytics + privacy | ⬜ Not started | First-party events table, in-app deletion |

---

## 3. Architecture overview

```
┌─────────────────────────────────────────────────────┐
│  Student client  (M4)   │  Admin panel  (M5)        │
│  React Native / PWA     │  Next.js /admin route     │
└────────────┬────────────┴───────────┬───────────────┘
             │  REST / RPC            │
┌────────────▼────────────────────────▼───────────────┐
│              Quiz API  (M3)  — Next.js route handlers│
│   wires selector (2) + state engine (3) to DB        │
└──────┬───────────────┬──────────────────────────────┘
       │               │
┌──────▼──────┐  ┌─────▼──────────────────────────┐
│  Selector   │  │  Learning State Engine  (M2/3)  │
│  engine     │  │  (pure TS, no DB access)        │
│  (M2, pure) │  └─────────────────────────────────┘
└─────────────┘
             ┌──────────────────────────────────────┐
             │  Supabase (Postgres + Auth + RLS)    │
             │  All schema changes via migrations   │
             └──────────────────────────────────────┘
```

**Key architectural rule:** Components 2 (Selector) and 3 (State engine) are **pure TypeScript functions** — they take data in and return decisions. They have **zero database imports**. The API (component 4) is the only place that touches both the logic and the database.

---

## 4. Repository layout

```
/apps/web                     Next.js app — admin panel only (/admin route group)
/apps/mobile                  React Native (Expo) — student client  [added in M4]
/packages/selector            Question selection + state engine (pure TS, no DB)
/packages/types               Shared types generated from DB schema
/packages/db-tests            RLS integration tests (require Supabase instance)
/supabase/migrations          SQL migrations — source of truth for schema
/supabase/seed                Seed: syllabus, misconceptions, 30 sample questions
/scripts                      Import/validation scripts (M5)
DECISIONS.md                  Running log of all assumptions (D-001 … D-020)
PROJECT.md                    This file — project knowledge base
```

---

## 5. Tech stack

| Layer | Choice | Notes |
|-------|--------|-------|
| **Student client** | **React Native + Expo** (iOS + Android) | D-015 ✅ confirmed |
| **Admin panel** | Next.js 14 (App Router) + TypeScript + Tailwind | Web only, `/apps/web` |
| **Backend** | Supabase: Postgres 16, Auth, RLS | India region (`ap-south-1`) |
| **Selector** | Pure TS module `/packages/selector` | No DB imports; shared by mobile + API |
| **State engine** | Pure TS in `/packages/selector/src/state.ts` | Added in M2 |
| **Math rendering** | LaTeX in DB; KaTeX (web admin), react-native-math-view (mobile) | D-016 ✅ confirmed |
| **Offline storage** | `expo-sqlite` — 2-batch prefetch + attempt queue | D-017 ✅ confirmed |
| **Analytics** | First-party `analytics_events` table (no PostHog) | D-019/D-020 ✅ confirmed |
| **Billing** | RevenueCat (cross-platform in-app purchases) | Parental gate before purchase |
| **OTA updates** | Expo EAS Update | For small fixes without store review |
| **API versioning** | `/api/v1/` prefix + `X-App-Min-Version` header | D-018 ✅ confirmed |
| **Auth** | Email OTP / Phone OTP only — no social logins | Avoids Sign in with Apple requirement |
| **Testing** | Vitest (unit + RLS), Playwright (E2E admin), Expo E2E (M4) | |
| **Tooling** | pnpm 9, ESLint 8, Prettier 3, GitHub Actions | |

---

## 6. Data model — table index

All tables have RLS enabled. All PKs are UUID. Full DDL in `/supabase/migrations/`.

| Table | Purpose |
|-------|---------|
| `subjects` | Syllabus root (e.g. Maths, Science) |
| `chapters` | Per class + subject (class_level 5–10) |
| `topics` | Within a chapter; has `learning_outcome` for stuck-student concept note |
| `topic_prerequisites` | DAG of topic dependencies; used by selector fallback rule 6.5 |
| `misconceptions` | What a wrong option represents; `remediation_note` shown after a hit |
| `question_families` | Groups of variant questions testing the same concept |
| `questions` | MCQ body, difficulty 1–3, status enum, version counter |
| `question_options` | 4 options per question; `is_correct`, `misconception_id`, `is_random_distractor` |
| `profiles` | Extends `auth.users`; stores `role`, `xp`, `streak_days`, `class_level` |
| `sessions` | One per quiz session; `chapter_id` null = Mixed mode |
| `attempts` | Immutable event log of every answer |
| `mastery` | Per (user, chapter): `level` 1–3, `score` 0–100, streak counters |
| `student_misconceptions` | Tracks how often a student hits each misconception; `resolved` flag |
| `review_queue` | Spaced-repetition schedule for previously wrong questions |
| `question_reports` | Student-submitted flags; insert open, read restricted to reviewer/admin |
| `question_stats` | Materialised view: attempts, accuracy, pick-rate per option, median time |

### Key trigger
`question_options_integrity` (deferrable constraint trigger, AFTER INSERT/UPDATE/DELETE):
- Exactly one `is_correct = true` per question
- Every `is_correct = false` option must have `misconception_id` OR `is_random_distractor = true`

### RLS summary
- **Students** — read `live` questions/options; read+write own `attempts`, `mastery`, `sessions`, `student_misconceptions`, `review_queue`, `profiles`; insert `question_reports`
- **Reviewers** — read+edit all questions; can change status up to `approved`; read `question_reports`
- **Admins** — full access; only role that can set `live` or `quarantined`
- **Syllabus tables** — readable by all; writable by admin only

---

## 7. Core interfaces (agreed contracts)

These are fixed before M2 starts. Changes require updating this file and `DECISIONS.md`.

### 7.1 Selector interface
```typescript
// /packages/selector/src/index.ts
selectBatch(input: SelectorInput): SelectorOutput
```
```typescript
interface SelectorInput {
  userId: string;
  chapterId: string | null;       // null = Mixed mode
  currentLevel: 1 | 2 | 3;
  seenQuestionIds: Set<string>;
  dueReviewIds: string[];
  activeMisconceptionIds: string[];
  recentFamilyIds: string[];      // last 5 questions of session
}
interface SelectorOutput {
  questionIds: string[];
  signal?: 'chapter_complete' | 'concept_note';
  conceptNote?: string;           // topic.learning_outcome when stuck
}
```

### 7.2 Learning state interface
```typescript
// /packages/selector/src/state.ts  (M2)
applyAnswer(state: StudentState, attempt: AttemptInput): StateUpdate
```
`StateUpdate` contains: updated `mastery`, updated `student_misconceptions`, optional `review_queue` upsert, XP delta, streak delta.

### 7.3 API contract (shapes, full OpenAPI spec in M3)
| Endpoint | In | Out |
|----------|----|-----|
| `POST /api/session/start` | `{ chapterId: string \| null }` | `{ sessionId, batch, currentLevel }` |
| `GET /api/quiz/next?sessionId=` | — | `{ batch: Question[] }` (options without `is_correct` if `VALIDATE_ON_SERVER=true`) |
| `POST /api/attempts` | `AttemptInput[]` (client-generated IDs) | `{ masteryUpdate, xpDelta }` |
| `POST /api/session/end` | `{ sessionId }` | `SessionSummary` |
| `GET /api/progress` | — | `ChapterProgress[]` |
| `POST /api/reports` | `{ questionId, reason, note }` | `{ ok }` |

### 7.4 Question JSON import format
Updated to include `body_format` (D-016). The `body` and `text` fields use LaTeX when `body_format` is `"latex"`.
```json
{
  "class_level": 8,
  "subject": "Maths",
  "chapter_number": 2,
  "topic": "Solving equations with variables on both sides",
  "family_key": "lin-eq-both-sides-01",
  "difficulty": 2,
  "body_format": "latex",
  "body": "Solve: $3x - 5 = 10$",
  "options": [
    { "key": "A", "text": "$x = 5$",          "is_correct": true },
    { "key": "B", "text": "$x = 15$",         "misconception": "forgot to divide by the coefficient" },
    { "key": "C", "text": "$x = \\frac{5}{3}$","misconception": "subtracted 5 instead of adding 5" },
    { "key": "D", "text": "$x = -5$",         "misconception": "sign error when moving terms" }
  ],
  "explanation": "Add 5 to both sides to get $3x = 15$, then divide by 3 to get $x = 5$.",
  "source": "ai-draft-reviewed"
}
```
Plain-text questions omit `body_format` (defaults to `"plain"`).

---

## 8. Confirmed decisions (post-M1 PO session)

All items below were confirmed by the product owner. Full rationale in `DECISIONS.md`.

| Decision | D-# | Status |
|----------|-----|--------|
| **React Native (Expo)** for student client; `/admin` stays Next.js web | D-015 | ✅ Confirmed |
| **LaTeX** markup in DB; `body_format` column on `questions`; KaTeX (web) + react-native-math-view (mobile) | D-016 | ✅ Confirmed |
| **2-batch prefetch** + `expo-sqlite` local attempt queue; sync never blocks quiz | D-017 | ✅ Confirmed |
| **`/api/v1/`** prefix; `X-App-Min-Version` response header; `APP_MIN_VERSION` env var | D-018 | ✅ Confirmed |
| **First-party `analytics_events` table** (no PostHog); no device-ID collection | D-019/D-020 | ✅ Confirmed |
| **Email/Phone OTP only** — no social logins; avoids Sign in with Apple requirement | D-019 | ✅ Confirmed |
| **In-app delete-my-data** action (not a web form); cascade-deletes all user rows | D-019 | ✅ Confirmed |
| **RevenueCat** for in-app billing; parental gate before any purchase screen | D-019 | ✅ Confirmed |
| **State engine** (`applyAnswer`) lives in `/packages/selector/src/state.ts`, built in M2 | D-015 | ✅ Confirmed |

### Schema migrations still to write (these stem from the above decisions)

| Migration | Contents | Target milestone |
|-----------|----------|-----------------|
| `0007_math_format.sql` | `ALTER TABLE questions ADD COLUMN body_format text NOT NULL DEFAULT 'plain' CHECK (body_format IN ('plain','latex'))` | Before M5 content pipeline |
| `0008_analytics.sql` | `analytics_events` table + RLS | M6 |
| `0009_app_version.sql` | `remote_config` table (key/value store for `APP_MIN_VERSION` and feature flags) | M3 |

---

## 9. Seed data summary

**Pilot content:** Class 8 Maths, CBSE/NCERT-aligned.

| Item | Count |
|------|-------|
| Chapters | 13 (full NCERT 2023 list) |
| Topics (seeded) | 12 across Ch1, 2, 5, 7 |
| Topic prerequisite edges | 5 |
| Misconceptions | 15 |
| Question families | 7 (F01–F07) |
| Questions | 30 (`status = 'live'`) |
| Options | 120 (4 per question) |

Questions cover: Linear Equations (Ch2), Squares & Square Roots (Ch5), Comparing Quantities (Ch7).
Families F01 and F02 have 4 variants each, F03–F06 have 4 variants each — enough to exercise the selector's family-dedup rule.

**Seed UUID convention:**
- `00000000-…-000000000001` = subjects
- `10000000-…-00000000000N` = chapters
- `20000000-…-00000000000N` = topics
- `30000000-…-00000000000N` = misconceptions
- `F0000001-…-00000000000N` = question families
- `Q000000N-…-00000000000M` = questions
- `O000000N-…-00000000000M` = question options

---

## 10. Running the project

### Prerequisites
- Node.js 20+ (Node 22 recommended to silence Supabase JS deprecation warning)
- pnpm 9: `npm install -g pnpm@9`
- Supabase CLI: `brew install supabase/tap/supabase` (for local DB)

### First-time setup
```bash
# Install dependencies
pnpm install --ignore-scripts

# Copy env file
cp .env.example .env.local
# Fill in SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY

# Start local Supabase (Docker required)
supabase start

# Apply migrations + seed
supabase db reset
# or manually:
for f in supabase/migrations/*.sql; do psql "$DATABASE_URL" -f "$f"; done
for f in supabase/seed/*.sql;       do psql "$DATABASE_URL" -f "$f"; done
```

### Development commands
```bash
pnpm lint          # ESLint across all packages
pnpm format        # Prettier --write
pnpm format:check  # Prettier --check (used in CI)
pnpm typecheck     # tsc --noEmit across all packages
pnpm test          # Vitest in all packages
pnpm build         # Build all packages
```

### Running RLS tests (requires local Supabase)
```bash
export SUPABASE_URL=http://127.0.0.1:54321
export SUPABASE_SERVICE_ROLE_KEY=<from: supabase status>
export SUPABASE_ANON_KEY=<from: supabase status>
cd packages/db-tests
pnpm test
```

---

## 11. CI

GitHub Actions (`.github/workflows/ci.yml`) runs on every push and PR to `main`/`develop`:

1. **lint-and-test** job: `pnpm install`, format check, lint, typecheck, test
2. **migration-check** job: spins up Postgres 16 service container, applies all migrations + seed files in order, fails if any SQL error occurs

RLS tests in the `lint-and-test` job are skipped (no Supabase instance); they run locally or in a dedicated staging environment.

---

## 12. Content pipeline (M5 preview)

- Import format: JSON (see §7.4) or CSV
- Validation script at `/scripts/validate-questions`:
  - Missing fields, wrong option count, not exactly 1 correct
  - Incorrect option with no misconception tag and not marked random
  - Near-duplicate body text (pg_trgm similarity, threshold TBD)
  - Explanation length (max ~300 chars)
  - Banned patterns: "all of the above", "none of the above", "which is NOT"
- Import lands questions as `status = 'draft'`; reviewer promotes to `reviewed`; admin sets `live`

---

## 13. Analytics events (M6)

`session_started` · `question_served` · `question_answered` (is_correct, level, time_ms) ·
`level_changed` · `misconception_hit` · `misconception_resolved` · `chapter_complete` ·
`question_reported` · `session_ended` · `streak_extended`

Admin health metrics: repeat rate · misconception resolution rate (14-day window) ·
accuracy on re-asked questions after 1 day · pool depth per chapter/level.

---

## 14. Key non-functionals

| Requirement | Target |
|-------------|--------|
| Quiz batch endpoint p50 | < 300 ms at ~5,000 concurrent users |
| Questions cacheable | Invalidate on quarantine or edit |
| Schema changes | Migrations only — no manual DB edits |
| Secrets | Env vars only; `.env.example` provided |
| Content versioning | Edit increments `questions.version`; attempts keep question ID |
| API versioning | `/api/v1/` from M3 onwards |
| App size (mobile) | Target < 30 MB |
| Minimum supported Android | TBD (suggest Android 8.0 / API 26) |

---

*Last updated: after M1 completion. Next review: before M2 kick-off.*
