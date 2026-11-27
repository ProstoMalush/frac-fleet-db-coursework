# Порядок запуска

## Самостоятельная база замеров

1. `ddl/01_create_schema_tables.sql`
2. `data/02_seed_reference_data.sql`
3. `data/03_generate_measurements.sql`
4. `queries/04_validation.sql`
5. `queries/05_sample_analytics.sql`

## Интеграция

После запуска основного проекта флотов ГРП (этапы 1–8):

6. `integration/06_create_cross_domain_views.sql`
7. `queries/07_integration_validation.sql`
