-- 0001_init_mart.sql
-- AI Bot Impact Tracker — mart schema + bot dimension.
-- Mirrors the live `ai_impact_mart_init` migration already applied to project
-- pvvrsvfucwncqseetbhe. Idempotent so it is safe to (re)run against a fresh DB.

create schema if not exists ai_impact;

-- Dimension: one row per in-house n8n-2 bot value written to Opportunity.Assisted_by__c.
create table if not exists ai_impact.dim_bot (
  assisted_by_value text primary key,
  bot_name          text,
  channel           text,
  bot_type          text
);

-- Fact: commission influenced per payout month (deduped — each opp counted once).
create table if not exists ai_impact.fct_commission_by_month (
  payout_month   text primary key,   -- 'YYYY-MM'
  commission_amt numeric,
  distinct_opps  integer
);

-- Fact: commission influenced per bot value (exact per-value rows; INCLUDES semantics).
create table if not exists ai_impact.fct_commission_by_bot (
  assisted_by_value text primary key,
  commission_amt    numeric,
  distinct_opps     integer,
  note              text
);

-- Headline KPIs (one row per metric).
create table if not exists ai_impact.kpi_summary (
  metric text primary key,
  value  numeric,
  as_of  date
);

-- Bot dimension seed. The in-house n8n-2 whitelist (vendors/humans excluded).
insert into ai_impact.dim_bot (assisted_by_value, bot_name, channel, bot_type) values
  ('Inbox Manager - AI', 'Inbox Manager (all personas, aggregate)',                       'email',     'in_house_n8n2'),
  ('Marketing - EW',     'Emma Wilson (contaminated: Olivia hot-lead clone leftover)',     'email/sms', 'in_house_n8n2'),
  ('Marketing - MA',     'Megan Anderson',                                                 'email/sms', 'in_house_n8n2'),
  ('Marketing - AR',     'Anne Robinson',                                                  'email/sms', 'in_house_n8n2'),
  ('Marketing - FT',     'Faith Thompson',                                                 'email/sms', 'in_house_n8n2'),
  ('Marketing - GS',     'Gianna Scavina / Help & Info',                                   'email/sms', 'in_house_n8n2'),
  ('Marketing - LP',     'Lauren Parker / New Deals Bot',                                  'email/sms', 'in_house_n8n2'),
  ('Marketing - OC',     'Olivia',                                                         'email/sms', 'in_house_n8n2'),
  ('Marketing - JB',     'Jasmine Bennett / Reactivation Bot',                             'email/sms', 'in_house_n8n2'),
  ('NYS Auto DNQ',       'DND / Auto-DQ automation',                                       '-',         'in_house_n8n2')
on conflict (assisted_by_value) do update
  set bot_name = excluded.bot_name,
      channel  = excluded.channel,
      bot_type = excluded.bot_type;
