-- stg_customers: customers, current state, one row per customer
with source as (
    select * from {{ source('raw', 'raw_customers') }}
),

renamed as (
    select
        customer_id,
        created_at,
        birth_date,
        region,
        -- defect in source: ~3% NULL; replaced once here so every layer sees an explicit value
        coalesce(employment_type, 'unknown') as employment_type,
        monthly_income,
        risk_segment,
        updated_at
    from source
)

select * from renamed

