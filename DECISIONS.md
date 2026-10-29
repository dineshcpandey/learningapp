# DECISIONS.md

Running log of assumptions and design choices made during development.
Each entry records the decision, the reasoning, and the open alternative.
Product-owner items from Section 16 of the spec are noted where relevant.

---

## M1 — Foundations

### D-001 · Board and pilot subject
**Decision:** CBSE, Class 8 Maths as the seed content, with chapters matching the NCERT 2023 textbook numbering (13 chapters).
**Reason:** Spec Section 16 item 1 says "assumed CBSE, Class 8 Maths".
**Confirm with PO:** If the board is different (e.g. ICSE), chapter titles and numbering will need to change but the schema will not.

---

### D-002 · Seed questions status = 'live'
**Decision:** All 30 seed questions are inserted with `status = 'live'` so that RLS tests, the selector (M2) and the API (M3) work without a separate approval workflow step during development.
**Reason:** Simplest path to a testable M1 that unblocks downstream milestones.
**Trade-off:** In production the import pipeline must land questions as `'draft'` and require reviewer/admin approval. The workflow is enforced by the RLS policies; the seed is an exception.

---

### D-003 · Fixed UUIDs in seed data
**Decision:** All seed rows use hard-coded predictable UUIDs (e.g. `'10000000-0000-0000-0000-000000000001'` for Chapter 1).
**Reason:** Makes the seed idempotent (`ON CONFLICT DO NOTHING`) and makes test assertions reference stable IDs rather than needing a lookup.
**Trade-off:** UUIDs look unusual; cannot be confused with real data in production because the prefix pattern (`10000000-…`, `20000000-…` etc.) is reserved for seed use only.

---

### D-004 · Trigger deferred to statement level
**Decision:** The `question_options_integrity` trigger is a `CONSTRAINT TRIGGER … DEFERRABLE INITIALLY DEFERRED` that fires once per row at statement end, not at row insertion.
**Reason:** Loading 4 options in a single `INSERT … VALUES (…), (…), (…), (…)` statement would otherwise fail mid-batch because the "exactly one correct" check sees an incomplete set after the first row lands. Statement-level deferral lets the whole batch commit before the constraint is evaluated.
**Alternative considered:** A `AFTER STATEMENT` trigger. Postgres constraint triggers must be `FOR EACH ROW`; the deferred approach is the standard workaround.

---

### D-005 · `current_user_role()` security-definer function
**Decision:** A `security definer` helper `current_user_role()` is used in RLS policies to look up the caller's role from `profiles`.
**Reason:** Avoids repeating a `(select role from profiles where id = auth.uid())` sub-select in every policy, and ensures the sub-select always runs as the function owner (not the calling user) so it is not itself blocked by RLS.
**Risk:** If a user's role row is missing (e.g. the `handle_new_user` trigger failed), the function returns `null` and the user is treated as unprivileged. This is the safe failure mode.

---

### D-006 · `question_stats` as a materialized view
**Decision:** `question_stats` is a `MATERIALIZED VIEW` with a `UNIQUE INDEX` on `question_id` (enabling `REFRESH CONCURRENTLY`).
**Reason:** The spec says "refresh on a schedule (hourly is fine) or compute on demand for the admin panel". A materialised view with a refresh function satisfies both options. A plain view would re-scan `attempts` on every admin page load.
**Alternative:** A regular view. Simpler but slower at scale. Can be swapped in by replacing the `CREATE MATERIALIZED VIEW` with `CREATE VIEW` and removing the refresh function.

---

### D-007 · RLS tests skip when env vars are absent
**Decision:** The RLS test suite in `packages/db-tests` skips all tests (via `it.skip`) when `SUPABASE_URL` is not set in the environment.
**Reason:** Allows `pnpm test` to pass in a clean CI environment that does not have a Postgres instance, while the `migration-check` CI job in a Postgres service container validates the SQL. The RLS tests are designed to run against `supabase start` (local instance) or the staging Supabase project.
**CI integration:** The M3 milestone will add a dedicated CI job that spins up a local Supabase instance and runs these tests.

---

### D-008 · `profiles` row created by trigger on `auth.users` insert
**Decision:** A `AFTER INSERT ON auth.users` trigger (`handle_new_user`) auto-creates a `profiles` row.
**Reason:** Supabase Auth manages `auth.users`; application code cannot insert there directly. The trigger ensures every signed-up user has a profile row before any RLS policy referencing `profiles` is evaluated.
**Edge case:** Guest mode (spec Section 2) uses anonymous Supabase Auth (`supabase.auth.signInAnonymously()`), which also fires this trigger, creating a profile with `role = 'student'` by default.

---

### D-009 · Guest mode limits deferred to M3
**Decision:** Guest mode limits (spec Section 16 item 2: "20 questions per day without login") are noted here but not enforced in M1.
**Reason:** M1 scope is schema and seed only. The limit will be enforced in the API layer (M3) as a rate check on the anonymous user's `attempts` count for the current day.

---

### D-010 · Hosting region
**Decision:** Assumed India region (`ap-south-1`) when creating the Supabase project, per spec Section 16 item 3.
**Action required:** Confirm with PO before creating the production Supabase project. The region cannot be changed after creation.

---

### D-011 · Difficulty level labels
**Decision:** Internally stored as `smallint` 1, 2, 3. Display labels are `Basic`, `Standard`, `Challenge` (spec Section 16 item 4). Mapping lives in the client, not the database.
**Reason:** Avoids a DB migration if labels change; the integers are stable API contracts.

---

### D-012 · `topic_prerequisites` self-referential check
**Decision:** Added `CHECK (topic_id <> requires_topic_id)` to `topic_prerequisites` to prevent a topic from being listed as its own prerequisite.
**Reason:** The spec does not mention this constraint but it is a data integrity baseline; cycles in the prerequisite graph are not prevented by a DB constraint (would require a trigger or application-level check). Cycles are a deferred concern for M2 / selector logic.

---

### D-013 · Syllabus seeded for Class 8 only; schema supports classes 5–10
**Decision:** The seed file covers Class 8 Maths only (the pilot). The `class_level` column's `CHECK (class_level BETWEEN 5 AND 10)` and the `subjects` table already support all classes and subjects without schema changes.
**Action:** Add other class/subject seeds when the pilot expands.

---

### D-014 · `question_options` RLS does not strip `is_correct`
**Decision:** The `is_correct` column is readable by students at the database level. The API layer is responsible for omitting it when `VALIDATE_ON_SERVER=true` (spec Section 7).
**Reason:** RLS is coarser than column-level security. Column-level security (`GRANT … (col)`) on the `is_correct` field is possible but adds complexity; the API boundary is the right place to enforce this for MVP.
**Alternative:** Supabase column-level grants. Can be added in a later migration without breaking existing code.

---

## Post-M1 — Product Owner Decisions (confirmed)

### D-015 · Client framework: React Native (Expo), not PWA
**Decision:** The student-facing client (M4) will be built with **React Native + Expo**, targeting both App Store and Google Play. The `/admin` panel stays as a Next.js web app.
**Reason:** PO confirmed mobile-first. Expo gives one TypeScript codebase for both stores, allows sharing `/packages/selector` and `/packages/types` directly, supports OTA updates via Expo EAS for small fixes, and makes offline SQLite support (D-017) first-class.
**Impact on repo:**
- `apps/web` becomes the admin-only Next.js app (route group `/admin` only).
- A new `apps/mobile` Expo app is added in M4 for the student client.
- No changes to `/packages/*`, `/supabase/*`, or the API.
**Confirmed by PO:** Yes.

---

### D-016 · Math notation: LaTeX stored in DB, rendered via KaTeX / react-native-math-view
**Decision:** Question `body`, option `text`, and `explanation` fields store content in **LaTeX** for any mathematical expression (e.g. `\\frac{3x}{5}`). Plain prose questions remain plain text. A new `body_format` column (`'plain'` | `'latex'`) distinguishes them at the row level.
**Schema change:** Migration `0007_math_format.sql` adds `body_format text not null default 'plain' check (body_format in ('plain', 'latex'))` to `questions`. Options and explanations inherit the question's format (no separate column — one format per question).
**Rendering:**
- Web admin: `react-katex` or `katex` directly.
- Mobile student client: `react-native-math-view` (wraps MathJax/KaTeX natively) or `expo-katex` once stable.
**Content pipeline impact:** The validation script (M5) must parse and validate LaTeX in questions where `body_format = 'latex'`. AI-draft prompts must specify LaTeX output.
**Question JSON format change:** Add `"body_format": "plain" | "latex"` field (defaults to `"plain"` if absent).
**Confirmed by PO:** Yes.

---

### D-017 · Offline-first: 2-batch prefetch + local SQLite attempt queue
**Decision:** The mobile client (M4) will prefetch **2 question batches** (not 1) and maintain a **local SQLite attempt queue** using `expo-sqlite`. Attempts sync in the background; the quiz never blocks on the network.
**Reason:** PO confirmed. Indian school networks are patchy; losing a quiz mid-session is a trust-breaking experience. The DB schema is already idempotent-safe (client-generated attempt IDs), so no schema changes are needed.
**Client implementation (M4):**
- Prefetch batch N+1 when the student reaches question 7 of batch N (not 3 — increased for reliability).
- Persist session state after every answered question (app-kill safe).
- Sync queue: exponential backoff, max 3 retries, then local-only mode with a calm status indicator.
- Show sync status uneventfully; never show an error that blocks the quiz.
**API impact (M3):** `POST /api/v1/attempts` already designed as idempotent array accept — no change needed.
**Confirmed by PO:** Yes.

---

### D-018 · API versioning: /api/v1/ from M3
**Decision:** All quiz API route handlers are prefixed `/api/v1/`. A `X-App-Min-Version` response header is sent on every response; the mobile app checks it and shows a gentle "Please update" screen if the installed version is below the minimum.
**Reason:** PO confirmed. Old app versions live on phones for months; `/api/` without a version is painful to migrate later.
**Minimum version config:** Stored in an environment variable `APP_MIN_VERSION` (e.g. `"1.0.0"`). A future remote-config service can override it without a deploy.
**Confirmed by PO:** Yes.

---

### D-019 · Children's privacy: first-party analytics, in-app deletion, email/OTP auth only
**Decision (composite):**
1. **Analytics:** Do not use PostHog or any third-party SDK that collects device identifiers. Use a first-party `analytics_events` table in Supabase instead. A thin `track(event, props)` wrapper is the only analytics call site; swapping the implementation later requires only one file change.
2. **Delete-my-data:** Implemented as an in-app action (not a web form), required by both Google Play and Apple. On confirm: delete all user rows from `attempts`, `mastery`, `sessions`, `student_misconceptions`, `review_queue`, `question_reports`, and `profiles`; then call `supabase.auth.admin.deleteUser()`. A cascade delete on `profiles → auth.users` covers most rows automatically.
3. **Auth:** Email OTP or phone OTP only. No social logins (avoids mandatory "Sign in with Apple"). This sidesteps the need for a parental gate before social login consent.
4. **Parental consent gate:** Show a consent screen before storing anything beyond nickname + class. Write timestamp to `profiles.consent_recorded_at`. Block all data storage until consent is recorded.
5. **No ad SDKs.** Monetise via in-app subscriptions only (RevenueCat for cross-platform billing). Parental gate before any purchase screen.
6. **Store accounts:** Create Google Play Console and App Store Connect developer accounts before M4 starts. Google Play now requires new accounts to run a closed test with at least 12 testers for 14 days before production release — start early.
**Schema impact:** `profiles.consent_recorded_at` already exists (M1). A new `analytics_events` table will be added in migration `0008_analytics.sql` (M6).
**Confirmed by PO:** Yes.

---

### D-020 · Analytics: first-party `analytics_events` table (confirmed by D-019)
**Decision:** Replace PostHog with a lightweight first-party table. Schema (M6 migration):
```sql
create table analytics_events (
  id         uuid        primary key default gen_random_uuid(),
  user_id    uuid        references profiles(id) on delete set null,
  session_id uuid        references sessions(id) on delete set null,
  event_name text        not null,
  props      jsonb       not null default '{}',
  client_ts  timestamptz not null,  -- client-side timestamp
  server_ts  timestamptz not null default now()
);
create index on analytics_events (user_id, server_ts);
create index on analytics_events (event_name, server_ts);
```
RLS: insert allowed for any authenticated user (own `user_id`); read for admin only.
The `props` JSONB column must never contain PII — enforced by code convention and documented in the content pipeline.
**Confirmed by PO:** Yes (implied by D-019).

---

*Last updated: Post-M1 PO decision session.*
