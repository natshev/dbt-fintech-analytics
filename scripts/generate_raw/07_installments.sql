-- raw_installments: planned repayment schedule (source emulation), one row per loan x installment.
-- Annuity schedule: equal monthly payment, interest share falls and principal share grows over the term.
-- The full schedule is created at disbursement, so it includes installments due after the period end.
-- Rounding: the last installment repays the remaining principal, so sum(principal_due) per loan = principal_amount.
-- Re-runnable and reproducible: table is recreated; no random(), so no setseed().

drop table if exists raw.raw_installments;
create table raw.raw_installments (
    installment_id int,
    loan_id int,
    installment_number int,
    due_date date,
    principal_due numeric(12,2),
    interest_due numeric(12,2)
);
insert into raw.raw_installments (installment_id, loan_id, installment_number, due_date, principal_due, interest_due)
-- loans: import, loan terms at disbursement
with loans as (
select
	loan_id,
	disbursed_at,
	principal_amount,
	annual_rate,
	term_months
from
	raw.raw_loans
),
-- schedule: one row per installment (1..term_months);
-- due_date counted from the disbursement date, so month-end dates do not drift (Jan 31 -> Feb 28 -> Mar 31)
schedule as (
select
	l.loan_id,
	n.installment_number,
	(l.disbursed_at::date + n.installment_number * interval '1 month')::date as due_date,
	l.principal_amount,
	l.annual_rate,
	l.term_months
from
	loans l
cross join lateral generate_series(1, l.term_months) as n(installment_number)
),
-- with_payment: monthly rate r and exact annuity payment P * r / (1 - (1 + r)^-n), not rounded
with_payment as (
    select s.*,
           s.annual_rate / 12 as r,
           s.principal_amount * (s.annual_rate / 12) / (1 - power(1 + s.annual_rate / 12, -s.term_months)) as payment_exact
    from schedule s
),
-- amounts: rounded payment and principal part of installment k = payment / (1 + r)^(n - k + 1)
amounts as (
    select loan_id, installment_number, due_date, principal_amount, term_months,
           round(payment_exact, 2) as payment,
           round(payment_exact / power(1 + r, term_months - installment_number + 1), 2) as principal_raw
    from with_payment
),
-- adjusted: last installment takes the rest of the principal (removes rounding difference)
adjusted as (
    select loan_id, installment_number, due_date, payment,
           case
               when installment_number = term_months
                   then principal_amount - (sum(principal_raw) over (partition by loan_id) - principal_raw)
               else principal_raw
           end as principal_due
    from amounts
),
-- final: interest = payment - principal, so the payment is equal every month; columns in table order
final as (
    select row_number() over (order by loan_id, installment_number) as installment_id,
           loan_id, installment_number, due_date,
           principal_due,
           payment - principal_due as interest_due
    from adjusted
)
select * from final;
