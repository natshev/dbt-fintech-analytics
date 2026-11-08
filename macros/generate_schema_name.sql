-- generate_schema_name: use the layer schema as is (staging, intermediate, marts)
-- instead of dbt default <target_schema>_<layer>; single developer, local database
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}

