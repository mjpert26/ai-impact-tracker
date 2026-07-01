# AI Bot Impact Tracker

Measures the business impact of BTC's in-house AI bots by attributing Salesforce
commission to them via `Opportunity.Assisted_by__c`. A Vercel dashboard
(`index.html`) reads a Supabase mart fed by nightly n8n ETLs; to be embedded in
Salesforce as a Web Tab.

## Headline (live, reconciled 2026-07-01)

| Metric | Value |
| --- | --- |
| Commission influenced | **$1,012,574.47** |
| Funded deals | **355** |
| Avg / deal | **$2,852** |
| Funnel | 8,721 leads → 1,301 meetings → 355 funded |
| Velocity | median **9 days** to fund · 68% within 30 |
| Months tracked | 10 (2025-09 → 2026-06) |

Scope: **in-house AI bots only** (Emma, Megan, Olivia, Faith, Anne, Jasmine, Gianna,
Lauren, Inbox Manager). Vendor/tool assists (Apten, Instantly, TextUs), the generic
"Marketing" tag, call-center and human assists are deliberately excluded. Per-bot and
per-month sums reconcile to the headline to the penny (`public.ai_reconciliation`).

## Architecture

```
Salesforce ──(06:15 SOQL)──▶ refresh_ai_impact_mart ──▶ ai_impact.{kpi, by_month, by_bot}
GoHighLevel (9 sub-accounts) ──(06:45 + hourly classify)──▶ fct_replies / fct_reply_outcomes /
     │  cursor-paginated; 14,278 conversations (all 2026)     fct_reply_detail (+ SF funded join)
     ▼
public anon views ──▶ index.html (live mode → baked snapshot fallback) ──▶ Vercel (main)
```

## Dashboard
Four tabs: **Scorecard** (scale/keep/cut verdicts + pipeline funnel + velocity),
**Commission** (cumulative curve, monthly bars, bot leaderboard), **Replies**
(sentiment mix, per-bot engagement), **Records** (every 2026 conversation,
month-paged, searchable, funded-only toggle — contains customer PII; gate before
sharing externally). Exec KPI band with MoM deltas + sparkline, data-freshness badge,
one-click PDF export, methodology & definitions panel.

## Status
- ✅ Mart, ETLs, dashboard, 2026 records backfill, sentiment classifier — live.
- ✅ Attribution audited end-to-end on the production bot instance (every active bot
  writes its correct tag; the 2025-06 EW mis-tag was fixed at source 2026-06-29 and
  its residual measured immaterial).
- ⏳ ROI panel (needs monthly AI spend), ETL failure alerting, Salesforce Web Tab
  embed + access gating, secret rotation.

## Repo map

```
index.html                                   dashboard (Vercel root, self-contained)
supabase/migrations/0001–0011                schema, RPCs, views (mirror of applied state)
n8n/etl_ai_impact_nightly.json               nightly commission ETL (api.btc)
n8n/etl_ai_replies_all_bots.json             nightly GHL replies+funded+detail ETL (tokens redacted)
n8n/etl_ai_2026_backfill.json                one-time 2026 records backfill (done; tokens redacted)
n8n/etl_ai_sentiment_classifier.json         hourly sentiment classifier
n8n/README.md                                ETL deploy/credential steps
docs/plan.md                                 phased build plan (historical)
CLAUDE.md                                    context handoff — read this first
```
