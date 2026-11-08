-- raw_provider_statement: payment provider statement (second source for reconciliation), one row per provider transaction.
-- Built from raw_payments without load duplicates; amount = principal_paid + interest_paid (provider has no split).
-- Planted differences vs raw_payments (for the reconciliation model):
--   missing_at_provider ~1%   - payment is not in the statement;
--   amount_diff         ~0.5% - amount is 1-50 PHP lower (e.g. provider fee withheld);
--   date_diff           ~0.5% - transaction 1-2 days later (can move a payment to the next month);
--   extra_at_provider   ~0.5% - extra transaction with payment_reference 900000 + payment_id, no such payment in raw_payments;
--   match               - transaction_at = paid_at + up to 5 minutes, same amount.
-- Statement covers transactions up to the as-of date (transaction_at < 2026-10-01).
-- Re-runnable and reproducible: table is recreated, setseed() fixes random().

drop table if exists raw.raw_provider_statement;
create table raw.raw_provider_statement(
    provider_txn_id varchar,
    payment_reference int,
    transaction_at timestamp,
    amount numeric(12,2)
);
select setseed(0.48);
insert into raw.raw_provider_statement (provider_txn_id, payment_reference, transaction_at, amount)
-- payments: import, one row per payment_id (earliest load, duplicates dropped), in payment_id order
with payments as (
    select distinct on (payment_id) payment_id, paid_at, principal_paid + interest_paid as amount
    from raw.raw_payments
    order by payment_id, _loaded_at
),
-- with_random: the only place with random(); rows in payment_id order, so numbers go to the same payments on every run
with_random as (
    select p.*, random() as r_case, random() as r_shift
    from payments p
),
-- cases: reconciliation case per payment (helper, not stored in the table)
cases as (
    select *,
           case
               when r_case < 0.010 then 'missing_at_provider'
               when r_case < 0.015 then 'amount_diff'
               when r_case < 0.020 then 'date_diff'
               when r_case < 0.025 then 'extra_at_provider'
               else 'match'
           end as recon_case
    from with_random
),
-- statement_rows: provider transactions
statement_rows as (
    -- regular rows: every payment except missing_at_provider; date and amount shifted for their cases
    select payment_id as payment_reference,
           case
               when recon_case = 'date_diff' then paid_at + (1 + r_shift) * interval '1 day'
               else paid_at + r_shift * interval '5 minutes'
           end as transaction_at,
           case
               -- ::int keeps amount numeric (exact cents)
               when recon_case = 'amount_diff' then amount - (1 + floor(r_shift * 50))::int
               else amount
           end as amount
    from cases
    where recon_case <> 'missing_at_provider'
    union all
    -- extra rows: money received by the provider, no payment with this reference in our system
    select 900000 + payment_id as payment_reference,
           paid_at + (1 + r_shift * 23) * interval '1 hour' as transaction_at,
           amount
    from cases
    where recon_case = 'extra_at_provider'
),
-- final: statement up to the as-of date; provider_txn_id in transaction time order ('TX' + 7 digits)
final as (
    select 'TX' || lpad(row_number() over (order by transaction_at, payment_reference)::text, 7, '0') as provider_txn_id,
           payment_reference, transaction_at, amount
    from statement_rows
    where transaction_at < timestamp '2026-10-01'
)
select * from final;
