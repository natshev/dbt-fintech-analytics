-- stg_campaigns: marketing campaigns, one row per campaign
with source as (
    select * from {{ source('raw', 'raw_campaigns') }}
),
renamed as (
    select
        campaign_id, 
        campaign_name, 
        channel, 
        start_date, 
        end_date
    from source
)

select * from renamed

