/**
 * Test fixtures: create and delete test users for the RLS test suite.
 *
 * Uses the service-role client (bypasses RLS) to:
 *   1. Create four auth users (student1, student2, reviewer, admin).
 *   2. Set their roles in the profiles table.
 *   3. Clean them up after the suite.
 */

import { serviceClient } from './clients.js';

export interface TestUsers {
  student1Id: string;
  student2Id: string;
  reviewerId: string;
  adminId: string;
}

export async function createTestUsers(): Promise<TestUsers> {
  const users = await Promise.all([
    createUser('student1@test.local', 'test-password-1'),
    createUser('student2@test.local', 'test-password-2'),
    createUser('reviewer@test.local', 'test-password-r'),
    createUser('admin@test.local', 'test-password-a'),
  ]);

  const [student1Id, student2Id, reviewerId, adminId] = users as [string, string, string, string];

  // Set roles in profiles table (the trigger creates the row; we just update role).
  await serviceClient.from('profiles').upsert([
    { id: student1Id, role: 'student', nickname: 'Student One' },
    { id: student2Id, role: 'student', nickname: 'Student Two' },
    { id: reviewerId, role: 'reviewer', nickname: 'Reviewer' },
    { id: adminId, role: 'admin', nickname: 'Admin' },
  ]);

  return { student1Id, student2Id, reviewerId, adminId };
}

async function createUser(email: string, password: string): Promise<string> {
  // Try to sign up; if the user already exists, look them up instead.
  const { data: signUpData, error: signUpError } = await serviceClient.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
  });

  if (signUpData?.user) return signUpData.user.id;

  if (signUpError?.message?.includes('already been registered')) {
    const { data: listData } = await serviceClient.auth.admin.listUsers();
    const existing = listData?.users?.find((u) => u.email === email);
    if (existing) return existing.id;
  }

  throw new Error(`Could not create test user ${email}: ${signUpError?.message ?? 'unknown'}`);
}

export async function deleteTestUsers(ids: string[]): Promise<void> {
  await Promise.all(ids.map((id) => serviceClient.auth.admin.deleteUser(id)));
}
