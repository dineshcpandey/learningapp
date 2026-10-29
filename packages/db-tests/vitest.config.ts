import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
    // RLS tests require a real Supabase instance; skip if env vars are not set.
    // Run with: SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... pnpm test
    testTimeout: 30_000,
    hookTimeout: 30_000,
  },
});
