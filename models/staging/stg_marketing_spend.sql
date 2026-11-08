-- stg_marketing_spend: daily ad spend, one row per campaign and day
with source as (
    select * from {{ source('raw', 'raw_marketing_spend') }}
),
renamed as (
    select
        campaign_id, 
        spend_date, 
        spend_amount, 
        impressions, 
        clicks
    from source
)

select * from renamed


