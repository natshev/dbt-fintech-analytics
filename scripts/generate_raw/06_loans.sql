-- raw_loans: disbursed loans (source emulation), one row per loan, one loan per approved application.
-- Loan terms (annual_rate, term_months) are copied from the product at disbursement.
-- status is 'active' for all loans here; fully repaid loans are set to 'closed' in the payments step.
-- Re-runnable and reproducible: table is recreated, setseed() fixes random().

drop table if exists raw.raw_loans;
create table raw.raw_loans (
    loan_id int,
    application_id int,
    customer_id int,
    product_id int,
    disbursed_at timestamp,
    principal_amount numeric(12,2),
    annual_rate numeric(5,4),
    term_months int,
    status varchar
);
select setseed(0.46);
insert into raw.raw_loans (loan_id, application_id, customer_id, product_id, disbursed_at, principal_amount, annual_rate, term_months, status)
-- applications: import, approved applications only
with applications as (
    select application_id, customer_id, product_id, requested_amount, decided_at
    from raw.raw_loan_applications
    where status = 'approved'
),
-- products: import, current product terms
products as (
    select product_id, annual_rate, term_months from raw.raw_products
),
-- loans: loan_id in application order, principal = requested amount;
-- random number is drawn here, before the join
loans as (
    select row_number() over (order by application_id) as loan_id,
           application_id,
           customer_id,
           product_id,
           requested_amount as principal_amount,
           decided_at,
           random() as r_disbursed
    from applications
),
-- final: disbursement date and product terms; columns in table order
final as (
    select l.loan_id, l.application_id, l.customer_id, l.product_id,
           -- disbursed_at: within 1 day after approval, capped by the period end
           l.decided_at + l.r_disbursed * least(interval '1 day', timestamp '2026-10-01' - l.decided_at) as disbursed_at,
           l.principal_amount, p.annual_rate, p.term_months,
           'active' as status
    from loans l
    join products p on p.product_id = l.product_id
)
select * from final;
