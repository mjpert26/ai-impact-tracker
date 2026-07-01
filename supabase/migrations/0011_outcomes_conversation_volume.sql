-- 0011_outcomes_conversation_volume.sql
-- Add per-bot conversation volume (from the backfilled fct_reply_detail) to the
-- public outcomes view so the dashboard can show each bot's engagement footprint.
-- Applied to project rrdgghwxuincfengkjyd as migration `outcomes_conversation_volume`.

drop view if exists public.ai_reply_outcomes;
create view public.ai_reply_outcomes as
  select coalesce(d.bot_name, o.location_id) as bot_name,
         d.assisted_by_value,
         o.positive_replies,
         o.positive_advanced,
         case when o.positive_replies > 0 then round(100.0 * o.positive_advanced / o.positive_replies) else 0 end as advanced_pct,
         o.positive_funded,
         case when o.positive_replies > 0 then round(100.0 * coalesce(o.positive_funded,0) / o.positive_replies) else 0 end as funded_pct,
         coalesce(o.funded_commission, 0) as funded_commission,
         coalesce(c.conversations, 0) as conversations,
         o.as_of
  from ai_impact.fct_reply_outcomes o
  left join ai_impact.dim_location d using (location_id)
  left join (select location_id, count(*) as conversations
             from ai_impact.fct_reply_detail group by location_id) c using (location_id);

grant select on public.ai_reply_outcomes to anon, authenticated;
