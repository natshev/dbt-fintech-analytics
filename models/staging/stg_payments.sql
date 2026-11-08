-- stg_payments: customer payments, one row per payment (load duplicates removed)
with source as (
    select * from {{ source('raw', 'raw_payments') }}
),

deduplicated as (
    -- defect in source: ~0.5% payments loaded twice; keep the earliest load of each payment_id
    select
        *,
        row_number() over (partition by payment_id order by _loaded_at) as load_rank
    from source
),

renamed as (
    select
        payment_id,
        loan_id,
        installment_id,
        paid_at,
        principal_paid,
        interest_paid,
        _loaded_at
    from deduplicated
    where load_rank = 1
)

select * from renamed

