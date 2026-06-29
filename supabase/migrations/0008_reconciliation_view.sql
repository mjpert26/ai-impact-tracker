-- 0008_reconciliation_view.sql
-- Nightly self-check: per-bot and per-month sums must equal the published headline.
-- reconciled=false => drift to investigate (a bot value outside the whitelist, a
-- double-counted multi-tag, or an ETL bug). Applied to project rrdgghwxuincfengkjyd
-- as migration `reconciliation_view`.

create or replace view public.ai_reconciliation as
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
  round((hl.headline_commission - bot.c)::numeric, 2)  as bot_commission_drift,
  round((hl.headline_commission - mon.c)::numeric, 2)  as month_commission_drift,
  hl.headline_deals::int                               as headline_deals,
  bot.d::int                                           as bot_sum_deals,
  mon.d::int                                           as month_sum_deals,
  (abs(hl.headline_commission - bot.c) < 1
   and abs(hl.headline_commission - mon.c) < 1
   and hl.headline_deals = bot.d
   and hl.headline_deals = mon.d)                      as reconciled
from hl, bot, mon;

grant select on public.ai_reconciliation to anon, authenticated;
