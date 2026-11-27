-- ЭТАП 8.2. Первоначальная загрузка измерений.
-- Бизнес-дата определяется в часовом поясе Asia/Yekaterinburg (UTC+05).
-- Скрипт допускает повторный запуск: измерения не дублируются.

BEGIN;

-- 1. Календарь на весь диапазон завершённых ремонтов.
WITH bounds AS (
    SELECT
        COALESCE(
            MIN((actual_start_at AT TIME ZONE 'Asia/Yekaterinburg')::date),
            DATE '2023-01-01'
        ) AS min_date,
        COALESCE(
            MAX((actual_start_at AT TIME ZONE 'Asia/Yekaterinburg')::date),
            DATE '2026-12-31'
        ) AS max_date
    FROM frac_core.well_repair
    WHERE repair_status = 'completed'
      AND actual_start_at IS NOT NULL
), calendar AS (
    SELECT gs::date AS d
    FROM bounds b
    CROSS JOIN LATERAL generate_series(
        b.min_date::timestamp,
        b.max_date::timestamp,
        INTERVAL '1 day'
    ) AS gs
)
INSERT INTO frac_mart.dim_date (
    date_key, full_date, calendar_year, quarter_number,
    month_number, day_of_month, iso_day_of_week, is_weekend, year_quarter
)
SELECT
    TO_CHAR(d, 'YYYYMMDD')::integer,
    d,
    EXTRACT(YEAR FROM d)::smallint,
    EXTRACT(QUARTER FROM d)::smallint,
    EXTRACT(MONTH FROM d)::smallint,
    EXTRACT(DAY FROM d)::smallint,
    EXTRACT(ISODOW FROM d)::smallint,
    EXTRACT(ISODOW FROM d) IN (6, 7),
    TO_CHAR(d, 'YYYY') || '-Q' || EXTRACT(QUARTER FROM d)::integer::text
FROM calendar
ON CONFLICT (date_key) DO NOTHING;

-- 2. Начальная версия каждого месторождения.
-- Дата 2023-01-01 — начало временного горизонта синтетического набора.
INSERT INTO frac_mart.dim_field (
    source_oil_field_id, field_code, field_name, region_name, description,
    valid_from, valid_to, is_current, change_reason
)
SELECT
    f.oil_field_id,
    f.field_code,
    f.field_name,
    f.region_name,
    f.description,
    DATE '2023-01-01',
    NULL,
    TRUE,
    'Начальная загрузка измерения из frac_core.oil_field'
FROM frac_core.oil_field AS f
ON CONFLICT (source_oil_field_id) WHERE is_current DO NOTHING;

-- 3. Типы ремонтов.
INSERT INTO frac_mart.dim_repair_type (
    source_repair_type_id, repair_type_code, type_name,
    description, planned_duration_hours
)
SELECT
    rt.repair_type_id,
    rt.repair_type_code,
    rt.type_name,
    rt.description,
    rt.planned_duration_hours
FROM frac_core.repair_type AS rt
ON CONFLICT (source_repair_type_id) DO UPDATE SET
    repair_type_code = EXCLUDED.repair_type_code,
    type_name = EXCLUDED.type_name,
    description = EXCLUDED.description,
    planned_duration_hours = EXCLUDED.planned_duration_hours;

COMMIT;

-- Контроль загрузки измерений.
SELECT 'dim_date' AS table_name, COUNT(*) AS rows_count FROM frac_mart.dim_date
UNION ALL
SELECT 'dim_field', COUNT(*) FROM frac_mart.dim_field
UNION ALL
SELECT 'dim_repair_type', COUNT(*) FROM frac_mart.dim_repair_type
ORDER BY table_name;
