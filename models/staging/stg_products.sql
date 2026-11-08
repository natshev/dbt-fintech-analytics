-- stg_products: product catalog, one row per product
with source as (
    select * from {{ source('raw', 'raw_products') }}
),

renamed as (
    select
        product_id,
        product_name,
        product_type,
        term_months,
        annual_rate
    from source
)

select * from renamed

