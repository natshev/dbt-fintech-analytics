-- stg_provider_statement: payment provider statement, one row per provider transaction
with source as (
    select * from {{ source('raw', 'raw_provider_statement') }}
),
renamed as (
    select
        provider_txn_id, 
        payment_reference, 
        transaction_at, 
        amount
    from source
)

select * from renamed

