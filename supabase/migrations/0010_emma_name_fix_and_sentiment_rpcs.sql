-- 0010_emma_name_fix_and_sentiment_rpcs.sql
-- 1) dim_bot: correct Emma's display name. The old "(contaminated: Olivia hot-lead
--    clone leftover)" diagnosis was wrong — the actual issue was Gianna's bot writing
--    EW until fixed at source 2026-06-29, and its measured residual impact is
--    immaterial (~41 sub-account conversations, zero funded matches).
-- 2) Sentiment engine RPCs for incremental classification of backfilled reply detail
--    (service_role only; consumed by the hourly n8n classifier workflow).
-- Applied to project rrdgghwxuincfengkjyd as migration `emma_name_fix_and_sentiment_rpcs`.

update ai_impact.dim_bot
   set bot_name = 'Emma Wilson'
 where assisted_by_value = 'Marketing - EW';

create or replace function public.get_unclassified_replies(p_limit int default 1000)
returns table (location_id text, contact_id text, last_message text)
language sql
security definer
set search_path = ai_impact, public
as $$
  select r.location_id, r.contact_id, r.last_message
  from ai_impact.fct_reply_detail r
  where r.sentiment = 'Unclassified'
    and r.last_message is not null and r.last_message <> ''
  order by r.msg_ts desc nulls last
  limit least(coalesce(p_limit,1000), 5000);
$$;

revoke all on function public.get_unclassified_replies(int) from public, anon, authenticated;
grant execute on function public.get_unclassified_replies(int) to service_role;

create or replace function public.set_reply_sentiments(p_rows jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ai_impact, public
as $$
declare v_count int;
begin
  update ai_impact.fct_reply_detail r
     set sentiment = x.sentiment
  from jsonb_to_recordset(coalesce(p_rows,'[]'::jsonb))
       as x(location_id text, contact_id text, sentiment text)
  where r.location_id = x.location_id
    and r.contact_id  = x.contact_id
    and x.sentiment in ('Positive','Neutral','Negative','Opt-out');
  get diagnostics v_count = row_count;
  return jsonb_build_object('ok', true, 'updated', v_count,
    'remaining', (select count(*) from ai_impact.fct_reply_detail where sentiment='Unclassified'));
end; $$;

revoke all on function public.set_reply_sentiments(jsonb) from public, anon, authenticated;
grant execute on function public.set_reply_sentiments(jsonb) to service_role;
