# Salesforce Canvas SSO — admin setup

Goal: opening the AI Impact tab in Salesforce logs the user into the dashboard
automatically (no password), with their SF profile deciding whether they see $
amounts (`exec`) or the operational view (`ops`). Enforced in the database.

## 1. Vercel env vars (Vercel project → Settings → Environment Variables)
| Var | Value |
|---|---|
| `SF_CONSUMER_SECRET` | Consumer Secret from the Connected App (step 2) |
| `SUPABASE_JWT_SECRET` | Supabase dashboard → Project Settings → API → JWT Secret |
| `ROLE_MAP_JSON` | e.g. `{"mike.perticone@bigthinkcapital.com":"exec","brian@bigthinkcapital.com":"exec","*":"ops"}` — keys are emails or SF profile IDs; `*` is the default role |

Redeploy after setting (Deployments → ⋯ → Redeploy).

## 2. Connected App (SF Setup → App Manager → New Connected App)
- Name: `AI Impact Canvas` — contact email: yours
- Enable OAuth Settings: ON; callback `https://<your-vercel-domain>/api/canvas-auth`; scopes: `openid`
- **Canvas App Settings**: Canvas: ON
  - Canvas App URL: `https://<your-vercel-domain>/api/canvas-auth`
  - Access Method: **Signed Request (POST)**
  - Locations: **Visualforce Page** (and/or Lightning Component)
- Save → **Manage Consumer Details** → copy the **Consumer Secret** → Vercel env.
- Manage → **Permitted Users: Admin approved users are pre-authorized** →
  Profiles: add every profile that should see the tab (both exec and ops).

## 3. Host page (SF Setup → Visualforce Pages → New)
```xml
<apex:page showHeader="true" sidebar="false">
  <apex:canvasApp applicationName="AI_Impact_Canvas" width="100%" height="2000px"/>
</apex:page>
```
(applicationName = the Connected App API name.) Then create a **Visualforce Tab**
for this page, add it to the app, and set tab visibility per profile.

## 4. Test (BEFORE lockdown)
- Open the tab as an exec-mapped user → full dashboard, `live` pill.
- Open as an ops-mapped user → Replies + Records only, no $ anywhere.
- Open the raw Vercel URL in an incognito window → still shows everything
  (anon is still allowed at this stage — that's expected).

## 5. Lockdown (the final switch — tell Claude "GO")
Applying `supabase/migrations/0015_LOCKDOWN...sql` + the snapshot-zero commit:
- public URL → "open inside Salesforce" message, zero data for anon
- $ and PII become reachable only through Salesforce-minted tokens
