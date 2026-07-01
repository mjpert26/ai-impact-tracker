# CLAUDE.md — AI Bot Impact Tracker

Context handoff for continuing this project in Claude Code. Read this + `README.md` first.

## What this is
Measures the business impact of BTC's in-house AI bots by attributing Salesforce
commission to them via `Opportunity.Assisted_by__c`. A Vercel dashboard (`index.html`,
repo root, auto-deploys from `main`) reads a Supabase mart (project
`rrdgghwxuincfengkjyd`, schema `ai_impact`) fed by nightly n8n ETLs on
**api.bigthinkcapital.com**. To be embedded in Salesforce as a Web Tab (that's also
the planned access gate — the page is currently public, PII included; owner accepted
this explicitly for now).

## Current state (2026-07-01) — launch-ready
- **Headline: $1,012,574.47 / 355 funded deals** (2025-09 → 2026-06), avg $2,852/deal.
  Reconciles to the penny: per-bot and per-month sums == headline (guarded by
  `public.ai_reconciliation`, `reconciled` must stay true).
- **Funnel:** 8,721 leads worked → 1,301 meetings → 355 funded. **Velocity:** median
  9 days to fund, 68% within 30 (defensible; do NOT headline the ~19× vs non-AI
  comparison — confounded by last-writer attribution).
- **Records:** 14,278 conversations (all of 2026, all 9 bots) backfilled from GHL into
  `ai_impact.fct_reply_detail`; month-by-month lazy-load, live search, funded-only
  toggle. 147 conversations tie to funded $ via email join (`sf_funded_email`).
- **Sentiment:** hourly classifier workflow chews the backlog (800/run, Claude Haiku),
  then keeps new records classified. Once complete, consider pointing the Replies
  sentiment chart at the full detail table instead of the rolling window.
- **Dashboard tabs:** Scorecard (default; verdicts + funnel), Commission, Replies,
  Records. Exec KPI band w/ MoM deltas + sparkline, freshness badge, PDF export
  (print CSS), methodology panel (incl. explicit scope statement). Mobile-checked.

## n8n workflow fleet (api.bigthinkcapital.com, project tPYBDOQFrX8Bp1vZ)
| Workflow | ID | State |
|---|---|---|
| Commission ETL (SF → mart) | `2d7GZxMOPALS1UEe` | active, 06:15 UTC |
| Replies + Funded + Detail (GHL+SF → mart) | `lICbCAT6RmD5gwzW` | active, 06:45 UTC |
| Sentiment Classifier (hourly :20) | `mYvz6YmYul3yL4RC` | verify Active toggle is on |
| 2026 Backfill (one-time, done) | `p4Xn0p5x545yy4xL` | inactive; job finished |
| old Replies (superseded) | `ZFwC1XNpiHPoVOwh` | deactivated |

Credentials referenced by ID: Anthropic `tkrE610QOjpv1yIn`, Salesforce Brian
`E7YUDEqmGx2oThas`, Supabase service_role `uB48zHhGKViNKUEe`. Repo copies of all
workflows in `n8n/` (GHL `pit-` tokens redacted; real ones live in the n8n nodes).

## Whitelist (in-house AI only — vendors/humans excluded)
`Inbox Manager - AI`, `Marketing - EW/MA/AR/FT/GS/LP/OC/JB`, `NYS Auto DNQ`.
Explicitly NOT counted: Apten, Instantly, TextUs, generic "Marketing", Call Center,
humans. A marketing SF report counting all tags shows ~$2.04M — that's scope, not a
discrepancy (shared bot values match within 1–3%; their "equals" filters also drop
multi-tagged deals — ours uses INCLUDES).

## Attribution facts (verified)
- `Assisted_by__c` is a multipicklist on Lead AND Opportunity; bots overwrite a single
  literal → tag = last milestone-writer ("influenced", not full attribution).
- **Megan (MA) tags Opportunities, not Leads** (9 tagged leads vs 105 funded opps) —
  never use SF-lead counts as her denominator; per-bot "reply rates" are NOT
  defensible with current data.
- **EW saga CLOSED (2026-07-01):** Gianna's bot wrote `Marketing - EW` until fixed at
  source 2026-06-29 (by Abdus, on ai.bigthinkcapital.com). Residual immaterial —
  Gianna's sub-account = 41 contacts, 0 funded matches (confirmed independently by
  Abdus: 41 contacts, 10 looped in). No re-tag. The old "Olivia clone" diagnosis was
  wrong (that branch was dead code). Full live-path audit of all active bots on ai.
  passed — every bot writes its correct tag.
- Gianna's real problem is **deliverability** (replies to odd `g.scavina` aliases get
  filtered) — flagged to Abdus, fix pending on their side.

## Bot instances (3 servers — do not confuse)
- **ai.bigthinkcapital.com = 161.35.109.194** (`n8n-2-new`) — LIVE bots, ~255 wfs.
- n8n-2.bigthinkcapital.com = 159.223.178.50 (`n8n-dos`) — OLD bots, retired traffic.
- api.bigthinkcapital.com = 174.138.63.47 — automation + our ETLs.

Access via MCP connectors only (sandbox egress is blocked to these hosts):
`n8n_api_btc_MCP` (REST, reliable), SSH MCPs for the bot boxes (n8n MCP-trigger
based — flaky, tools drop between turns; reload via ToolSearch, ask user to
reconnect if gone). The `.../mcp/ai-btc-n8n-mcp` toolHttpRequest connector returns
empty `{success:true}` — ignore it. n8n MCP `create_workflow`/`update_workflow` are
broken (Zod rejects nodes array) → paste-and-run JSON imports instead.

## GHL API notes (hard-won)
- Per-sub-account Private Integration `pit-` tokens (9 bots; map = `dim_location`).
  Agency PIT is 401-blocked from sub-account conversations; marketplace OAuth app is
  card-gated — abandoned.
- `conversations/search`: no `nextPageUrl`, but **`startAfterDate` (epoch ms) cursors
  backward** — that's how the 2026 backfill pulled 14k. Response has `total`.
  `monetaryValue` on opps = 0 (use SF for $). GHL "won" = handoff, NOT funded.
- Backfill captured ALL conversations (no direction filter) — last_message may be the
  bot's own pitch; classifier prompt handles this (outbound → Neutral).

## Supabase mart (project rrdgghwxuincfengkjyd)
Tables: `dim_bot`, `dim_location`, `fct_commission_by_month/by_bot`, `kpi_summary`,
`fct_replies`, `fct_reply_outcomes`, `fct_reply_detail` (14k, PII), `sf_funded_email`.
Anon views: `ai_kpi_summary`, `ai_commission_by_month/by_bot`,
`ai_replies_by_sentiment`, `ai_replies_by_month`, `ai_reply_outcomes` (+conversations),
`ai_reply_detail` (PII!), `ai_reply_detail_months`, `ai_reconciliation`.
Service-role RPCs: `refresh_ai_impact_mart`, `refresh_ai_impact_replies`,
`refresh_ai_impact_reply_outcomes`, `refresh_ai_impact_reply_detail` (ACCUMULATES,
upsert by location+contact — never wipes), `get_unclassified_replies`,
`set_reply_sentiments`. Migrations 0001–0011 in `supabase/migrations/` mirror what's
applied.

## Open items (post-launch)
1. **ROI panel** — blocked on monthly AI spend (OpenAI + Anthropic + OpenRouter; bots
   use a mix — gpt-5-mini/nano bulk, claude-sonnet/opus, gemini via OpenRouter).
   Angle: in-house $1.01M ≈ Apten+Instantly+TextUs combined ($868K) minus invoices.
2. **ETL failure alerting** — waiting on user choice: Slack webhook vs email.
3. **SF Web Tab embed** + access gating (current plan; page is public w/ PII).
4. Point Replies sentiment chart at full classified detail (after backlog clears).
5. Secret hygiene: revert ai. box root-password SSH to key-only, rotate `pit-` tokens.
6. Workflow graveyard cleanup on ai. (dozens of inactive copies) — with Abdus.

## Working conventions
- Git identity: `git config user.email noreply@anthropic.com && git config user.name
  Claude` (a stop-hook enforces this). Branch `claude/inspiring-allen-iskb3e`, then
  ff-merge to `main` (Vercel auto-deploys main).
- index.html is a single self-contained file; after editing, extract `<script>` and
  `node --check` it. Screenshot via playwright-core +
  `/opt/pw-browsers/chromium-1194/chrome-linux/chrome` (offline = snapshot fallback).
- Salesforce MCP is read-only; large SOQL results get saved to disk — parse the file
  (top-level shape: `[{records: [...]}]`, latin-1 encoding).
