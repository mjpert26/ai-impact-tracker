-- 0013_commission_by_bot_month.sql
-- Per-bot-per-month commission slice (answers "where did the $1M come from"),
-- plus a reconciliation fix: deals tagged with TWO bot values legitimately make the
-- per-bot sum exceed the headline (INCLUDES counts them under both), so the bot-sum
-- check now allows [headline, headline+1%] instead of exact equality. Months remain
-- an exact partition. Applied to rrdgghwxuincfengkjyd as `commission_by_bot_month_v2`
-- (seeded with the 2026-07-01 Salesforce pull; nightly ETL v2 refreshes it).

create table if not exists ai_impact.fct_commission_by_bot_month (
  assisted_by_value text not null,
  payout_month      text not null,
  commission_amt    numeric,
  distinct_opps     integer,
  primary key (assisted_by_value, payout_month)
);

create or replace function public.refresh_ai_impact_bot_month(p_rows jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ai_impact, public
as $$
begin
  delete from ai_impact.fct_commission_by_bot_month where true;
  insert into ai_impact.fct_commission_by_bot_month (assisted_by_value, payout_month, commission_amt, distinct_opps)
  select x.assisted_by_value, x.payout_month, x.commission_amt, x.distinct_opps
  from jsonb_to_recordset(coalesce(p_rows,'[]'::jsonb))
    as x(assisted_by_value text, payout_month text, commission_amt numeric, distinct_opps int);
  return jsonb_build_object('ok', true,
    'rows', (select count(*) from ai_impact.fct_commission_by_bot_month));
end; $$;

revoke all on function public.refresh_ai_impact_bot_month(jsonb) from public, anon, authenticated;
grant execute on function public.refresh_ai_impact_bot_month(jsonb) to service_role;

create or replace view public.ai_commission_by_bot_month as
  select bm.assisted_by_value, coalesce(b.bot_name, bm.assisted_by_value) as bot_name,
         bm.payout_month, bm.commission_amt, bm.distinct_opps
  from ai_impact.fct_commission_by_bot_month bm
  left join ai_impact.dim_bot b using (assisted_by_value);

grant select on public.ai_commission_by_bot_month to anon, authenticated;

drop view if exists public.ai_reconciliation;
create view public.ai_reconciliation as
with hl as (
  select
    max(value) filter (where metric = 'total_commission_influenced') as headline_commission,
    max(value) filter (where metric = 'funded_deals')                as headline_deals
  from ai_impact.kpi_summary
),
bot as (select coalesce(sum(commission_amt),0) c, coalesce(sum(distinct_opps),0) d from ai_impact.fct_commission_by_bot),
mon as (select coalesce(sum(commission_amt),0) c, coalesce(sum(distinct_opps),0) d from ai_impact.fct_commission_by_month)
select
  round(hl.headline_commission::numeric, 2)            as headline_commission,
  round(bot.c::numeric, 2)                             as bot_sum_commission,
  round(mon.c::numeric, 2)                             as month_sum_commission,
  round((bot.c - hl.headline_commission)::numeric, 2)  as bot_overlap_amount,
  round((hl.headline_commission - mon.c)::numeric, 2)  as month_commission_drift,
  hl.headline_deals::int                               as headline_deals,
  bot.d::int                                           as bot_sum_deals,
  mon.d::int                                           as month_sum_deals,
  (abs(hl.headline_commission - mon.c) < 1
   and hl.headline_deals = mon.d
   and bot.c >= hl.headline_commission - 1
   and bot.c <= hl.headline_commission * 1.01)         as reconciled
from hl, bot, mon;

grant select on public.ai_reconciliation to anon, authenticated;
