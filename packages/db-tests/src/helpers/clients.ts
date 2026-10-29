/**
 * Supabase test client helpers.
 *
 * The RLS tests use three client personas:
 *   - `serviceClient`  — bypasses RLS (used for test setup/teardown)
 *   - `studentClient`  — authenticated as a student user
 *   - `student2Client` — authenticated as a second student (to test isolation)
 *   - `reviewerClient` — authenticated as a reviewer
 *   - `adminClient`    — authenticated as an admin
 *
 * In a real CI run, use `supabase test db` or a local Supabase instance.
 * In this suite, we call `supabase.auth.signInWithPassword` using pre-seeded
 * test accounts and then use the resulting session JWT for RLS checks.
 *
 * Environment variables required:
 *   SUPABASE_URL
 *   SUPABASE_SERVICE_ROLE_KEY
 *   TEST_STUDENT_EMAIL / TEST_STUDENT_PASSWORD
 *   TEST_STUDENT2_EMAIL / TEST_STUDENT2_PASSWORD
 *   TEST_REVIEWER_EMAIL / TEST_REVIEWER_PASSWORD
 *   TEST_ADMIN_EMAIL / TEST_ADMIN_PASSWORD
 */

import { createClient, type SupabaseClient } from '@supabase/supabase-js';

const url = process.env['SUPABASE_URL'] ?? '';
const serviceKey = process.env['SUPABASE_SERVICE_ROLE_KEY'] ?? '';

/** True when env vars are present; used by the test file to skip gracefully. */
export const DB_CONFIGURED = Boolean(url && serviceKey);

/** Bypasses RLS — only for test setup / teardown. Null when not configured. */
export const serviceClient: SupabaseClient = DB_CONFIGURED
  ? createClient(url, serviceKey, { auth: { persistSession: false } })
  : (null as unknown as SupabaseClient); // guarded by DB_CONFIGURED checks in test file

/** Creates an anon client then signs in, returning the authenticated client. */
async function makeAuthClient(email: string, password: string): Promise<SupabaseClient> {
  const anonKey = process.env['SUPABASE_ANON_KEY'] ?? serviceKey; // fall back in local env
  const client = createClient(url, anonKey, { auth: { persistSession: false } });
  const { error } = await client.auth.signInWithPassword({ email, password });
  if (error) throw new Error(`Auth failed for ${email}: ${error.message}`);
  return client;
}

export async function makeStudentClient(): Promise<SupabaseClient> {
  return makeAuthClient(
    process.env['TEST_STUDENT_EMAIL'] ?? 'student1@test.local',
    process.env['TEST_STUDENT_PASSWORD'] ?? 'test-password-1',
  );
}

export async function makeStudent2Client(): Promise<SupabaseClient> {
  return makeAuthClient(
    process.env['TEST_STUDENT2_EMAIL'] ?? 'student2@test.local',
    process.env['TEST_STUDENT2_PASSWORD'] ?? 'test-password-2',
  );
}

export async function makeReviewerClient(): Promise<SupabaseClient> {
  return makeAuthClient(
    process.env['TEST_REVIEWER_EMAIL'] ?? 'reviewer@test.local',
    process.env['TEST_REVIEWER_PASSWORD'] ?? 'test-password-r',
  );
}

export async function makeAdminClient(): Promise<SupabaseClient> {
  return makeAuthClient(
    process.env['TEST_ADMIN_EMAIL'] ?? 'admin@test.local',
    process.env['TEST_ADMIN_PASSWORD'] ?? 'test-password-a',
  );
}
