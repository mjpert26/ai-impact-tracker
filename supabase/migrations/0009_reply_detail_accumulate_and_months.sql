-- 0009_reply_detail_accumulate_and_months.sql
-- Two changes that make the replies/Records tier production-grade:
--
-- 1) refresh_ai_impact_reply_detail now ACCUMULATES (upsert by location_id+contact_id)
--    instead of REPLACING (delete+insert). GHL's conversations/search has no pagination
--    (recent ~100 per bot), so the old replace semantics froze the table at ~one window.
--    Accumulating means each nightly run (and the one-time 2026 backfill) compounds into
--    a growing history that never shrinks; one row per contact = their latest reply.
--
-- 2) ai_reply_detail_months: a small per-month index so the dashboard Records tab can
--    lazy-load one month at a time instead of pulling every row at once.
--
-- Applied to project rrdgghwxuincfengkjyd as migration `reply_detail_accumulate_and_months`.

create or replace function public.refresh_ai_impact_reply_detail(p_location text, p_rows jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ai_impact, public
as $$
begin
  insert into ai_impact.fct_reply_detail
    (location_id, contact_id, payout_month, contact_name, email, sentiment, last_message, sf_lead_id, sf_stage, funded_commission, msg_ts)
  select p_location, x.contact_id, x.payout_month, x.contact_name, x.email, x.sentiment, x.last_message,
         x.sf_lead_id, x.sf_stage, x.funded_commission, to_timestamp((x.ts)::bigint/1000.0)
  from jsonb_to_recordset(coalesce(p_rows,'[]'::jsonb))
    as x(contact_id text, payout_month text, contact_name text, email text, sentiment text,
         last_message text, sf_lead_id text, sf_stage text, funded_commission numeric, ts bigint)
  on conflict (location_id, contact_id) do update
    set payout_month      = excluded.payout_month,
        contact_name      = excluded.contact_name,
        email             = excluded.email,
        sentiment         = excluded.sentiment,
        last_message      = excluded.last_message,
        sf_lead_id        = excluded.sf_lead_id,
        sf_stage          = excluded.sf_stage,
        funded_commission = excluded.funded_commission,
        msg_ts            = excluded.msg_ts;
  return jsonb_build_object('ok', true, 'location', p_location,
    'rows', (select count(*) from ai_impact.fct_reply_detail where location_id = p_location));
end; $$;

create or replace view public.ai_reply_detail_months as
  select payout_month, count(*)::int as records, count(*) filter (where funded_commission > 0)::int as funded
  from ai_impact.fct_reply_detail
  where payout_month is not null
  group by payout_month
  order by payout_month desc;

grant select on public.ai_reply_detail_months to anon, authenticated;
