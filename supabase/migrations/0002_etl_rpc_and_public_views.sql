-- 0002_etl_rpc_and_public_views.sql
-- Nightly-ETL upsert RPC + read-only public exposure for the dashboard.
-- Applied to the dedicated Supabase project `ai-impact-tracker`
-- (rrdgghwxuincfengkjyd) as migration `etl_rpc_and_public_views`.

-- ---------------------------------------------------------------------------
-- 1. Uniqueness needed for the KPI upsert.
-- ---------------------------------------------------------------------------
create unique index if not exists kpi_summary_metric_key
  on ai_impact.kpi_summary (metric);

-- ---------------------------------------------------------------------------
-- 2. ETL upsert RPC, called nightly by the api.btc n8n workflow with the
--    service_role key. Whole-mart refresh in one transaction.
--      p_kpis     : [{metric, value}, ...]
--      p_by_month : [{payout_month, commission_amt, distinct_opps}, ...]
--      p_by_bot   : [{assisted_by_value, commission_amt, distinct_opps, note}, ...]
-- ---------------------------------------------------------------------------
create or replace function public.refresh_ai_impact_mart(
  p_kpis     jsonb,
  p_by_month jsonb,
  p_by_bot   jsonb
) returns jsonb
language plpgsql
security definer
set search_path = ai_impact, public
as $$
declare
  v_as_of date := current_date;
begin
  -- Monthly facts: full replace.
  delete from ai_impact.fct_commission_by_month;
  insert into ai_impact.fct_commission_by_month (payout_month, commission_amt, distinct_opps)
  select x.payout_month, x.commission_amt, x.distinct_opps
  from jsonb_to_recordset(coalesce(p_by_month, '[]'::jsonb))
       as x(payout_month text, commission_amt numeric, distinct_opps int);

  -- Per-bot facts: full replace with exact per-value rows (retires "Other in-house").
  delete from ai_impact.fct_commission_by_bot;
  insert into ai_impact.fct_commission_by_bot (assisted_by_value, commission_amt, distinct_opps, note)
  select x.assisted_by_value, x.commission_amt, x.distinct_opps, x.note
  from jsonb_to_recordset(coalesce(p_by_bot, '[]'::jsonb))
       as x(assisted_by_value text, commission_amt numeric, distinct_opps int, note text);

  -- KPIs: upsert by metric.
  insert into ai_impact.kpi_summary (metric, value, as_of)
  select x.metric, x.value, v_as_of
  from jsonb_to_recordset(coalesce(p_kpis, '[]'::jsonb)) as x(metric text, value numeric)
  on conflict (metric) do update
    set value = excluded.value, as_of = excluded.as_of;

  return jsonb_build_object(
    'ok', true,
    'as_of', v_as_of,
    'months', (select count(*) from ai_impact.fct_commission_by_month),
    'bots',   (select count(*) from ai_impact.fct_commission_by_bot),
    'total_commission_influenced',
              (select value from ai_impact.kpi_summary where metric = 'total_commission_influenced')
  );
end;
$$;

-- Only the service_role (used by the n8n ETL) may write.
revoke all on function public.refresh_ai_impact_mart(jsonb, jsonb, jsonb) from public;
revoke all on function public.refresh_ai_impact_mart(jsonb, jsonb, jsonb) from anon, authenticated;
grant execute on function public.refresh_ai_impact_mart(jsonb, jsonb, jsonb) to service_role;

-- ---------------------------------------------------------------------------
-- 3. Read-only public views for the dashboard (PostgREST exposes `public`).
--    Views run with owner (postgres) privileges, so anon reads the ai_impact
--    tables through them without direct table grants.
-- ---------------------------------------------------------------------------
create or replace view public.ai_kpi_summary as
  select metric, value, as_of
  from ai_impact.kpi_summary;

create or replace view public.ai_commission_by_month as
  select payout_month, commission_amt, distinct_opps
  from ai_impact.fct_commission_by_month;

create or replace view public.ai_commission_by_bot as
  select b.assisted_by_value,
         coalesce(d.bot_name, b.assisted_by_value) as bot_name,
         d.channel,
         d.bot_type,
         b.commission_amt,
         b.distinct_opps,
         b.note
  from ai_impact.fct_commission_by_bot b
  left join ai_impact.dim_bot d using (assisted_by_value);

grant usage on schema public to anon, authenticated;
grant select on public.ai_kpi_summary         to anon, authenticated;
grant select on public.ai_commission_by_month to anon, authenticated;
grant select on public.ai_commission_by_bot   to anon, authenticated;
