# CLAUDE.md — AI Bot Impact Tracker

Context handoff for continuing this project in Claude Code. Read this + `README.md` first.

## What this is
Measures the business impact of BTC's in-house AI bots (run through the **n8n-2**
instance) by attributing Salesforce commission to them via `Opportunity.Assisted_by__c`.
Output is a Vercel dashboard (`index.html`) reading a Supabase mart, embedded in
Salesforce as a web tab.

## Current state — DONE
- **Headline (production, validated 2026-06-16):** $952,764.20 commission influenced,
  325 funded deals, ~$2,932/deal, 10 months (2025-09 → 2026-06). Basis:
  `Opportunity.csbs__Commission_Amount__c` on funded deals tagged with an in-house AI value.
- **Mart is LIVE** in Supabase project `rrdgghwxuincfengkjyd`, schema `ai_impact`:
  `dim_bot`, `fct_commission_by_month`, `fct_commission_by_bot`, `kpi_summary`.
  Migrations in `supabase/migrations/`.
- **ETL is BUILT.** `public.refresh_ai_impact_mart(p_kpis, p_by_month, p_by_bot)`
  (SECURITY DEFINER, service_role only) deployed + validated. Nightly n8n workflow
  `n8n/etl_ai_impact_nightly.json` for **api.btc** (import per `n8n/README.md`).
  Per-bot is now **exact per-value rows** — the old "Other in-house" bucket is gone.
- **Live dashboard wired.** Read-only public views (`public.ai_kpi_summary`,
  `ai_commission_by_month`, `ai_commission_by_bot`) granted to `anon`. `index.html`
  reads them live (URL + anon key embedded) with the baked snapshot as fallback.

## Whitelist (n8n-2 in-house only — vendors/humans excluded)
`Inbox Manager - AI`, `Marketing - EW`, `Marketing - MA`, `Marketing - AR`,
`Marketing - FT`, `Marketing - GS`, `Marketing - LP`, `Marketing - OC`,
`Marketing - JB`, `NYS Auto DNQ`
(GS / LP / NYS currently have 0 funded-tagged deals.)

## How attribution works (verified facts)
- `Assisted_by__c` is a **multipicklist** on Lead AND Opportunity. n8n-2 bots PATCH it.
- **Overwrite, not append** — bots write a single literal, so the tag = the *last*
  milestone-writer. It's "influenced," not full history. Verified: per-value sums
  partition cleanly to the 325/$952,764.20 headline (no double-counting).
- **`Marketing - EW` is contaminated** — Olivia's hot-lead branch tags EW (clone
  leftover from Emma Wilson). Per-persona EW unreliable until fixed at source.
- Meetings live on the **Lead** (`Meeting_booked_time__c`). `Opportunity.Amount` is
  garbage — use `csbs__Commission_Amount__c`.

## Source query (reproducible)
```sql
SELECT SUM(csbs__Commission_Amount__c), COUNT(Id)
FROM Opportunity
WHERE StageName='Funded' AND csbs__Commission_Amount__c != null
  AND Assisted_by__c INCLUDES ('Inbox Manager - AI','Marketing - EW','Marketing - MA',
    'Marketing - AR','Marketing - FT','Marketing - GS','Marketing - LP','Marketing - OC',
    'Marketing - JB','NYS Auto DNQ')
```
Monthly: `GROUP BY CALENDAR_YEAR/MONTH(csbs__Funded_Date__c)`. Per-bot: one `SUM` per
value. The ETL Code node reproduces all three from a single raw pull.

## What's LEFT (next tasks)
1. **Deploy** — import the n8n workflow on api.btc (create the `Supabase ai_impact
   (service_role)` Custom Auth credential first — see `n8n/README.md`), run once,
   activate. Then deploy `index.html` to Vercel and embed in Salesforce via Web Tab.
2. **Replies-sentiment tier — PoC built, pending deploy.** Mart: `ai_impact.fct_replies`,
   `dim_location`, `refresh_ai_impact_replies()` RPC, anon views (migration 0003).
   Workflow `n8n/etl_ai_replies_nightly.json`: GHL `conversations/search` → Claude Haiku
   classify → Supabase RPC. Megan sub-account `htgHvVfBZ1WH3UpQoxaa` (= `Marketing - MA`).
   GHL join to Salesforce is by **email/phone** (GHL stores only the SF *rep* User id in a
   custom field, not the Lead/Opp). To finish: create `Anthropic (AI Impact)` n8n credential
   (Custom Auth: `x-api-key` + `anthropic-version: 2023-06-01`), import + run, then scale to
   all sub-accounts via a GHL OAuth app and add the per-lead SF join (positive→funded).
3. **Fix `Marketing - EW` clone** at the n8n-2 source, then per-persona becomes trustworthy.

## Environment / MCPs
- **Salesforce** (read-only via MCP), **n8n api.btc** (read-only MCP — workflow must be
  imported manually), **n8n-2** (read-only), **Supabase** (project `rrdgghwxuincfengkjyd`),
  **GitHub** (this repo). The api.btc Salesforce credential is `Salesforce Brian`
  (`E7YUDEqmGx2oThas`).

## Repo map
```
index.html                                            dashboard (Vercel root)
README.md                                             build status + numbers
CLAUDE.md                                             this file
supabase/migrations/0001_init_mart.sql                schema + dim_bot
supabase/migrations/0002_etl_rpc_and_public_views.sql ETL RPC + anon views
n8n/etl_ai_impact_nightly.json                        nightly ETL workflow
n8n/README.md                                         ETL deploy steps
docs/plan.md                                          phased build plan
```
