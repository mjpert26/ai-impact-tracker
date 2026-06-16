# n8n — Nightly Mart ETL

`etl_ai_impact_nightly.json` refreshes the `ai_impact` mart in Supabase
(project `rrdgghwxuincfengkjyd`) every night. It runs on the **api.btc**
instance (`api.bigthinkcapital.com`), **not** n8n-2 — n8n-2 runs the bots that
write `Assisted_by__c`; this job only reads Salesforce and writes the mart.

## What it does

1. **Schedule Trigger** — nightly at 06:15 UTC.
2. **Pull funded AI-assisted opps** (Salesforce node, `Salesforce Brian`
   OAuth cred `E7YUDEqmGx2oThas`) — one SOQL `search` returning every funded
   opp with commission tagged with any whitelisted in-house bot value.
3. **Aggregate mart payloads** (Code node) — builds `p_kpis`, `p_by_month`
   (deduped, each opp once) and `p_by_bot` (per-value, INCLUDES semantics).
4. **Upsert mart** (HTTP node) — `POST /rest/v1/rpc/refresh_ai_impact_mart`,
   which replaces `fct_*` and upserts `kpi_summary` in one transaction. This is
   what retires the old "Other in-house" bucket in favour of exact per-bot rows.

The Code node reproduces the documented SOQL methodology exactly; verified
2026-06-16 to reproduce $952,764.20 / 325 funded deals.

## Deploy (one-time, manual import — the api.btc MCP is read-only)

1. **Create the Supabase write credential** in api.btc n8n:
   - Type: **Custom Auth** (`httpCustomAuth`)
   - Name: `Supabase ai_impact (service_role)`
   - JSON:
     ```json
     {
       "headers": {
         "apikey": "<SUPABASE_SERVICE_ROLE_KEY>",
         "Authorization": "Bearer <SUPABASE_SERVICE_ROLE_KEY>"
       }
     }
     ```
     Get the service_role key from Supabase → Project Settings → API. It is a
     secret — it is **not** committed to this repo.
2. **Import** `etl_ai_impact_nightly.json` (Workflows → Import from File).
3. On the **Upsert mart** node, select the credential created in step 1
   (the imported `id` is a placeholder).
4. Confirm the **Pull funded AI-assisted opps** node still points at the
   `Salesforce Brian` credential.
5. **Execute Workflow** once to backfill, then toggle **Active**.

## Verify

```sql
select * from ai_impact.kpi_summary order by metric;
select * from ai_impact.fct_commission_by_bot order by commission_amt desc;
```

## Scale note

The pull is bounded by funded + AI-tagged opps (~325 today). If that set ever
approaches Salesforce's single-batch query ceiling, split the Salesforce node
into per-value aggregate `SUM`/`COUNT` queries (the methodology is identical —
per-value sums partition cleanly because `Assisted_by__c` is overwrite-only).
