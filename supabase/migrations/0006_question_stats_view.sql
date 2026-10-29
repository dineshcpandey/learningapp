-- Migration: 0006_question_stats_view.sql
-- Materialised view for question analytics. Lives in the learning schema.

set search_path to learning, public;

create materialized view learning.question_stats as
select
  q.id                                              as question_id,
  count(a.id)                                       as total_attempts,
  round(
    avg(case when a.is_correct then 1.0 else 0.0 end), 4
  )                                                 as accuracy,
  round(
    count(*) filter (where a.chosen_option = 'A')::numeric
    / nullif(count(a.id), 0), 4
  )                                                 as pick_rate_a,
  round(
    count(*) filter (where a.chosen_option = 'B')::numeric
    / nullif(count(a.id), 0), 4
  )                                                 as pick_rate_b,
  round(
    count(*) filter (where a.chosen_option = 'C')::numeric
    / nullif(count(a.id), 0), 4
  )                                                 as pick_rate_c,
  round(
    count(*) filter (where a.chosen_option = 'D')::numeric
    / nullif(count(a.id), 0), 4
  )                                                 as pick_rate_d,
  percentile_cont(0.5) within group (order by a.time_ms) as median_time_ms
from learning.questions q
left join learning.attempts a on a.question_id = q.id
group by q.id;

create unique index on learning.question_stats (question_id);

create or replace function learning.refresh_question_stats()
returns void
language sql
security definer set search_path = learning, public
as $$
  refresh materialized view concurrently learning.question_stats;
$$;
