-- 0003_replies_tier.sql
-- GHL conversation-sentiment tier. Applied to project rrdgghwxuincfengkjyd
-- as migration `replies_tier`.

-- GHL sub-account (location) -> bot value. Seeded with the Megan PoC location;
-- add a row per location as we roll out to the other sub-accounts.
create table if not exists ai_impact.dim_location (
  location_id       text primary key,
  assisted_by_value text,
  bot_name          text
);

insert into ai_impact.dim_location (location_id, assisted_by_value, bot_name) values
  ('htgHvVfBZ1WH3UpQoxaa', 'Marketing - MA', 'Megan Anderson')
on conflict (location_id) do update
  set assisted_by_value = excluded.assisted_by_value,
      bot_name          = excluded.bot_name;

-- Sentiment of inbound replies, per location / month / sentiment.
create table if not exists ai_impact.fct_replies (
  location_id   text,
  payout_month  text,   -- 'YYYY-MM' of the reply (lastMessageDate)
  sentiment     text,   -- Positive | Neutral | Negative | Opt-out
  reply_count   integer,
  primary key (location_id, payout_month, sentiment)
);

-- Per-location upsert RPC, called by the nightly GHL workflow (service_role).
create or replace function public.refresh_ai_impact_replies(
  p_location text,
  p_rows     jsonb
) returns jsonb
language plpgsql
security definer
set search_path = ai_impact, public
as $$
begin
  delete from ai_impact.fct_replies where location_id = p_location;
  insert into ai_impact.fct_replies (location_id, payout_month, sentiment, reply_count)
  select p_location, x.payout_month, x.sentiment, x.reply_count
  from jsonb_to_recordset(coalesce(p_rows, '[]'::jsonb))
       as x(payout_month text, sentiment text, reply_count int);

  return jsonb_build_object(
    'ok', true,
    'location', p_location,
    'rows', (select count(*) from ai_impact.fct_replies where location_id = p_location),
    'total_replies', (select coalesce(sum(reply_count),0) from ai_impact.fct_replies where location_id = p_location)
  );
end;
$$;

revoke all on function public.refresh_ai_impact_replies(text, jsonb) from public, anon, authenticated;
grant execute on function public.refresh_ai_impact_replies(text, jsonb) to service_role;

-- Public read views for the dashboard.
create or replace view public.ai_replies_by_sentiment as
  select coalesce(d.bot_name, r.location_id) as bot_name,
         d.assisted_by_value,
         r.sentiment,
         sum(r.reply_count) as reply_count
  from ai_impact.fct_replies r
  left join ai_impact.dim_location d using (location_id)
  group by 1, 2, r.sentiment;

create or replace view public.ai_replies_by_month as
  select r.payout_month,
         r.sentiment,
         sum(r.reply_count) as reply_count
  from ai_impact.fct_replies r
  group by r.payout_month, r.sentiment;

grant usage on schema public to anon, authenticated;
grant select on public.ai_replies_by_sentiment to anon, authenticated;
grant select on public.ai_replies_by_month     to anon, authenticated;
