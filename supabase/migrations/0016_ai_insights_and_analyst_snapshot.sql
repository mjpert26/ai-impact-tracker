-- 0016_ai_insights_and_analyst_snapshot.sql
-- Insights & recommendations tier. Applied as `ai_insights` + `analyst_snapshot_rpc`.
-- 1) ai_impact.ai_insights: the weekly AI analyst brief (Claude reviews the mart via
--    the n8n workflow n8n/etl_ai_weekly_analyst.json and writes 4-7 recommendations).
--    set_ai_insights replaces the batch each run. Money-gated public view.
-- 2) get_analyst_snapshot(): one-call mart summary for the analyst (service_role).

create table if not exists ai_impact.ai_insights (
  id           int generated always as identity primary key,
  severity     text check (severity in ('opportunity','warning','win')),
  title        text not null,
  body         text not null,
  generated_at timestamptz not null default now()
);

create or replace function public.set_ai_insights(p_rows jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ai_impact, public
as $$
begin
  delete from ai_impact.ai_insights where true;
  insert into ai_impact.ai_insights (severity, title, body)
  select coalesce(nullif(x.severity,''),'opportunity'), x.title, x.body
  from jsonb_to_recordset(coalesce(p_rows,'[]'::jsonb))
    as x(severity text, title text, body text)
  where x.title is not null and x.body is not null;
  return jsonb_build_object('ok', true,
    'rows', (select count(*) from ai_impact.ai_insights));
end; $$;

revoke all on function public.set_ai_insights(jsonb) from public, anon, authenticated;
grant execute on function public.set_ai_insights(jsonb) to service_role;

create or replace view public.ai_insights as
  select severity, title, body, generated_at
  from ai_impact.ai_insights
  where public.can_see_money()
  order by case severity when 'warning' then 0 when 'opportunity' then 1 else 2 end, id;

grant select on public.ai_insights to anon, authenticated;

create or replace function public.get_analyst_snapshot()
returns jsonb
language sql
security definer
set search_path = ai_impact, public
as $$
  select jsonb_build_object(
    'kpis', (select jsonb_object_agg(metric, value) from ai_impact.kpi_summary),
    'as_of', (select max(as_of) from ai_impact.kpi_summary),
    'by_bot', (select jsonb_agg(jsonb_build_object('bot', b.assisted_by_value, 'name', d.bot_name,
                 'commission', b.commission_amt, 'deals', b.distinct_opps) order by b.commission_amt desc)
               from ai_impact.fct_commission_by_bot b left join ai_impact.dim_bot d using (assisted_by_value)),
    'by_month', (select jsonb_agg(jsonb_build_object('month', payout_month, 'commission', commission_amt,
                  'deals', distinct_opps) order by payout_month) from ai_impact.fct_commission_by_month),
    'outcomes', (select jsonb_agg(jsonb_build_object('bot', coalesce(d.bot_name, o.location_id),
                  'positive_replies', o.positive_replies, 'handoffs', o.positive_advanced,
                  'funded', o.positive_funded, 'funded_commission', o.funded_commission))
                 from ai_impact.fct_reply_outcomes o left join ai_impact.dim_location d using (location_id)),
    'conversations_by_bot', (select jsonb_object_agg(coalesce(d.bot_name, c.location_id), c.n)
                 from (select location_id, count(*) n from ai_impact.fct_reply_detail group by 1) c
                 left join ai_impact.dim_location d using (location_id)),
    'sentiment_mix', (select jsonb_object_agg(sentiment, n) from
                 (select sentiment, count(*) n from ai_impact.fct_reply_detail group by 1) s),
    'monthly_cost_usd', (select monthly_usd from ai_impact.ai_program_cost where id = 1),
    'reconciled', (select reconciled from public.ai_reconciliation)
  );
$$;

revoke all on function public.get_analyst_snapshot() from public, anon, authenticated;
grant execute on function public.get_analyst_snapshot() to service_role;
