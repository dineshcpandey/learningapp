-- Migration: 0007_math_format.sql
-- Adds body_format to learning.questions (D-016: LaTeX support).

set search_path to learning, public;

alter table learning.questions
  add column body_format text not null default 'plain'
    check (body_format in ('plain', 'latex'));

comment on column learning.questions.body_format is
  'Markup format for body, option texts, and explanation. '
  '''plain'' = raw text. ''latex'' = KaTeX-compatible LaTeX with $…$ inline delimiters.';

create index on learning.questions (body_format) where body_format <> 'plain';
