-- 0004_reply_outcomes.sql
-- Positive-reply -> won-opportunity outcomes (GHL contactId join).
-- Applied to project rrdgghwxuincfengkjyd as migration `reply_outcomes`.

create table if not exists ai_impact.fct_reply_outcomes (
  location_id       text primary key,
  as_of             date,
  positive_replies  integer,
  positive_advanced integer
);

create or replace function public.refresh_ai_impact_reply_outcomes(
  p_location          text,
  p_positive_replies  int,
  p_positive_advanced int
) returns jsonb
language plpgsql
security definer
set search_path = ai_impact, public
as $$
begin
  insert into ai_impact.fct_reply_outcomes (location_id, as_of, positive_replies, positive_advanced)
  values (p_location, current_date, coalesce(p_positive_replies,0), coalesce(p_positive_advanced,0))
  on conflict (location_id) do update
    set as_of = excluded.as_of,
        positive_replies = excluded.positive_replies,
        positive_advanced = excluded.positive_advanced;

  return jsonb_build_object('ok', true, 'location', p_location,
    'positive_replies', p_positive_replies, 'positive_advanced', p_positive_advanced);
end;
$$;

revoke all on function public.refresh_ai_impact_reply_outcomes(text,int,int) from public, anon, authenticated;
grant execute on function public.refresh_ai_impact_reply_outcomes(text,int,int) to service_role;

-- Public read view: per-bot positive-reply -> won-deal conversion.
create or replace view public.ai_reply_outcomes as
  select coalesce(d.bot_name, o.location_id) as bot_name,
         d.assisted_by_value,
         o.positive_replies,
         o.positive_advanced,
         case when o.positive_replies > 0
              then round(100.0 * o.positive_advanced / o.positive_replies)
              else 0 end as advanced_pct,
         o.as_of
  from ai_impact.fct_reply_outcomes o
  left join ai_impact.dim_location d using (location_id);

grant select on public.ai_reply_outcomes to anon, authenticated;
