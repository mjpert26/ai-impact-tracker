-- 0007_reply_detail.sql
-- Per-record reply detail for the dashboard Records tab: one row per contact a bot
-- replied to, with the captured inbound message, sentiment, and the Salesforce join
-- (Lead -> ConvertedOpportunity stage + funded commission). Applied to project
-- rrdgghwxuincfengkjyd as migration `reply_detail`.
--
-- NOTE: this table holds customer PII (names, emails, message bodies). The public
-- `ai_reply_detail` view is granted to anon for the Vercel dashboard — gate that page
-- (Vercel password / Salesforce-embed-only) before sharing externally.

create table if not exists ai_impact.fct_reply_detail (
  location_id       text not null,
  contact_id        text not null,
  payout_month      text,
  contact_name      text,
  email             text,
  sentiment         text,
  last_message      text,
  sf_lead_id        text,
  sf_stage          text,
  funded_commission numeric,
  msg_ts            timestamptz,
  primary key (location_id, contact_id)
);

create index if not exists fct_reply_detail_month on ai_impact.fct_reply_detail (payout_month);

-- Full replace of one location's detail rows per ETL run. p_rows is a JSON array of
-- {contact_id, payout_month, contact_name, email, sentiment, last_message,
--  sf_lead_id, sf_stage, funded_commission, ts} where ts is GHL epoch millis.
create or replace function public.refresh_ai_impact_reply_detail(p_location text, p_rows jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ai_impact, public
as $$
begin
  delete from ai_impact.fct_reply_detail where location_id = p_location;
  insert into ai_impact.fct_reply_detail
    (location_id, contact_id, payout_month, contact_name, email, sentiment, last_message, sf_lead_id, sf_stage, funded_commission, msg_ts)
  select p_location, x.contact_id, x.payout_month, x.contact_name, x.email, x.sentiment, x.last_message,
         x.sf_lead_id, x.sf_stage, x.funded_commission, to_timestamp((x.ts)::bigint/1000.0)
  from jsonb_to_recordset(coalesce(p_rows,'[]'::jsonb))
    as x(contact_id text, payout_month text, contact_name text, email text, sentiment text,
         last_message text, sf_lead_id text, sf_stage text, funded_commission numeric, ts bigint);
  return jsonb_build_object('ok', true, 'location', p_location,
    'rows', (select count(*) from ai_impact.fct_reply_detail where location_id = p_location));
end; $$;

revoke all on function public.refresh_ai_impact_reply_detail(text, jsonb) from public, anon, authenticated;
grant execute on function public.refresh_ai_impact_reply_detail(text, jsonb) to service_role;

-- Public read view: one row per record, bot name resolved via dim_location.
drop view if exists public.ai_reply_detail;
create view public.ai_reply_detail as
  select coalesce(d.bot_name, r.location_id) as bot_name,
         d.assisted_by_value,
         r.payout_month,
         r.contact_name,
         r.email,
         r.sentiment,
         r.last_message,
         r.sf_lead_id,
         r.sf_stage,
         r.funded_commission,
         r.msg_ts
  from ai_impact.fct_reply_detail r
  left join ai_impact.dim_location d using (location_id);

grant select on public.ai_reply_detail to anon, authenticated;
