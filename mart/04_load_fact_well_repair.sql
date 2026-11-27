-- ЭТАП 8.4. Загрузка фактов завершённых ремонтов.
-- Зерно факта: одна строка на один завершённый ремонт.
-- Для каждого ремонта выбирается версия dim_field, действовавшая на дату начала ремонта.
-- Суммарные объёмы жидкости и проппанта рассчитываются как сумма последних
-- накопительных значений по этапам, а не как сумма всех временных точек телеметрии.

BEGIN;

WITH completed_repairs AS (
    SELECT
        r.repair_id,
        r.repair_code,
        r.well_id,
        r.frac_fleet_id,
        r.repair_type_id,
        (r.actual_start_at AT TIME ZONE 'Asia/Yekaterinburg')::date AS repair_date,
        frac_core.fn_repair_actual_duration_hours(r.repair_id) AS actual_duration_hours,
        w.well_code,
        f.fleet_code,
        o.oil_field_id,
        o.field_code
    FROM frac_core.well_repair AS r
    JOIN frac_core.well AS w
        ON w.well_id = r.well_id
    JOIN frac_core.oil_field AS o
        ON o.oil_field_id = w.oil_field_id
    JOIN frac_core.frac_fleet AS f
        ON f.frac_fleet_id = r.frac_fleet_id
    WHERE r.repair_status = 'completed'
      AND r.actual_start_at IS NOT NULL
      AND r.actual_end_at IS NOT NULL
      AND r.repair_code LIKE 'SYN-RPR-%'
), stage_metrics AS (
    SELECT
        s.repair_id,
        s.repair_stage_id,
        COUNT(m.measurement_id)::integer AS measurement_count,
        COUNT(m.pressure_mpa)::integer AS pressure_count,
        SUM(m.pressure_mpa) AS pressure_sum,
        MAX(m.pressure_mpa) AS stage_max_pressure_mpa,
        MAX(m.cumulative_fluid_volume_m3) AS stage_total_fluid_volume_m3,
        MAX(m.cumulative_proppant_mass_t) AS stage_total_proppant_mass_t
    FROM frac_core.repair_stage AS s
    LEFT JOIN frac_core.telemetry_measurement AS m
        ON m.repair_stage_id = s.repair_stage_id
    GROUP BY s.repair_id, s.repair_stage_id
), repair_metrics AS (
    SELECT
        sm.repair_id,
        COUNT(*)::smallint AS stage_count,
        COALESCE(SUM(sm.measurement_count), 0)::integer AS measurement_count,
        SUM(sm.pressure_sum) AS pressure_sum,
        COALESCE(SUM(sm.pressure_count), 0)::integer AS pressure_count,
        MAX(sm.stage_max_pressure_mpa) AS max_pressure_mpa,
        SUM(sm.stage_total_fluid_volume_m3) AS total_fluid_volume_m3,
        SUM(sm.stage_total_proppant_mass_t) AS total_proppant_mass_t
    FROM stage_metrics AS sm
    GROUP BY sm.repair_id
), fact_rows AS (
    SELECT
        cr.repair_id,
        cr.repair_code,
        cr.well_code,
        cr.fleet_code,
        dd.date_key,
        df.field_key,
        drt.repair_type_key,
        COALESCE(rm.stage_count, 0)::smallint AS stage_count,
        COALESCE(rm.measurement_count, 0)::integer AS measurement_count,
        cr.actual_duration_hours,
        CASE WHEN COALESCE(rm.pressure_count, 0) = 0 THEN NULL::numeric
             ELSE ROUND(rm.pressure_sum / NULLIF(rm.pressure_count, 0), 3)
        END AS avg_pressure_mpa,
        rm.max_pressure_mpa,
        rm.total_fluid_volume_m3,
        rm.total_proppant_mass_t
    FROM completed_repairs AS cr
    JOIN frac_mart.dim_date AS dd
        ON dd.full_date = cr.repair_date
    JOIN frac_mart.dim_field AS df
        ON df.source_oil_field_id = cr.oil_field_id
       AND cr.repair_date >= df.valid_from
       AND (df.valid_to IS NULL OR cr.repair_date < df.valid_to)
    JOIN frac_mart.dim_repair_type AS drt
        ON drt.source_repair_type_id = cr.repair_type_id
    LEFT JOIN repair_metrics AS rm
        ON rm.repair_id = cr.repair_id
)
INSERT INTO frac_mart.fact_well_repair (
    source_repair_id, repair_code, well_code, fleet_code,
    date_key, field_key, repair_type_key,
    repair_count, stage_count, measurement_count,
    actual_duration_hours, avg_pressure_mpa, max_pressure_mpa,
    total_fluid_volume_m3, total_proppant_mass_t
)
SELECT
    repair_id, repair_code, well_code, fleet_code,
    date_key, field_key, repair_type_key,
    1, stage_count, measurement_count,
    actual_duration_hours, avg_pressure_mpa, max_pressure_mpa,
    total_fluid_volume_m3, total_proppant_mass_t
FROM fact_rows
ON CONFLICT (source_repair_id) DO UPDATE SET
    repair_code = EXCLUDED.repair_code,
    well_code = EXCLUDED.well_code,
    fleet_code = EXCLUDED.fleet_code,
    date_key = EXCLUDED.date_key,
    field_key = EXCLUDED.field_key,
    repair_type_key = EXCLUDED.repair_type_key,
    repair_count = EXCLUDED.repair_count,
    stage_count = EXCLUDED.stage_count,
    measurement_count = EXCLUDED.measurement_count,
    actual_duration_hours = EXCLUDED.actual_duration_hours,
    avg_pressure_mpa = EXCLUDED.avg_pressure_mpa,
    max_pressure_mpa = EXCLUDED.max_pressure_mpa,
    total_fluid_volume_m3 = EXCLUDED.total_fluid_volume_m3,
    total_proppant_mass_t = EXCLUDED.total_proppant_mass_t,
    loaded_at = CURRENT_TIMESTAMP;

COMMIT;

-- Контроль ожидаемого зерна факта: 420 завершённых синтетических ремонтов.
SELECT
    COUNT(*) AS fact_rows,
    COUNT(DISTINCT source_repair_id) AS distinct_source_repairs,
    SUM(repair_count) AS total_repairs,
    ROUND(AVG(actual_duration_hours), 2) AS avg_repair_duration_hours,
    ROUND(AVG(avg_pressure_mpa), 2) AS avg_pressure_mpa,
    ROUND(MAX(max_pressure_mpa), 2) AS max_pressure_mpa,
    ROUND(SUM(total_fluid_volume_m3), 3) AS total_fluid_volume_m3,
    ROUND(SUM(total_proppant_mass_t), 3) AS total_proppant_mass_t
FROM frac_mart.fact_well_repair;
