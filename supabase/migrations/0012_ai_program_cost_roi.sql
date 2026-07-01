-- 0012_ai_program_cost_roi.sql
-- ROI panel plumbing: single-row program-cost config + anon-readable view.
-- The dashboard renders the ROI card only when monthly_usd > 0, so the card stays
-- hidden until real spend data is loaded. To activate:
--   insert into ai_impact.ai_program_cost (monthly_usd, as_of, note)
--   values (XXXX, current_date, 'OpenAI + Anthropic + OpenRouter')
--   on conflict (id) do update set monthly_usd=excluded.monthly_usd,
--     as_of=excluded.as_of, note=excluded.note;
-- Applied to project rrdgghwxuincfengkjyd as migration `ai_program_cost_roi`.

create table if not exists ai_impact.ai_program_cost (
  id          int primary key default 1 check (id = 1),
  monthly_usd numeric not null,
  as_of       date,
  note        text
);

drop view if exists public.ai_roi;
create view public.ai_roi as
  select monthly_usd, as_of, note from ai_impact.ai_program_cost where id = 1;

grant select on public.ai_roi to anon, authenticated;
