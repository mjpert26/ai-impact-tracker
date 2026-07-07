-- 0014_role_guards_money.sql  (APPLIED as `role_guards_money`)
-- Phase 1 of Canvas SSO. can_see_money() = direct DB, anon (until lockdown), or
-- JWT app_role='exec'. Commission/ROI views return no rows for 'ops' tokens;
-- engagement views keep rows but null the $ columns. Zero change for anon today.
-- (Full SQL mirrors what was applied; see repo history / Supabase migration log.)

create or replace function public.can_see_money()
returns boolean
language sql stable
as $$
  select coalesce(nullif(current_setting('request.jwt.claims', true), ''), '') = ''
      or coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb->>'role', '') = 'anon'
      or coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb->>'app_role', '') = 'exec';
$$;
grant execute on function public.can_see_money() to anon, authenticated;

create or replace view public.ai_kpi_summary as
  select metric, value, as_of from ai_impact.kpi_summary
  where public.can_see_money();

create or replace view public.ai_commission_by_month as
  select payout_month, commission_amt, distinct_opps
  from ai_impact.fct_commission_by_month
  where public.can_see_money();

create or replace view public.ai_commission_by_bot as
  select b.assisted_by_value,
         coalesce(d.bot_name, b.assisted_by_value) as bot_name,
         d.channel, d.bot_type, b.commission_amt, b.distinct_opps, b.note
  from ai_impact.fct_commission_by_bot b
  left join ai_impact.dim_bot d using (assisted_by_value)
  where public.can_see_money();

create or replace view public.ai_commission_by_bot_month as
  select bm.assisted_by_value, coalesce(b.bot_name, bm.assisted_by_value) as bot_name,
         bm.payout_month, bm.commission_amt, bm.distinct_opps
  from ai_impact.fct_commission_by_bot_month bm
  left join ai_impact.dim_bot b using (assisted_by_value)
  where public.can_see_money();

create or replace view public.ai_roi as
  select monthly_usd, as_of, note from ai_impact.ai_program_cost
  where id = 1 and public.can_see_money();

create or replace view public.ai_reply_outcomes as
  select coalesce(d.bot_name, o.location_id) as bot_name,
         d.assisted_by_value,
         o.positive_replies,
         o.positive_advanced,
         case when o.positive_replies > 0 then round(100.0 * o.positive_advanced / o.positive_replies) else 0 end as advanced_pct,
         o.positive_funded,
         case when o.positive_replies > 0 then round(100.0 * coalesce(o.positive_funded,0) / o.positive_replies) else 0 end as funded_pct,
         case when public.can_see_money() then coalesce(o.funded_commission, 0) else null end as funded_commission,
         coalesce(c.conversations, 0) as conversations,
         o.as_of
  from ai_impact.fct_reply_outcomes o
  left join ai_impact.dim_location d using (location_id)
  left join (select location_id, count(*) as conversations
             from ai_impact.fct_reply_detail group by location_id) c using (location_id);

create or replace view public.ai_reply_detail as
  select coalesce(d.bot_name, r.location_id) as bot_name,
         d.assisted_by_value,
         r.payout_month,
         r.contact_name,
         r.email,
         r.sentiment,
         r.last_message,
         r.sf_lead_id,
         case when fe.email is not null then 'Funded' else r.sf_stage end as sf_stage,
         case when public.can_see_money() then coalesce(fe.commission, r.funded_commission, 0) else null end as funded_commission,
         r.msg_ts
  from ai_impact.fct_reply_detail r
  left join ai_impact.dim_location d using (location_id)
  left join ai_impact.sf_funded_email fe on lower(r.email) = fe.email;

grant select on public.ai_kpi_summary, public.ai_commission_by_month,
  public.ai_commission_by_bot, public.ai_commission_by_bot_month, public.ai_roi,
  public.ai_reply_outcomes, public.ai_reply_detail to anon, authenticated;
