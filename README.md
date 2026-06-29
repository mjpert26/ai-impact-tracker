# AI Bot Impact Tracker

Measures the business impact of BTC's in-house AI bots (run on the **n8n-2**
instance) by attributing Salesforce commission to them via
`Opportunity.Assisted_by__c`. A Vercel dashboard (`index.html`) reads a Supabase
mart and is embedded in Salesforce as a web tab.

## Headline (validated 2026-06-16)

| Metric | Value |
| --- | --- |
| Commission influenced | **$952,764.20** |
| Funded deals | **325** |
| Avg / deal | **$2,931.58** |
| Months tracked | **10** (2025-09 → 2026-06) |

Per-bot (exact per-value, INCLUDES semantics — sums back to the headline):

| Bot value | Commission | Opps |
| --- | --- | --- |
| Marketing - EW (Emma Wilson — *contaminated*) | $335,268.67 | 76 |
| Marketing - MA (Megan Anderson) | $263,775.96 | 101 |
| Marketing - OC (Olivia) | $187,671.43 | 74 |
| Inbox Manager - AI (aggregate) | $126,890.17 | 35 |
| Marketing - FT (Faith Thompson) | $21,638.19 | 30 |
| Marketing - AR (Anne Robinson) | $16,953.06 | 8 |
| Marketing - JB (Jasmine Bennett) | $566.72 | 1 |

> "Commission influenced" = the deal's commission attributed to the **last
> milestone-writer** in `Assisted_by__c` (bots overwrite a single literal). It
> is influence, not full attribution. **Marketing - EW** is contaminated by an
> Olivia hot-lead clone leftover and overstates Emma Wilson until fixed at the
> n8n-2 source.

## Architecture

```
Salesforce (Opportunity.Assisted_by__c, csbs__Commission_Amount__c)
   │   nightly SOQL  (api.btc n8n: n8n/etl_ai_impact_nightly.json)
   ▼
public.refresh_ai_impact_mart()  ── upserts ──▶  ai_impact.{fct_*, kpi_summary}
   │                                                     │
   │                                public read-only views (anon)
   ▼                                                     ▼
                          index.html  (live mode → snapshot fallback)
```

## Status

- ✅ **Mart** — live in Supabase project `rrdgghwxuincfengkjyd`, schema
  `ai_impact` (`dim_bot`, `fct_commission_by_month`, `fct_commission_by_bot`,
  `kpi_summary`). See `supabase/migrations/`.
- ✅ **ETL** — `public.refresh_ai_impact_mart()` RPC deployed and validated.
  Nightly n8n workflow built: `n8n/etl_ai_impact_nightly.json` (import on
  api.btc — see `n8n/README.md`). The old "Other in-house" bucket is retired in
  favour of exact per-bot rows.
- ✅ **Live dashboard** — read-only public views (`public.ai_kpi_summary`,
  `ai_commission_by_month`, `ai_commission_by_bot`) exposed to `anon`;
  `index.html` reads them live with the baked snapshot as fallback.
- ⏳ **Deploy** — Vercel static from repo root; embed in Salesforce via Web Tab
  iframe.
- ✅ **Replies + outcomes tier (LIVE, all 9 bots)** — nightly GHL→Claude workflow `n8n/etl_ai_replies_all_bots.json` (api.btc id `ZFwC1XNpiHPoVOwh`, active 06:45 UTC) loops all 9 bot sub-accounts: classifies inbound replies (Positive/Neutral/Negative/Opt-out), correlates positive repliers to **handed-off GHL opportunities** by `contactId`, and joins to **Salesforce funded commission** by email (`Lead.ConvertedOpportunity`). Mart: `fct_replies`, `fct_reply_outcomes`, `dim_location` (9 bots), RPCs + anon views (incl. per-bot `ai_reply_outcomes`). Dashboard **Replies tab** shows aggregate + per-bot breakdown live.
  - **Auth:** per-sub-account GHL Private Integration tokens (one per bot). The agency OAuth app route was abandoned — GHL agency PITs are 401-blocked from sub-account conversations, and the marketplace app forced a card-gated billing install unusable for internal accounts.
- ⏳ **Fix `Marketing - EW` clone** at the n8n-2 source.

## Repo map

```
index.html                                  dashboard (Vercel root)
supabase/migrations/0001_init_mart.sql       schema + dim_bot
supabase/migrations/0002_etl_rpc_and_public_views.sql   ETL RPC + anon views
n8n/etl_ai_impact_nightly.json               nightly commission ETL (api.btc)
n8n/etl_ai_replies_all_bots.json             nightly GHL replies+funded ETL, all 9 bots (api.btc; tokens redacted)
n8n/README.md                                ETL deploy/credential steps
supabase/migrations/0003_replies_tier.sql    replies tables + RPC + anon views
supabase/migrations/0004_reply_outcomes.sql  positive-reply -> won-opportunity outcomes
supabase/migrations/0005_reply_outcomes_funded.sql  Salesforce-funded outcome on replies tier
supabase/migrations/0006_dim_location_rollout.sql   GHL location -> bot map (9 bots)
supabase/migrations/0007_reply_detail.sql    per-record reply detail (Records tab; PII)
docs/plan.md                                 phased build plan
CLAUDE.md                                    context handoff
```
