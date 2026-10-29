-- Seed: 001_syllabus_class8_maths.sql
-- Class 8 Maths syllabus (CBSE/NCERT-aligned).
-- Chapters, topics, and topic prerequisites for the pilot content.
--
-- NOTE: This seed uses fixed UUIDs so subsequent seed runs are idempotent.

-- ── Subject ───────────────────────────────────────────────────────────────────
insert into subjects (id, name) values
  ('00000000-0000-0000-0000-000000000001', 'Maths')
on conflict (name) do nothing;

-- ── Chapters (Class 8 Maths – 13 NCERT chapters) ────────────────────────────
insert into chapters (id, class_level, subject_id, number, title) values
  ('10000000-0000-0000-0000-000000000001', 8, '00000000-0000-0000-0000-000000000001', 1,  'Rational Numbers'),
  ('10000000-0000-0000-0000-000000000002', 8, '00000000-0000-0000-0000-000000000001', 2,  'Linear Equations in One Variable'),
  ('10000000-0000-0000-0000-000000000003', 8, '00000000-0000-0000-0000-000000000001', 3,  'Understanding Quadrilaterals'),
  ('10000000-0000-0000-0000-000000000004', 8, '00000000-0000-0000-0000-000000000001', 4,  'Data Handling'),
  ('10000000-0000-0000-0000-000000000005', 8, '00000000-0000-0000-0000-000000000001', 5,  'Squares and Square Roots'),
  ('10000000-0000-0000-0000-000000000006', 8, '00000000-0000-0000-0000-000000000001', 6,  'Cubes and Cube Roots'),
  ('10000000-0000-0000-0000-000000000007', 8, '00000000-0000-0000-0000-000000000001', 7,  'Comparing Quantities'),
  ('10000000-0000-0000-0000-000000000008', 8, '00000000-0000-0000-0000-000000000001', 8,  'Algebraic Expressions and Identities'),
  ('10000000-0000-0000-0000-000000000009', 8, '00000000-0000-0000-0000-000000000001', 9,  'Mensuration'),
  ('10000000-0000-0000-0000-000000000010', 8, '00000000-0000-0000-0000-000000000001', 10, 'Exponents and Powers'),
  ('10000000-0000-0000-0000-000000000011', 8, '00000000-0000-0000-0000-000000000001', 11, 'Direct and Inverse Proportions'),
  ('10000000-0000-0000-0000-000000000012', 8, '00000000-0000-0000-0000-000000000001', 12, 'Factorisation'),
  ('10000000-0000-0000-0000-000000000013', 8, '00000000-0000-0000-0000-000000000001', 13, 'Introduction to Graphs')
on conflict (class_level, subject_id, number) do nothing;

-- ── Topics ────────────────────────────────────────────────────────────────────
-- Chapter 1: Rational Numbers
insert into topics (id, chapter_id, title, learning_outcome) values
  ('20000000-0000-0000-0000-000000000001',
   '10000000-0000-0000-0000-000000000001',
   'Properties of rational numbers',
   'Student can identify and apply closure, commutativity, associativity, and distributivity to rational numbers.'),
  ('20000000-0000-0000-0000-000000000002',
   '10000000-0000-0000-0000-000000000001',
   'Rational numbers on the number line',
   'Student can locate rational numbers on a number line and identify their relative positions.'),
  ('20000000-0000-0000-0000-000000000003',
   '10000000-0000-0000-0000-000000000001',
   'Rational numbers between two rational numbers',
   'Student can find multiple rational numbers between any two given rational numbers.');

-- Chapter 2: Linear Equations
insert into topics (id, chapter_id, title, learning_outcome) values
  ('20000000-0000-0000-0000-000000000010',
   '10000000-0000-0000-0000-000000000002',
   'Solving equations with variables on one side',
   'Student can isolate the variable by applying inverse operations to solve ax + b = c.'),
  ('20000000-0000-0000-0000-000000000011',
   '10000000-0000-0000-0000-000000000002',
   'Solving equations with variables on both sides',
   'Student can collect variable terms on one side and constants on the other to solve equations of the form ax + b = cx + d.'),
  ('20000000-0000-0000-0000-000000000012',
   '10000000-0000-0000-0000-000000000002',
   'Linear equations — word problems',
   'Student can translate a word problem into a linear equation and solve it.');

-- Chapter 5: Squares and Square Roots
insert into topics (id, chapter_id, title, learning_outcome) values
  ('20000000-0000-0000-0000-000000000020',
   '10000000-0000-0000-0000-000000000005',
   'Properties of perfect squares',
   'Student can identify perfect squares, list their properties, and determine whether a number is a perfect square.'),
  ('20000000-0000-0000-0000-000000000021',
   '10000000-0000-0000-0000-000000000005',
   'Finding square roots by prime factorisation',
   'Student can find the square root of a perfect square using prime factorisation.'),
  ('20000000-0000-0000-0000-000000000022',
   '10000000-0000-0000-0000-000000000005',
   'Finding square roots by long division',
   'Student can apply the long-division method to find the square root of large numbers.');

-- Chapter 7: Comparing Quantities
insert into topics (id, chapter_id, title, learning_outcome) values
  ('20000000-0000-0000-0000-000000000030',
   '10000000-0000-0000-0000-000000000007',
   'Percentage increase and decrease',
   'Student can calculate percentage increase/decrease and apply it to real-life problems.'),
  ('20000000-0000-0000-0000-000000000031',
   '10000000-0000-0000-0000-000000000007',
   'Simple interest',
   'Student can apply SI = PRT/100 to find simple interest, principal, rate, or time.'),
  ('20000000-0000-0000-0000-000000000032',
   '10000000-0000-0000-0000-000000000007',
   'Compound interest',
   'Student can apply the compound interest formula A = P(1 + r/100)^n and find CI = A − P.');

-- ── Topic prerequisites ───────────────────────────────────────────────────────
-- Variables on both sides requires variables on one side.
insert into topic_prerequisites (topic_id, requires_topic_id) values
  ('20000000-0000-0000-0000-000000000011', '20000000-0000-0000-0000-000000000010')
on conflict do nothing;

-- Word problems require both solving skills.
insert into topic_prerequisites (topic_id, requires_topic_id) values
  ('20000000-0000-0000-0000-000000000012', '20000000-0000-0000-0000-000000000011')
on conflict do nothing;

-- Square root by long division requires prime factorisation method.
insert into topic_prerequisites (topic_id, requires_topic_id) values
  ('20000000-0000-0000-0000-000000000022', '20000000-0000-0000-0000-000000000021')
on conflict do nothing;

-- Compound interest requires simple interest.
insert into topic_prerequisites (topic_id, requires_topic_id) values
  ('20000000-0000-0000-0000-000000000032', '20000000-0000-0000-0000-000000000031')
on conflict do nothing;

-- Simple interest requires percentage concepts.
insert into topic_prerequisites (topic_id, requires_topic_id) values
  ('20000000-0000-0000-0000-000000000031', '20000000-0000-0000-0000-000000000030')
on conflict do nothing;
