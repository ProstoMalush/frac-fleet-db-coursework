# Схема partner_1 — «Проектирование БД замеров по скважинам»

Самостоятельная учебная предметная область одногруппницы. Все данные синтетические.

## Состав

8 таблиц: `source_field`, `source_well`, `measurement_parameter`, `measurement_method`, `measuring_device`, `measurement_operator`, `measurement_session`, `well_measurement`.

Плановый объём после заполнения: 10 месторождений, 100 скважин, 8 параметров, 4 методики, 12 приборов, 10 операторов, 4 300 сессий и 34 400 значений измерений.

## Запуск в общей БД test

Выполнить по порядку:
1. `ddl/01_create_schema_tables.sql`
2. `data/02_seed_reference_data.sql`
3. `data/03_generate_measurements.sql`
4. `queries/04_validation.sql`
5. `queries/05_sample_analytics.sql`

Схема автономна и не содержит внешних ключей на `frac_core`. Межсхемное сопоставление выполняется отдельно, в `../integration/`.

Локальные ID принадлежат только `partner_1`; для сопоставления скважин используется пара `field_code + well_code`.

Подробные материалы: `docs/`.
