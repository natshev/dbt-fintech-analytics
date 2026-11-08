-- stg_loan_applications: loan applications, one row per application
with source as (
    select * from {{ source('raw', 'raw_loan_applications') }}
),

renamed as (
    select
        application_id,
        customer_id,
        product_id,
        campaign_id,
        -- defect in source: mixed case and spaces ('Facebook', ' google '); cleaned here
        lower(trim(channel)) as channel,
        applied_at,
        requested_amount,
        status,
        decided_at
    from source
)

select * from renamed

