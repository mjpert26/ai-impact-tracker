# Build plan

## Phase 1 — Mart  ✅ DONE
- `ai_impact` schema: `dim_bot`, `fct_commission_by_month`, `fct_commission_by_bot`,
  `kpi_summary` (`supabase/migrations/0001_init_mart.sql`).
- Seeded from the validated source query ($952,764.20 / 325).

## Phase 2 — ETL  ✅ DONE
- `public.refresh_ai_impact_mart(p_kpis, p_by_month, p_by_bot)` — SECURITY DEFINER,
  service_role only; whole-mart refresh in one transaction
  (`supabase/migrations/0002_etl_rpc_and_public_views.sql`).
- Nightly n8n workflow for **api.btc**: Schedule → Salesforce search → Code aggregate
  → HTTP RPC upsert (`n8n/etl_ai_impact_nightly.json`).
- Replaces the "Other in-house" bucket with exact per-value rows.
- **Remaining:** manual import on api.btc (read-only MCP can't deploy) — see `n8n/README.md`.

## Phase 3 — Live dashboard  ✅ DONE
- Read-only public views over the mart, granted to `anon`.
- `index.html` reads live via PostgREST (URL + anon key embedded), snapshot fallback.
- **Remaining:** deploy to Vercel (repo root) + embed in Salesforce Web Tab iframe.

## Phase 4 — Positive replies tier  ⏳ BLOCKED
- Classify inbound (Positive / Neutral / Negative / Opt-out). Conversations live in
  **GoHighLevel** — blocked on GHL access.

## Phase 5 — Fix `Marketing - EW` contamination  ⏳
- Olivia's hot-lead branch tags `Marketing - EW` (clone leftover). Fix at the n8n-2
  source so per-persona EW becomes trustworthy.
