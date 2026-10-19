-- raw_campaigns: marketing campaigns (source emulation), 10 static rows.
-- Re-runnable: table is dropped and recreated on every run.
-- Channel values are clean here; inconsistent casing appears in raw_loan_applications.

drop table if exists raw.raw_campaigns;
create table raw.raw_campaigns (
    campaign_id int,
    campaign_name varchar,
    channel varchar,
    start_date date,
    end_date date
);
insert into raw.raw_campaigns (campaign_id, campaign_name, channel, start_date, end_date)
values
(1, 'Facebook Launch Q4 2024', 'facebook', '2024-10-01', '2024-12-31'),
(2, 'Google Search Always On', 'google', '2024-10-01', '2026-09-30'),
(3, 'Partner Stores 2025', 'partner_store', '2025-01-01', '2025-12-31'),
(4, 'TikTok Awareness 2025', 'tiktok', '2025-03-01', '2025-08-31'),
(5, 'Facebook Summer 2025', 'facebook', '2025-04-01', '2025-06-30'),
(6, 'Facebook Holiday 2025', 'facebook', '2025-10-15', '2025-12-31'),
(7, 'TikTok Payday 2026', 'tiktok', '2026-01-01', '2026-06-30'),
(8, 'Partner Stores Electronics 2026', 'partner_store', '2026-01-01', '2026-09-30'),
(9, 'Facebook Retargeting 2026', 'facebook', '2026-03-01', '2026-09-30'),
(10, 'Google Display 2026', 'google', '2026-04-01', '2026-09-30');