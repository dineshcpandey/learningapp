-- Migration: 0007_math_format.sql
-- Adds body_format to questions to distinguish plain-text from LaTeX content.
-- Decision D-016: PO confirmed LaTeX support is required for math questions.
--
-- body_format applies to the question body, all option texts, and the explanation
-- for that question. One format per question — mixed formats within a question
-- are not supported.
--
-- 'plain'  — plain text, no math markup. Default for all existing rows.
-- 'latex'  — body/options/explanation may contain inline LaTeX delimited by $…$
--            or display LaTeX delimited by $$…$$. Rendered by KaTeX (web admin)
--            and react-native-math-view (mobile client).

alter table questions
  add column body_format text not null default 'plain'
    check (body_format in ('plain', 'latex'));

comment on column questions.body_format is
  'Markup format for body, option texts, and explanation. '
  '''plain'' = raw text. ''latex'' = KaTeX-compatible LaTeX with $…$ inline delimiters.';

-- Index: allows admin to filter questions by format
-- (useful for bulk re-validation when the LaTeX renderer changes)
create index on questions (body_format) where body_format <> 'plain';
