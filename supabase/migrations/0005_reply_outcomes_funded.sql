-- 0005_reply_outcomes_funded.sql
-- True Salesforce-funded outcome on the replies tier: positive reply -> funded commission.
-- The GHL "won" status is only a handoff to the funding manager, NOT a funded deal;
-- the real funded $ lives in Salesforce (Lead.ConvertedOpportunity). Applied to
-- project rrdgghwxuincfengkjyd as migration `reply_outcomes_funded`.

alter table ai_impact.fct_reply_outcomes
  add column if not exists positive_funded   integer,
  add column if not exists funded_commission numeric;

-- 5-arg overload (the 3-arg version is kept for backward compatibility).
create or replace function public.refresh_ai_impact_reply_outcomes(
  p_location          text,
  p_positive_replies  int,
  p_positive_advanced int,
  p_positive_funded   int,
  p_funded_commission numeric
) returns jsonb
language plpgsql
security definer
set search_path = ai_impact, public
as $$
begin
  insert into ai_impact.fct_reply_outcomes
    (location_id, as_of, positive_replies, positive_advanced, positive_funded, funded_commission)
  values
    (p_location, current_date, coalesce(p_positive_replies,0), coalesce(p_positive_advanced,0),
     coalesce(p_positive_funded,0), coalesce(p_funded_commission,0))
  on conflict (location_id) do update
    set as_of = excluded.as_of,
        positive_replies  = excluded.positive_replies,
        positive_advanced = excluded.positive_advanced,
        positive_funded   = excluded.positive_funded,
        funded_commission = excluded.funded_commission;

  return jsonb_build_object('ok', true, 'location', p_location,
    'positive_replies', p_positive_replies, 'positive_advanced', p_positive_advanced,
    'positive_funded', p_positive_funded, 'funded_commission', p_funded_commission);
end;
$$;

revoke all on function public.refresh_ai_impact_reply_outcomes(text,int,int,int,numeric) from public, anon, authenticated;
grant execute on function public.refresh_ai_impact_reply_outcomes(text,int,int,int,numeric) to service_role;

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
         o.as_of
  from ai_impact.fct_reply_outcomes o
  left join ai_impact.dim_location d using (location_id);

grant select on public.ai_reply_outcomes to anon, authenticated;
