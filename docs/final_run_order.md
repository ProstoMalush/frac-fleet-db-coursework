# Итоговый порядок развёртывания проекта

Все скрипты выполнять в одной базе PostgreSQL 15 (для текущего Docker-проекта — `test`). Каждый SQL-файл запускать отдельно в DBeaver и проверять результат.

## A. Основная предметная область — frac_core

1. `ddl/01_create_schema.sql`
2. `ddl/02_extensions.sql`
3. `ddl/03_create_tables.sql`
4. `ddl/04_constraints.sql`
5. `ddl/05_indexes.sql`
6. `ddl/06_comments.sql`
7. `data/01_reference_data.sql`
8. `data/02_equipment_and_maintenance.sql`
9. `data/03_repairs_and_stages.sql`
10. `data/04_telemetry_measurements.sql`
11. `queries/00_check_structure.sql` и `queries/01_verify_generated_data.sql`
12. `functions/01_create_functions.sql`, затем `functions/02_test_functions.sql`

## B. Пять бизнес-запросов

`queries/02_repairs_by_field_quarter.sql` → `03_fleet_performance.sql` → `04_repeat_repairs_by_well.sql` → `05_telemetry_above_stage_average.sql` → `06_equipment_maintenance_by_fleet_cte.sql`. Дополнительное сравнение коррелированного и некоррелированного запросов — `07_telemetry_above_stage_average_noncorrelated.sql`. Диагностика ТО — `08_maintenance_due_date_profile.sql`.

## C. Аналитическая витрина — frac_mart

1. `mart/01_create_mart.sql`
2. `mart/02_load_dimensions.sql`
3. `mart/03_scd2_function_and_demo.sql`
4. `mart/04_load_fact_well_repair.sql`
5. `mart/05_create_analytics_view.sql`
6. `mart/06_validate_mart.sql`

## D. Вторая предметная область — partner_1

1. `partner_1/ddl/01_create_schema_tables.sql`
2. `partner_1/data/02_seed_reference_data.sql`
3. `partner_1/data/03_generate_measurements.sql`
4. `partner_1/queries/04_validation.sql`
5. `partner_1/queries/05_sample_analytics.sql`

## E. Интеграция двух предметных областей

1. `integration/06_create_cross_domain_views.sql`
2. `integration/07_validation.sql`

## F. Эксперимент с индексами (отдельно, после наполнения frac_core)

1. `performance/00_table_sizes.sql`
2. `performance/00b_cluster_telemetry_by_time.sql` — необязательная физическая сортировка для воспроизводимости демонстрации BRIN; требует блокировки таблицы на время `CLUSTER`.
3. `performance/01_prepare_baseline.sql`
4. `performance/02_explain_before.sql`
5. `performance/03_create_target_indexes.sql`
6. `performance/04_explain_after.sql`
7. `performance/05_index_catalog.sql`
8. `performance/06_index_usage_stats.sql`

**Не оставляйте БД после шага F.3 без выполнения F.5:** целевые индексы должны быть восстановлены.

## Уже развёрнутая БД пользователя

Если схемы и данные уже созданы в текущем контейнере, не запускайте повторно начальные DDL и генераторы данных. Этот порядок предназначен для чистой новой установки/проверочного повторного развёртывания.
