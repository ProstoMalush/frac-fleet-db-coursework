-- ЭТАП 8.6. Контрольные запросы аналитической витрины.

-- 1. Количество записей в измерениях и таблице фактов.
SELECT 'dim_date' AS table_name, COUNT(*) AS rows_count FROM frac_mart.dim_date
UNION ALL
SELECT 'dim_field', COUNT(*) FROM frac_mart.dim_field
UNION ALL
SELECT 'dim_repair_type', COUNT(*) FROM frac_mart.dim_repair_type
UNION ALL
SELECT 'fact_well_repair', COUNT(*) FROM frac_mart.fact_well_repair
ORDER BY table_name;

-- 2. История SCD-2 по демонстрационному месторождению.
SELECT
    field_code,
    field_name,
    region_name,
    description,
    valid_from,
    valid_to,
    is_current,
    change_reason
FROM frac_mart.dim_field
WHERE field_code = 'SYN-FLD-001'
ORDER BY valid_from;

-- 3. Проверка, что каждая строка факта имеет дату, месторождение и вид ремонта.
SELECT
    COUNT(*) AS fact_rows,
    COUNT(*) FILTER (WHERE d.date_key IS NULL) AS missing_date_dimension,
    COUNT(*) FILTER (WHERE f.field_key IS NULL) AS missing_field_dimension,
    COUNT(*) FILTER (WHERE rt.repair_type_key IS NULL) AS missing_repair_type_dimension
FROM frac_mart.fact_well_repair AS fact
LEFT JOIN frac_mart.dim_date AS d ON d.date_key = fact.date_key
LEFT JOIN frac_mart.dim_field AS f ON f.field_key = fact.field_key
LEFT JOIN frac_mart.dim_repair_type AS rt ON rt.repair_type_key = fact.repair_type_key;

-- 4. Проверка корректного выбора версии месторождения на дату ремонта.
SELECT COUNT(*) AS facts_with_wrong_field_version
FROM frac_mart.fact_well_repair AS fact
JOIN frac_mart.dim_date AS d ON d.date_key = fact.date_key
JOIN frac_mart.dim_field AS f ON f.field_key = fact.field_key
WHERE d.full_date < f.valid_from
   OR (f.valid_to IS NOT NULL AND d.full_date >= f.valid_to);

-- 5. Первые строки квартальной витрины.
SELECT *
FROM frac_mart.v_quarterly_repairs_dashboard
ORDER BY calendar_year, quarter_number, field_code, repair_type_code
LIMIT 50;

-- 6. Итоги по годам и кварталам.
SELECT
    calendar_year,
    quarter_number,
    SUM(repairs_count) AS repairs_count,
    ROUND(AVG(avg_duration_hours), 2) AS avg_duration_hours,
    ROUND(SUM(total_fluid_volume_m3), 3) AS total_fluid_volume_m3,
    ROUND(SUM(total_proppant_mass_t), 3) AS total_proppant_mass_t
FROM frac_mart.v_quarterly_repairs_dashboard
GROUP BY calendar_year, quarter_number
ORDER BY calendar_year, quarter_number;
