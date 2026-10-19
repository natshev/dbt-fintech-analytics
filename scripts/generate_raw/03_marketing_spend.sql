-- raw_marketing_spend: daily ad spend (source emulation), one row per campaign x day.
-- spend = channel base +-30%; impressions and clicks are NULL for partner_store (offline channel).
-- Re-runnable and reproducible: table is recreated, setseed() fixes random().

drop table if exists raw.raw_marketing_spend;
create table raw.raw_marketing_spend(
    campaign_id int,
    spend_date date,
    spend_amount numeric(12,2),
    impressions int,
    clicks int
);
select setseed(0.42);
insert into raw.raw_marketing_spend (campaign_id, spend_date, spend_amount, impressions, clicks)
-- days: one row per campaign per day between start_date and end_date
with days as (
select
	c.campaign_id,
	c.channel,
	d.spend_date::date as spend_date
from
	raw.raw_campaigns c
cross join lateral generate_series(c.start_date, c.end_date, interval '1 day') as d(spend_date)
),
-- spend: daily spend = channel base +-30%
spend as (
select
	campaign_id,
	spend_date,
	channel,
	round((
        case channel 
        when 'google' then 5000
		when 'facebook' then 4000
		when 'tiktok' then 3000
		when 'partner_store' then 2000
	end * (0.7 + random() * 0.6)
)::numeric, 2) as spend_amount
from
	days
),
-- with_impressions: 8-12 impressions per peso; NULL for partner_store (offline channel)
with_impressions as (
select
	campaign_id,
	spend_date,
	channel,
	spend_amount,
	case
		when channel <> 'partner_store' then round(spend_amount * (8 + random() * 4))::int
	end as impressions
from
	spend
),
-- final: clicks = 1-3% of impressions (NULL stays NULL); columns in table order
final as (
select
	campaign_id,
	spend_date,
	spend_amount,
	impressions,
	round(impressions * (0.01 + random() * 0.02))::int as clicks
from with_impressions
)
select
	*
from
	final;


