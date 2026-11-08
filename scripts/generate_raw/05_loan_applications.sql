-- raw_loan_applications: loan applications (source emulation), one row per application.
-- Defect for staging: ~12% of channel values in mixed case or with leading/trailing spaces.
-- campaign_id is NULL for organic and when no campaign of the channel was running on the application date.
-- Re-runnable and reproducible: table is recreated, setseed() fixes random().

drop table if exists raw.raw_loan_applications;
create table raw.raw_loan_applications (
    application_id int,
    customer_id int,
    product_id int,
    campaign_id int,
    channel varchar,
    applied_at timestamp,
    requested_amount numeric(12,2),
    status varchar,
    decided_at timestamp
);
select
	setseed(0.45);
insert into raw.raw_loan_applications (application_id, customer_id, product_id, campaign_id, channel, applied_at, requested_amount, status, decided_at)
-- customers: import, registration date of each customer
with customers as (
select
	customer_id,
	created_at
from
	raw.raw_customers
),
-- campaigns: import, campaign channel and active dates
campaigns as (
select
	campaign_id,
	channel,
	start_date,
	end_date
from
	raw.raw_campaigns
),
-- ids: one row per application, random customer;
-- all random numbers are drawn here, before the join (row order after a join is not guaranteed)
ids as (
select
	g as application_id,
	(1 + floor(random() * 2000))::int as customer_id,
	random() as r_applied,
	random() as r_product,
	random() as r_channel,
	random() as r_status,
	random() as r_decided,
	random() as r_defect,
	random() as r_amount
from
	generate_series(1, 3000) as g
),
-- with_channel: application date, product, amount and clean channel
with_channel as (
select
	i.application_id,
	i.customer_id,
	-- applied_at: within 7 days after registration, capped by the period end
	c.created_at + i.r_applied * least(interval '7 days', timestamp '2026-10-01' - c.created_at) as applied_at,
	-- product_id: Cash 6M 30%, Cash 12M 30%, POS 3M 20%, POS 6M 20%
	case
		when i.r_product < 0.30 then 1
		when i.r_product < 0.60 then 2
		when i.r_product < 0.80 then 3
		else 4
	end as product_id,
	-- requested_amount (PHP, rounded to 100): cash 5 000-50 000, pos 3 000-30 000
	case
		when i.r_product < 0.60 then round((5000 + i.r_amount * 45000) / 100) * 100
		else round((3000 + i.r_amount * 27000) / 100) * 100
	end as requested_amount,
	-- channel: POS always partner_store; cash: google 35%, facebook 30%, tiktok 15%, organic 20%
	case
		when i.r_product >= 0.60 then 'partner_store'
		when i.r_channel < 0.35 then 'google'
		when i.r_channel < 0.65 then 'facebook'
		when i.r_channel < 0.80 then 'tiktok'
		else 'organic'
	end as channel,
	i.r_status,
	i.r_decided,
	i.r_defect
from
	ids i
join customers c on
	c.customer_id = i.customer_id
),
-- final: campaign lookup, decision, channel defect; columns in table order
final as (
select
	a.application_id,
	a.customer_id,
	a.product_id,
	cp.campaign_id,
	-- channel defect (~12%): upper case, initcap, leading/trailing spaces; applied after the campaign lookup
	case
		when a.r_defect < 0.04 then upper(a.channel)
		when a.r_defect < 0.08 then initcap(a.channel)
		when a.r_defect < 0.12 then ' ' || a.channel || ' '
		else a.channel
	end as channel,
	a.applied_at,
	a.requested_amount,
	-- status: approved 67%, rejected 28%, cancelled 5%
	case
		when a.r_status < 0.67 then 'approved'
		when a.r_status < 0.95 then 'rejected'
		else 'cancelled'
	end as status,
	-- decided_at: within 2 days after the application, capped by the period end
	a.applied_at + a.r_decided * least(interval '2 days', timestamp '2026-10-01' - a.applied_at) as decided_at
from
	with_channel a
-- campaign of the same channel running on the application date; if two overlap (google 2026), take the newest
left join lateral (
	select
		campaign_id
	from
		campaigns c
	where
		c.channel = a.channel
		and a.applied_at::date between c.start_date and c.end_date
	order by
		c.start_date desc
	limit 1
) cp on
	true
)
select
	*
from
	final;
