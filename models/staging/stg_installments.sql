-- stg_installments: planned repayment schedule, one row per loan installment
with source as (
    select * from {{ source('raw', 'raw_installments') }}
),
renamed as (
    select
        installment_id, 
        loan_id, 
        installment_number, 
        due_date, 
        principal_due, 
        interest_due
    from source
)

select * from renamed




