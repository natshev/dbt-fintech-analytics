-- stg_loans: disbursed loans, one row per loan
with source as (
    select * from {{ source('raw', 'raw_loans') }}
),
renamed as (
    select
        loan_id, 
        application_id, 
        customer_id, 
        product_id, 
        disbursed_at, 
        principal_amount, 
        annual_rate, 
        term_months, 
        status
    from source
)

select * from renamed



