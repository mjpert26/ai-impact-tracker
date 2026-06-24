-- 0006_dim_location_rollout.sql
-- Seed the GHL location -> bot map for the full rollout (all bot sub-accounts).
-- Location IDs captured from the agency token's /locations/search (exec 844313).
-- Renewals bots (Erica Monroe, Rachel Duncan, Rebecca Miller, RAID-Rachel) and
-- test/snapshot accounts are intentionally excluded (not in the commission whitelist).

insert into ai_impact.dim_location (location_id, assisted_by_value, bot_name) values
  ('htgHvVfBZ1WH3UpQoxaa', 'Marketing - MA',     'Megan Anderson'),
  ('kuO6oj3iKtz5PQUu4WZ0', 'Marketing - AR',     'Anne Robinson'),
  ('96LqPx5WmcloFPZZe1hy', 'Marketing - FT',     'Faith Thompson'),
  ('sEjuiURUKweddSIqjcjT', 'Marketing - GS',     'Gianna Scavina'),
  ('1lP8kn6tPERda0fT4zVT', 'Marketing - OC',     'Olivia'),
  ('PXyGarBjp2lwuVBdA81P', 'Marketing - EW',     'Emma Wilson'),
  ('NsDKFz05b8v0P86nTc2o', 'Marketing - JB',     'Jasmine Bennett'),
  ('qT3OTNWfVeq0tNWklhMK', 'Marketing - LP',     'Lauren Parker'),
  ('XAF0RGBybE8RoesJhSiz', 'Inbox Manager - AI', 'Inbox Manager - Hannah Lake')
on conflict (location_id) do update
  set assisted_by_value = excluded.assisted_by_value,
      bot_name          = excluded.bot_name;

-- Other captured Location IDs (not mapped to a commission bot — renewals/test):
--   Erica Monroe (Renewals)        ClVzQMmd37ggwYNhDJFu
--   Rachel Duncan (Renewals)       0xyjsACIAv0pQ8LnkWR4
--   Rebecca Miller (Renewals)      eMYiruhawaYjIlQoiyaA
--   Big Think Capital RAID - Rachel MPgSx7qQIsY4SpSA1CR8
--   Info bot                       fyvjEcFXBSYXHyr2yqTl
--   Instantly Bot                  NLny607atNQ60S0AZKhh
--   Emily Carter                   W4LnJRkASiljfRJ7WjGv
--   TEST Account                   Rkm9z0QJSgHuRxj6i18d
--   Tester Account                 JpRjMFeUoB0WFn5aOpEL
--   Master Snapshot                G0qMScZTPQcRFnWgDVHX
--   Old Olivia - Not In Use        s0XokfbVw8hypsdIiluZ
-- GHL company (agency) id: JBp4sotf0dqjfQE1F5jd
