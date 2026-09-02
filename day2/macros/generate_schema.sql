{# スキーマ名の作成 #}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- set default_schema = target.schema -%}
        {{ default_schema }}
{%- endmacro %}