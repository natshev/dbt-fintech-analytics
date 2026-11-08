-- run_all.sql: rebuilds all raw tables (source emulation) in dependency order.
-- Run from the project root (PowerShell):
--   & "C:\Program Files\PostgreSQL\18\bin\psql.exe" -U dbt_user -d analytics -f scripts/generate_raw/run_all.sql
-- \ir resolves file names relative to this file, so the current folder does not matter.
-- 08_payments.sql updates raw_loans.status, so it must run after 06 and 07.

-- stop at the first error instead of building tables on broken data
\set ON_ERROR_STOP on

\ir 00_schema.sql
\ir 01_products.sql
\ir 02_campaigns.sql
\ir 03_marketing_spend.sql
\ir 04_customers.sql
\ir 05_loan_applications.sql
\ir 06_loans.sql
\ir 07_installments.sql
\ir 08_payments.sql
\ir 09_provider_statement.sql

-- control totals: compare with the reference numbers (same data as a run from DBeaver)
-- raw_products 4; raw_campaigns 10; raw_marketing_spend 2391 / 8837488.69; raw_customers 2000 / 77745318.84;
-- raw_loan_applications 3000 / 68911400.00; raw_loans 2036 / 47018500.00; raw_installments 14775 / 47018500.00;
-- raw_payments 11062 / 35771143.09; raw_provider_statement 10913 / 41095886.44
select 'raw_products' as table_name, count(*) as row_count, null::numeric as control_sum from raw.raw_products
union all
select 'raw_campaigns', count(*), null::numeric from raw.raw_campaigns
union all
select 'raw_marketing_spend', count(*), sum(spend_amount) from raw.raw_marketing_spend
union all
select 'raw_customers', count(*), sum(monthly_income) from raw.raw_customers
union all
select 'raw_loan_applications', count(*), sum(requested_amount) from raw.raw_loan_applications
union all
select 'raw_loans', count(*), sum(principal_amount) from raw.raw_loans
union all
select 'raw_installments', count(*), sum(principal_due) from raw.raw_installments
union all
select 'raw_payments', count(*), sum(principal_paid) from raw.raw_payments
union all
select 'raw_provider_statement', count(*), sum(amount) from raw.raw_provider_statement;
