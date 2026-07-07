-- 0015 LOCKDOWN — DO NOT APPLY until Canvas SSO is verified working inside
-- Salesforce (exec user sees $, ops user doesn't). Applying this:
--   1) removes the anon allowance from can_see_money(), and
--   2) revokes anon SELECT on every dashboard view,
-- which makes the public URL show NOTHING without a Salesforce-minted token.
-- Pair with the dashboard commit that zeroes the baked snapshot.

create or replace function public.can_see_money()
returns boolean
language sql stable
as $$
  select coalesce(nullif(current_setting('request.jwt.claims', true), ''), '') = ''
      or coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb->>'app_role', '') = 'exec';
$$;

revoke select on public.ai_kpi_summary,
  public.ai_commission_by_month, public.ai_commission_by_bot,
  public.ai_commission_by_bot_month, public.ai_roi,
  public.ai_replies_by_sentiment, public.ai_replies_by_month,
  public.ai_reply_outcomes, public.ai_reply_detail,
  public.ai_reply_detail_months, public.ai_reconciliation
from anon;
