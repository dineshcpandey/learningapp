/**
 * RLS tests for the Learning App database.
 *
 * Each describe block maps to a table (or a group of tables) and tests the
 * policies defined in the migrations.
 *
 * How to run:
 *   1. Start a local Supabase instance: `supabase start`
 *   2. Apply migrations: `supabase db reset`
 *   3. Set env vars (or use the defaults for local dev):
 *        SUPABASE_URL=http://127.0.0.1:54321
 *        SUPABASE_SERVICE_ROLE_KEY=<local service key from supabase status>
 *        SUPABASE_ANON_KEY=<local anon key>
 *   4. pnpm test  (from packages/db-tests)
 *
 * Note: These are integration tests that require a running Postgres instance.
 * They are skipped automatically (via `skipIfNoEnv`) when env vars are absent,
 * which allows `pnpm test` in CI without a database to still pass lint/type checks.
 */

import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import {
  serviceClient,
  makeStudentClient,
  makeStudent2Client,
  makeReviewerClient,
  makeAdminClient,
  DB_CONFIGURED,
} from './helpers/clients.js';
import { createTestUsers, deleteTestUsers, type TestUsers } from './helpers/fixtures.js';
import type { SupabaseClient } from '@supabase/supabase-js';

// ── Skip guard ────────────────────────────────────────────────────────────────
// If SUPABASE_URL is not configured, skip all tests gracefully.
const SKIP = !DB_CONFIGURED;
const maybeIt = SKIP ? it.skip : it;
const maybeDescribe = SKIP ? describe.skip : describe;

// Seed UUIDs (from 003_questions.sql / 001_syllabus.sql)
const LIVE_QUESTION_ID = 'Q0000001-0000-0000-0000-000000000001';
const CHAPTER_ID = '10000000-0000-0000-0000-000000000002';

// ── Test state ────────────────────────────────────────────────────────────────
let users: TestUsers;
let student1: SupabaseClient;
let student2: SupabaseClient;
let reviewer: SupabaseClient;
let admin: SupabaseClient;

beforeAll(async () => {
  if (SKIP) return;
  users = await createTestUsers();
  [student1, student2, reviewer, admin] = await Promise.all([
    makeStudentClient(),
    makeStudent2Client(),
    makeReviewerClient(),
    makeAdminClient(),
  ]);
});

afterAll(async () => {
  if (SKIP) return;
  await deleteTestUsers([users.student1Id, users.student2Id, users.reviewerId, users.adminId]);
});

// =============================================================================
// 1. attempts table — core isolation guarantee
// =============================================================================
maybeDescribe('attempts — RLS isolation', () => {
  let attemptId: string;

  maybeIt('student1 can insert their own attempt', async () => {
    const { data, error } = await student1
      .from('attempts')
      .insert({
        user_id: users.student1Id,
        question_id: LIVE_QUESTION_ID,
        chosen_option: 'A',
        is_correct: true,
        time_ms: 1500,
      })
      .select('id')
      .single();

    expect(error).toBeNull();
    expect(data).not.toBeNull();
    attemptId = data!.id as string;
  });

  maybeIt('student1 can read their own attempts', async () => {
    const { data, error } = await student1
      .from('attempts')
      .select('id')
      .eq('user_id', users.student1Id);

    expect(error).toBeNull();
    expect((data ?? []).length).toBeGreaterThan(0);
  });

  maybeIt("student2 cannot read student1's attempts", async () => {
    const { data, error } = await student2
      .from('attempts')
      .select('id')
      .eq('user_id', users.student1Id);

    // RLS returns an empty array (not an error) for unauthorised reads.
    expect(error).toBeNull();
    expect(data ?? []).toHaveLength(0);
  });

  maybeIt('student1 cannot insert an attempt on behalf of student2', async () => {
    const { error } = await student1.from('attempts').insert({
      user_id: users.student2Id, // wrong user_id
      question_id: LIVE_QUESTION_ID,
      chosen_option: 'B',
      is_correct: false,
    });

    // Should be rejected: with check (auth.uid() = user_id)
    expect(error).not.toBeNull();
  });

  maybeIt('admin can read attempts from any user', async () => {
    const { data, error } = await admin
      .from('attempts')
      .select('id')
      .eq('user_id', users.student1Id);

    expect(error).toBeNull();
    expect((data ?? []).length).toBeGreaterThan(0);
  });

  // Cleanup
  afterAll(async () => {
    if (attemptId) {
      await serviceClient.from('attempts').delete().eq('id', attemptId);
    }
  });
});

// =============================================================================
// 2. profiles — each user sees only their own row
// =============================================================================
maybeDescribe('profiles — RLS isolation', () => {
  maybeIt('student1 can read their own profile', async () => {
    const { data, error } = await student1
      .from('profiles')
      .select('id, role')
      .eq('id', users.student1Id);

    expect(error).toBeNull();
    expect(data ?? []).toHaveLength(1);
    expect((data![0] as { role: string }).role).toBe('student');
  });

  maybeIt("student1 cannot read student2's profile", async () => {
    const { data, error } = await student1.from('profiles').select('id').eq('id', users.student2Id);

    expect(error).toBeNull();
    expect(data ?? []).toHaveLength(0);
  });

  maybeIt('student1 can update their own nickname', async () => {
    const { error } = await student1
      .from('profiles')
      .update({ nickname: 'Updated Nick' })
      .eq('id', users.student1Id);

    expect(error).toBeNull();
  });

  maybeIt('admin can read any profile', async () => {
    const { data, error } = await admin
      .from('profiles')
      .select('id')
      .in('id', [users.student1Id, users.student2Id]);

    expect(error).toBeNull();
    expect((data ?? []).length).toBe(2);
  });
});

// =============================================================================
// 3. questions — students see only live questions
// =============================================================================
maybeDescribe('questions — students see live only', () => {
  let draftQuestionId: string;

  beforeAll(async () => {
    if (SKIP) return;
    // Admin creates a draft question to test that students cannot see it.
    const { data } = await serviceClient
      .from('questions')
      .insert({
        family_id: 'F0000001-0000-0000-0000-000000000001',
        chapter_id: CHAPTER_ID,
        topic_id: '20000000-0000-0000-0000-000000000011',
        difficulty: 1,
        body: 'DRAFT TEST QUESTION — should not be visible to students',
        explanation: 'Draft explanation.',
        status: 'draft',
        source: 'test',
      })
      .select('id')
      .single();
    draftQuestionId = data?.id as string;
  });

  afterAll(async () => {
    if (draftQuestionId) {
      await serviceClient.from('questions').delete().eq('id', draftQuestionId);
    }
  });

  maybeIt('student can read live questions', async () => {
    const { data, error } = await student1
      .from('questions')
      .select('id, status')
      .eq('id', LIVE_QUESTION_ID);

    expect(error).toBeNull();
    expect(data ?? []).toHaveLength(1);
    expect((data![0] as { status: string }).status).toBe('live');
  });

  maybeIt('student cannot see draft questions', async () => {
    const { data, error } = await student1.from('questions').select('id').eq('id', draftQuestionId);

    expect(error).toBeNull();
    expect(data ?? []).toHaveLength(0);
  });

  maybeIt('reviewer can see draft questions', async () => {
    const { data, error } = await reviewer
      .from('questions')
      .select('id, status')
      .eq('id', draftQuestionId);

    expect(error).toBeNull();
    expect(data ?? []).toHaveLength(1);
  });

  maybeIt('admin can see draft questions', async () => {
    const { data, error } = await admin
      .from('questions')
      .select('id, status')
      .eq('id', draftQuestionId);

    expect(error).toBeNull();
    expect(data ?? []).toHaveLength(1);
  });

  maybeIt('student cannot set a question to live status', async () => {
    const { error } = await student1
      .from('questions')
      .update({ status: 'live' })
      .eq('id', draftQuestionId);

    expect(error).not.toBeNull();
  });

  maybeIt('reviewer cannot set status to live (only up to approved)', async () => {
    // First advance to reviewed:
    await serviceClient.from('questions').update({ status: 'reviewed' }).eq('id', draftQuestionId);

    const { error } = await reviewer
      .from('questions')
      .update({ status: 'live' })
      .eq('id', draftQuestionId);

    expect(error).not.toBeNull();
  });

  maybeIt('admin can set status to live', async () => {
    const { error } = await admin
      .from('questions')
      .update({ status: 'live' })
      .eq('id', draftQuestionId);

    expect(error).toBeNull();
  });
});

// =============================================================================
// 4. mastery — own-row isolation
// =============================================================================
maybeDescribe('mastery — RLS isolation', () => {
  beforeAll(async () => {
    if (SKIP) return;
    // Seed mastery rows for both students.
    await serviceClient.from('mastery').upsert([
      {
        user_id: users.student1Id,
        chapter_id: CHAPTER_ID,
        level: 1,
        score: 30,
        correct_streak: 0,
        wrong_streak: 0,
      },
      {
        user_id: users.student2Id,
        chapter_id: CHAPTER_ID,
        level: 2,
        score: 60,
        correct_streak: 0,
        wrong_streak: 0,
      },
    ]);
  });

  afterAll(async () => {
    await serviceClient
      .from('mastery')
      .delete()
      .in('user_id', [users.student1Id, users.student2Id]);
  });

  maybeIt('student1 can read their own mastery', async () => {
    const { data, error } = await student1
      .from('mastery')
      .select('*')
      .eq('user_id', users.student1Id);

    expect(error).toBeNull();
    expect((data ?? []).length).toBeGreaterThan(0);
  });

  maybeIt("student1 cannot read student2's mastery", async () => {
    const { data, error } = await student1
      .from('mastery')
      .select('*')
      .eq('user_id', users.student2Id);

    expect(error).toBeNull();
    expect(data ?? []).toHaveLength(0);
  });
});

// =============================================================================
// 5. sessions — own-row isolation
// =============================================================================
maybeDescribe('sessions — RLS isolation', () => {
  let session1Id: string;
  let session2Id: string;

  beforeAll(async () => {
    if (SKIP) return;
    const results = await Promise.all([
      serviceClient
        .from('sessions')
        .insert({ user_id: users.student1Id, chapter_id: CHAPTER_ID })
        .select('id')
        .single(),
      serviceClient
        .from('sessions')
        .insert({ user_id: users.student2Id, chapter_id: CHAPTER_ID })
        .select('id')
        .single(),
    ]);
    session1Id = results[0].data?.id as string;
    session2Id = results[1].data?.id as string;
  });

  afterAll(async () => {
    await serviceClient
      .from('sessions')
      .delete()
      .in('id', [session1Id, session2Id].filter(Boolean));
  });

  maybeIt('student1 can read their own session', async () => {
    const { data, error } = await student1.from('sessions').select('id').eq('id', session1Id);

    expect(error).toBeNull();
    expect(data ?? []).toHaveLength(1);
  });

  maybeIt("student1 cannot read student2's session", async () => {
    const { data, error } = await student1.from('sessions').select('id').eq('id', session2Id);

    expect(error).toBeNull();
    expect(data ?? []).toHaveLength(0);
  });
});

// =============================================================================
// 6. student_misconceptions — own-row isolation
// =============================================================================
maybeDescribe('student_misconceptions — RLS isolation', () => {
  const MISCONCEPTION_ID = '30000000-0000-0000-0000-000000000001';

  beforeAll(async () => {
    if (SKIP) return;
    await serviceClient.from('student_misconceptions').upsert([
      {
        user_id: users.student1Id,
        misconception_id: MISCONCEPTION_ID,
        hit_count: 2,
        success_count: 0,
      },
      {
        user_id: users.student2Id,
        misconception_id: MISCONCEPTION_ID,
        hit_count: 1,
        success_count: 0,
      },
    ]);
  });

  afterAll(async () => {
    await serviceClient
      .from('student_misconceptions')
      .delete()
      .in('user_id', [users.student1Id, users.student2Id]);
  });

  maybeIt('student1 can read their own misconception record', async () => {
    const { data, error } = await student1
      .from('student_misconceptions')
      .select('*')
      .eq('user_id', users.student1Id);

    expect(error).toBeNull();
    expect((data ?? []).length).toBeGreaterThan(0);
  });

  maybeIt("student1 cannot read student2's misconception record", async () => {
    const { data, error } = await student1
      .from('student_misconceptions')
      .select('*')
      .eq('user_id', users.student2Id);

    expect(error).toBeNull();
    expect(data ?? []).toHaveLength(0);
  });
});

// =============================================================================
// 7. review_queue — own-row isolation
// =============================================================================
maybeDescribe('review_queue — RLS isolation', () => {
  beforeAll(async () => {
    if (SKIP) return;
    await serviceClient.from('review_queue').upsert([
      {
        user_id: users.student1Id,
        question_id: LIVE_QUESTION_ID,
        due_at: new Date().toISOString(),
        stage: 0,
      },
    ]);
  });

  afterAll(async () => {
    await serviceClient.from('review_queue').delete().eq('user_id', users.student1Id);
  });

  maybeIt('student1 can read their own review queue', async () => {
    const { data, error } = await student1
      .from('review_queue')
      .select('*')
      .eq('user_id', users.student1Id);

    expect(error).toBeNull();
    expect((data ?? []).length).toBeGreaterThan(0);
  });

  maybeIt("student2 cannot read student1's review queue", async () => {
    const { data, error } = await student2
      .from('review_queue')
      .select('*')
      .eq('user_id', users.student1Id);

    expect(error).toBeNull();
    expect(data ?? []).toHaveLength(0);
  });
});

// =============================================================================
// 8. question_reports — insert open, read restricted
// =============================================================================
maybeDescribe('question_reports — RLS', () => {
  let reportId: string;

  maybeIt('any authenticated student can submit a report', async () => {
    const { data, error } = await student1
      .from('question_reports')
      .insert({
        question_id: LIVE_QUESTION_ID,
        user_id: users.student1Id,
        reason: 'typo',
        note: 'Test report from RLS test suite.',
      })
      .select('id')
      .single();

    expect(error).toBeNull();
    reportId = data?.id as string;
  });

  maybeIt('student cannot read reports', async () => {
    const { data, error } = await student1.from('question_reports').select('id').eq('id', reportId);

    expect(error).toBeNull();
    expect(data ?? []).toHaveLength(0);
  });

  maybeIt('reviewer can read reports', async () => {
    const { data, error } = await reviewer.from('question_reports').select('id').eq('id', reportId);

    expect(error).toBeNull();
    expect((data ?? []).length).toBeGreaterThan(0);
  });

  maybeIt('admin can read and resolve a report', async () => {
    const { error } = await admin
      .from('question_reports')
      .update({ resolved: true })
      .eq('id', reportId);

    expect(error).toBeNull();
  });

  afterAll(async () => {
    if (reportId) {
      await serviceClient.from('question_reports').delete().eq('id', reportId);
    }
  });
});

// =============================================================================
// 9. question_options trigger — integrity enforcement
// =============================================================================
maybeDescribe('question_options — trigger integrity', () => {
  // We test the trigger directly via the service client (bypasses RLS)
  // to isolate trigger logic from RLS.

  maybeIt('trigger rejects a question with two correct options', async () => {
    // Insert a minimal question first.
    const { data: q } = await serviceClient
      .from('questions')
      .insert({
        family_id: 'F0000001-0000-0000-0000-000000000001',
        chapter_id: CHAPTER_ID,
        topic_id: '20000000-0000-0000-0000-000000000011',
        difficulty: 1,
        body: 'TRIGGER TEST: two correct options',
        explanation: 'Test.',
        status: 'draft',
        source: 'test',
      })
      .select('id')
      .single();

    const qId = q?.id as string;

    // Insert option A (correct).
    await serviceClient.from('question_options').insert({
      question_id: qId,
      option_key: 'A',
      text: 'Correct A',
      is_correct: true,
      is_random_distractor: false,
    });

    // Insert option B (also correct) — trigger should fire and reject.
    const { error } = await serviceClient.from('question_options').insert({
      question_id: qId,
      option_key: 'B',
      text: 'Correct B',
      is_correct: true,
      is_random_distractor: false,
    });

    expect(error).not.toBeNull();
    expect(error?.message).toContain('exactly 1 correct option');

    // Cleanup
    await serviceClient.from('questions').delete().eq('id', qId);
  });

  maybeIt('trigger rejects a wrong option without misconception or random flag', async () => {
    const { data: q } = await serviceClient
      .from('questions')
      .insert({
        family_id: 'F0000001-0000-0000-0000-000000000001',
        chapter_id: CHAPTER_ID,
        topic_id: '20000000-0000-0000-0000-000000000011',
        difficulty: 1,
        body: 'TRIGGER TEST: bare wrong option',
        explanation: 'Test.',
        status: 'draft',
        source: 'test',
      })
      .select('id')
      .single();

    const qId = q?.id as string;

    // Insert option A (correct) — this alone is valid (1 correct, 0 wrong).
    await serviceClient.from('question_options').insert({
      question_id: qId,
      option_key: 'A',
      text: 'Correct',
      is_correct: true,
      is_random_distractor: false,
    });

    // Insert option B (wrong, no misconception, not random) — should fail.
    const { error } = await serviceClient.from('question_options').insert({
      question_id: qId,
      option_key: 'B',
      text: 'Wrong with no tag',
      is_correct: false,
      is_random_distractor: false,
      misconception_id: null,
    });

    expect(error).not.toBeNull();
    expect(error?.message).toContain('neither misconception_id nor is_random_distractor');

    await serviceClient.from('questions').delete().eq('id', qId);
  });

  maybeIt(
    'trigger accepts a question with one correct + wrong options that have misconception or random',
    async () => {
      const { data: q } = await serviceClient
        .from('questions')
        .insert({
          family_id: 'F0000001-0000-0000-0000-000000000001',
          chapter_id: CHAPTER_ID,
          topic_id: '20000000-0000-0000-0000-000000000011',
          difficulty: 1,
          body: 'TRIGGER TEST: valid question',
          explanation: 'Test.',
          status: 'draft',
          source: 'test',
        })
        .select('id')
        .single();

      const qId = q?.id as string;

      const { error } = await serviceClient.from('question_options').insert([
        {
          question_id: qId,
          option_key: 'A',
          text: 'Correct',
          is_correct: true,
          is_random_distractor: false,
          misconception_id: null,
        },
        {
          question_id: qId,
          option_key: 'B',
          text: 'Wrong (misc)',
          is_correct: false,
          is_random_distractor: false,
          misconception_id: '30000000-0000-0000-0000-000000000001',
        },
        {
          question_id: qId,
          option_key: 'C',
          text: 'Wrong (random)',
          is_correct: false,
          is_random_distractor: true,
          misconception_id: null,
        },
        {
          question_id: qId,
          option_key: 'D',
          text: 'Wrong (misc+random)',
          is_correct: false,
          is_random_distractor: true,
          misconception_id: '30000000-0000-0000-0000-000000000002',
        },
      ]);

      expect(error).toBeNull();

      await serviceClient.from('questions').delete().eq('id', qId);
    },
  );
});

// =============================================================================
// 10. syllabus tables — read-only for all users, write for admin only
// =============================================================================
maybeDescribe('syllabus — read public, write admin only', () => {
  maybeIt('student can read subjects', async () => {
    const { data, error } = await student1.from('subjects').select('name');
    expect(error).toBeNull();
    expect((data ?? []).length).toBeGreaterThan(0);
  });

  maybeIt('student cannot insert a subject', async () => {
    const { error } = await student1.from('subjects').insert({ name: 'TestSubjectFromStudent' });
    expect(error).not.toBeNull();
  });

  maybeIt('admin can insert a subject', async () => {
    const { error } = await admin.from('subjects').insert({ name: '_TestSubjectFromAdmin' });
    // Clean up regardless.
    await serviceClient.from('subjects').delete().eq('name', '_TestSubjectFromAdmin');
    expect(error).toBeNull();
  });
});
