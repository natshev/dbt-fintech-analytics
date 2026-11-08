-- raw_payments: actual customer payments (source emulation), one row per paid installment.
-- Payer type per loan: on_time 80% (-3..+5 days from due date), late 12% (10-40 days, one delay per loan),
-- default 8% (pays the first N installments, then stops). Payments are full amounts from the schedule.
-- Only payments made up to the as-of date (2026-09-30) exist; _loaded_at = next night 02:00.
-- Defect for staging: ~0.5% payments loaded twice (same payment_id and amounts, _loaded_at one day later).
-- After the insert, raw_loans.status is recalculated: 'closed' when every installment is paid.
-- Re-runnable and reproducible: table is recreated, setseed() fixes random().

drop table if exists raw.raw_payments;
create table raw.raw_payments (
    payment_id int,
    loan_id int,
    installment_id int,
    paid_at timestamp,
    principal_paid numeric(12,2),
    interest_paid numeric(12,2),
    _loaded_at timestamp
);
select
	setseed(0.47);
insert into raw.raw_payments (payment_id, loan_id, installment_id, paid_at, principal_paid, interest_paid, _loaded_at)
-- loans: import, loan term
with loans as (
select
	loan_id,
	term_months
from
	raw.raw_loans
),
-- installments: import, schedule in strict installment_id order
-- (random numbers below must go to the same rows on every run)
installments as (
select
	installment_id,
	loan_id,
	installment_number,
	due_date,
	principal_due,
	interest_due
from
	raw.raw_installments
order by
	installment_id
),
-- with_random: the only place with random(), one pass over the schedule;
-- read twice below, computed once, so both readers see the same numbers
with_random as (
select
	i.*,
	random() as r_type,
	random() as r_stop,
	random() as r_late,
	random() as r_paid,
	random() as r_dup
from
	installments i
),
-- loan_behavior: payer type per loan, taken from the random numbers of installment 1
loan_behavior as (
select
	w.loan_id,
	-- payer_type: on_time 80%, late 12%, default 8%
	case
		when w.r_type < 0.80 then 'on_time'
		when w.r_type < 0.92 then 'late'
		else 'default'
	end as payer_type,
	-- paid_count: installments the customer pays; default pays 0..term-1, then stops
	case
		when w.r_type < 0.92 then l.term_months
		else floor(w.r_stop * l.term_months)::int
	end as paid_count,
	-- late_days: one delay per loan (10-40 days), so payments keep their order
	10 + floor(w.r_late * 31)::int as late_days
from
	with_random w
join loans l on
	l.loan_id = w.loan_id
where
	w.installment_number = 1
),
-- paid: paid installments (first paid_count of each loan) and payment time
paid as (
select
	w.installment_id,
	w.loan_id,
	w.due_date,
	w.principal_due,
	w.interest_due,
	b.payer_type,
	-- paid_at: late = due date + loan delay (+ random time of day); others = due date -3..+5 days
	case
		when b.payer_type = 'late' then w.due_date + (b.late_days + w.r_paid) * interval '1 day'
		else w.due_date + (-3 + w.r_paid * 8) * interval '1 day'
	end as paid_at,
	w.r_dup
from
	with_random w
join loan_behavior b on
	b.loan_id = w.loan_id
where
	w.installment_number <= b.paid_count
),
-- payments: only payments up to the as-of date; payment_id in payment time order;
-- full amounts from the schedule; _loaded_at = next night 02:00
payments as (
    select row_number() over (order by paid_at, installment_id) as payment_id,
           loan_id, installment_id, paid_at,
           principal_due as principal_paid,
           interest_due as interest_paid,
           date_trunc('day', paid_at) + interval '1 day 2 hours' as _loaded_at,
           r_dup
    from paid
    where paid_at < timestamp '2026-10-01'
),
-- final: payments + duplicates (defect); union all keeps identical rows; columns in table order
final as (
    select payment_id, loan_id, installment_id, paid_at, principal_paid, interest_paid, _loaded_at
    from payments
    union all
    -- duplicates (~0.5%): the same record loaded again the next night
    select payment_id, loan_id, installment_id, paid_at, principal_paid, interest_paid, _loaded_at + interval '1 day'
    from payments
    where r_dup < 0.005
)
select * from final;

-- loan status: reset, so the file can be re-run on its own
update raw.raw_loans set status = 'active';

-- closed: every installment of the loan is paid;
-- count(distinct installment_id), not count(*): duplicates must not close an unpaid loan
update raw.raw_loans l
set status = 'closed'
where (select count(distinct p.installment_id)
       from raw.raw_payments p
       where p.loan_id = l.loan_id) = l.term_months;
