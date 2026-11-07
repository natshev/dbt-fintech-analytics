-- raw_customers: customer master data (source emulation), one row per customer, current state.
-- Defect for staging: ~3% NULL in employment_type; monthly_income is still generated from the real type.
-- Re-runnable and reproducible: table is recreated, setseed() fixes random().

drop table if exists raw.raw_customers;
create table raw.raw_customers (
    customer_id int,
    created_at timestamp,
    birth_date date,
    region varchar,
    employment_type varchar,
    monthly_income numeric(12,2),
    risk_segment varchar,
    updated_at timestamp
);
select
	setseed(0.44);
insert into raw.raw_customers (customer_id, created_at, birth_date, region, employment_type, monthly_income, risk_segment, updated_at)
-- ids: one row per customer, created_at uniform over 2024-10-01 .. 2026-09-30;
-- random numbers for case columns are drawn once here (random() inside "when" is re-evaluated in every branch)
with ids as (
select
	g as customer_id,
	timestamp '2024-10-01' + random() * interval '730 days' as created_at,
	random() as r_region,
	random() as r_employment,
	random() as r_null,
	random() as r_risk
from
	generate_series(1, 2000) as g
),
-- final: derived attributes; columns in table order
final as (
select
	customer_id,
	created_at,
	-- birth_date: age 21-65 at registration
	(created_at - (21 + random() * 44) * interval '1 year')::date as birth_date,
	-- region: NCR 40%, Calabarzon 25%, Central Luzon 15%, Central Visayas 12%, Davao 8%
	case
		when r_region < 0.40 then 'NCR'
		when r_region < 0.65 then 'Calabarzon'
		when r_region < 0.80 then 'Central Luzon'
		when r_region < 0.92 then 'Central Visayas'
		else 'Davao'
	end as region,
	-- employment_type: employed 65%, self_employed 25%, unemployed 10%; ~3% NULL (defect)
	case
		when r_null < 0.03 then null
		when r_employment < 0.65 then 'employed'
		when r_employment < 0.90 then 'self_employed'
		else 'unemployed'
	end as employment_type,
	-- monthly_income (PHP): range by the real employment type (r_employment), also for NULL rows
	case
		when r_employment < 0.65 then round((15000 + random() * 45000)::numeric, 2)
		when r_employment < 0.90 then round((10000 + random() * 90000)::numeric, 2)
		else round((3000 + random() * 7000)::numeric, 2)
	end as monthly_income,
	-- risk_segment: low 30%, medium 50%, high 20%
	case
		when r_risk < 0.30 then 'low'
		when r_risk < 0.80 then 'medium'
		else 'high'
	end as risk_segment,
	-- updated_at: equals created_at in the first load; changes come with the second load (snapshot step)
	created_at as updated_at
from
	ids
)
select
	*
from
	final;
