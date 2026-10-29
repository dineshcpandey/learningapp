-- Migration: 0006_question_stats_view.sql
-- Materialised view for question analytics used by the admin panel.
-- Computed on demand (or refreshed hourly via pg_cron / Supabase Edge Function).

create materialized view question_stats as
select
  q.id                                              as question_id,
  count(a.id)                                       as total_attempts,
  round(
    avg(case when a.is_correct then 1.0 else 0.0 end), 4
  )                                                 as accuracy,
  -- pick-rate per option
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
  -- median time using percentile_cont
  percentile_cont(0.5) within group (order by a.time_ms) as median_time_ms
from questions q
left join attempts a on a.question_id = q.id
group by q.id;

create unique index on question_stats (question_id);

-- Convenience function to refresh the view (call from a scheduled job or admin action).
create or replace function refresh_question_stats()
returns void
language sql
security definer set search_path = public
as $$
  refresh materialized view concurrently question_stats;
$$;
