-- ЭТАП 8.5. Аналитическое представление для квартального дашборда.
-- Один ряд результата: год + квартал + версия месторождения + вид ремонта.

CREATE OR REPLACE VIEW frac_mart.v_quarterly_repairs_dashboard AS
SELECT
    d.calendar_year,
    d.quarter_number,
    d.year_quarter,
    f.field_code,
    f.field_name,
    f.region_name,
    f.valid_from AS field_version_valid_from,
    f.valid_to AS field_version_valid_to,
    f.is_current AS field_version_is_current,
    rt.repair_type_code,
    rt.type_name AS repair_type_name,
    COUNT(*)::bigint AS repairs_count,
    SUM(fact.repair_count)::bigint AS repair_count_measure,
    ROUND(AVG(fact.actual_duration_hours), 2) AS avg_duration_hours,
    ROUND(MIN(fact.actual_duration_hours), 2) AS min_duration_hours,
    ROUND(MAX(fact.actual_duration_hours), 2) AS max_duration_hours,
    ROUND(AVG(fact.avg_pressure_mpa), 2) AS avg_pressure_mpa,
    ROUND(MAX(fact.max_pressure_mpa), 2) AS max_pressure_mpa,
    ROUND(SUM(fact.total_fluid_volume_m3), 3) AS total_fluid_volume_m3,
    ROUND(SUM(fact.total_proppant_mass_t), 3) AS total_proppant_mass_t,
    COUNT(DISTINCT fact.fleet_code)::integer AS fleets_involved
FROM frac_mart.fact_well_repair AS fact
JOIN frac_mart.dim_date AS d
    ON d.date_key = fact.date_key
JOIN frac_mart.dim_field AS f
    ON f.field_key = fact.field_key
JOIN frac_mart.dim_repair_type AS rt
    ON rt.repair_type_key = fact.repair_type_key
GROUP BY
    d.calendar_year, d.quarter_number, d.year_quarter,
    f.field_code, f.field_name, f.region_name,
    f.valid_from, f.valid_to, f.is_current,
    rt.repair_type_code, rt.type_name;

COMMENT ON VIEW frac_mart.v_quarterly_repairs_dashboard IS
'Квартальная аналитическая витрина по месторождениям и видам ремонтов: количество, длительность и технологические показатели.';

-- Представление детального уровня для проверки связи факта с измерениями.
CREATE OR REPLACE VIEW frac_mart.v_repair_fact_detail AS
SELECT
    fact.fact_repair_key,
    fact.source_repair_id,
    fact.repair_code,
    fact.well_code,
    fact.fleet_code,
    d.full_date AS repair_start_date,
    d.year_quarter,
    f.field_code,
    f.field_name,
    f.region_name,
    f.valid_from AS field_version_valid_from,
    f.valid_to AS field_version_valid_to,
    rt.repair_type_code,
    rt.type_name AS repair_type_name,
    fact.actual_duration_hours,
    fact.stage_count,
    fact.measurement_count,
    fact.avg_pressure_mpa,
    fact.max_pressure_mpa,
    fact.total_fluid_volume_m3,
    fact.total_proppant_mass_t
FROM frac_mart.fact_well_repair AS fact
JOIN frac_mart.dim_date AS d ON d.date_key = fact.date_key
JOIN frac_mart.dim_field AS f ON f.field_key = fact.field_key
JOIN frac_mart.dim_repair_type AS rt ON rt.repair_type_key = fact.repair_type_key;

COMMENT ON VIEW frac_mart.v_repair_fact_detail IS
'Детальное представление одной строки на один завершённый ремонт с расшифровкой измерений.';
