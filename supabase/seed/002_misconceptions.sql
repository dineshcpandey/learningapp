-- Seed: 002_misconceptions.sql
-- 15 misconceptions across the pilot topics.
-- Fixed UUIDs for idempotency.

insert into misconceptions (id, topic_id, description, remediation_note) values

  -- ── Linear Equations – one side (topic 010) ──────────────────────────────
  ('30000000-0000-0000-0000-000000000001',
   '20000000-0000-0000-0000-000000000010',
   'Added the constant instead of subtracting when moving it to the other side',
   'Remember: moving a term across the equals sign flips its sign. +5 becomes -5.'),

  ('30000000-0000-0000-0000-000000000002',
   '20000000-0000-0000-0000-000000000010',
   'Divided by the constant instead of dividing by the coefficient of x',
   'Check which number is multiplied with x. That is the coefficient — divide both sides by it.'),

  ('30000000-0000-0000-0000-000000000003',
   '20000000-0000-0000-0000-000000000010',
   'Applied the inverse operation to only one side of the equation',
   'Whatever you do to the left side, do the same to the right side to keep the equation balanced.'),

  -- ── Linear Equations – both sides (topic 011) ────────────────────────────
  ('30000000-0000-0000-0000-000000000004',
   '20000000-0000-0000-0000-000000000011',
   'Moved the variable term to the wrong side (added instead of subtracted)',
   'When collecting variables on the left, subtract the right-hand variable term from both sides.'),

  ('30000000-0000-0000-0000-000000000005',
   '20000000-0000-0000-0000-000000000011',
   'Sign error when transposing terms across the equals sign',
   'Transposing a positive term makes it negative, and vice versa.'),

  -- ── Squares and Square Roots – perfect squares (topic 020) ───────────────
  ('30000000-0000-0000-0000-000000000006',
   '20000000-0000-0000-0000-000000000020',
   'Confused a number ending in 2, 3, 7, or 8 as a possible perfect square',
   'A perfect square can only end in 0, 1, 4, 5, 6, or 9.'),

  ('30000000-0000-0000-0000-000000000007',
   '20000000-0000-0000-0000-000000000020',
   'Counted an odd number of prime factors as a perfect square',
   'A perfect square has all prime factors appearing an even number of times.'),

  -- ── Squares and Square Roots – prime factorisation (topic 021) ───────────
  ('30000000-0000-0000-0000-000000000008',
   '20000000-0000-0000-0000-000000000021',
   'Took only one prime from each pair instead of one per pair',
   'When finding the square root, pick ONE factor from each identical pair of primes.'),

  ('30000000-0000-0000-0000-000000000009',
   '20000000-0000-0000-0000-000000000021',
   'Multiplied all prime factors instead of choosing one from each pair',
   'Group prime factors into pairs and then multiply one factor from each pair together.'),

  -- ── Percentage increase / decrease (topic 030) ───────────────────────────
  ('30000000-0000-0000-0000-000000000010',
   '20000000-0000-0000-0000-000000000030',
   'Used the new value instead of the original value as the base in % change formula',
   'Percentage change = (change ÷ original) × 100. Always divide by the original (old) value.'),

  ('30000000-0000-0000-0000-000000000011',
   '20000000-0000-0000-0000-000000000030',
   'Added the percentage to the original number without converting it (e.g. 20% of 50 = 50+20=70)',
   '20% of 50 means (20/100)×50 = 10, so the new value is 50+10 = 60, not 70.'),

  -- ── Simple interest (topic 031) ──────────────────────────────────────────
  ('30000000-0000-0000-0000-000000000012',
   '20000000-0000-0000-0000-000000000031',
   'Forgot to divide by 100 in the SI = PRT/100 formula',
   'The rate R is given as a percentage. Dividing by 100 converts it to a decimal for calculation.'),

  ('30000000-0000-0000-0000-000000000013',
   '20000000-0000-0000-0000-000000000031',
   'Confused Amount with Simple Interest (A = P + SI, not A = SI)',
   'Simple Interest is only the interest earned. Amount = Principal + SI.'),

  -- ── Compound interest (topic 032) ────────────────────────────────────────
  ('30000000-0000-0000-0000-000000000014',
   '20000000-0000-0000-0000-000000000032',
   'Confused compound interest with simple interest (applied SI formula to CI problem)',
   'In compound interest, the interest for each period is added to the principal before calculating the next period''s interest.'),

  ('30000000-0000-0000-0000-000000000015',
   '20000000-0000-0000-0000-000000000032',
   'Reported Amount instead of Compound Interest as the final answer',
   'CI = Amount − Principal. Do not forget to subtract the original principal at the end.')

on conflict do nothing;
