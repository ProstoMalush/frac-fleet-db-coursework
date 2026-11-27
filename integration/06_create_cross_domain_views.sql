-- Межсхемная интеграция partner_1 (замеры) с frac_core/frac_mart (ремонты ГРП).
-- Выполнять только после этапов 1-8 основного проекта и наполнения partner_1.
-- Важно: source_well_id и frac_core.well_id принадлежат разным пространствам ID.
-- Сопоставление выполняется по естественному составному ключу: field_code + well_code.

CREATE OR REPLACE VIEW frac_mart.v_partner_1_well_crosswalk AS
SELECT
    pw.source_well_id,
    pf.source_field_id,
    pf.field_code,
    pw.well_code,
    cw.well_id AS frac_core_well_id,
    cf.oil_field_id AS frac_core_oil_field_id,
    (pw.source_well_id = cw.well_id) AS numeric_ids_equal,
    TRUE AS matched_by_natural_key
FROM partner_1.source_well pw
JOIN partner_1.source_field pf
  ON pf.source_field_id = pw.source_field_id
JOIN frac_core.oil_field cf
  ON cf.field_code = pf.field_code
JOIN frac_core.well cw
  ON cw.oil_field_id = cf.oil_field_id
 AND cw.well_code = pw.well_code;

COMMENT ON VIEW frac_mart.v_partner_1_well_crosswalk IS
'Сопоставление скважин partner_1 и frac_core по паре field_code + well_code. Локальные числовые ID не используются как ключ интеграции.';

-- Одна строка на один факт ремонта; подтягивается последняя корректная сессия
-- замеров по той же скважине, которая была выполнена не ранее чем за 90 дней
-- до точного времени начала ремонта (включая более ранние измерения в этот день).
CREATE OR REPLACE VIEW frac_mart.v_repair_with_partner_well_measurements AS
SELECT
    fact.fact_repair_key,
    fact.source_repair_id,
    fact.repair_code,
    d.full_date AS repair_date,
    source_repair.actual_start_at,
    field.field_code,
    field.field_name,
    fact.well_code,
    fact.fleet_code,
    rt.repair_type_code,
    rt.type_name AS repair_type_name,
    fact.actual_duration_hours,
    fact.avg_pressure_mpa AS frac_avg_pressure_mpa,
    fact.max_pressure_mpa AS frac_max_pressure_mpa,
    partner_metrics.session_id AS partner_session_id,
    partner_metrics.measured_at AS partner_measurement_at,
    CASE WHEN partner_metrics.measured_at IS NOT NULL
         THEN (source_repair.actual_start_at AT TIME ZONE 'Asia/Yekaterinburg')::date
              - (partner_metrics.measured_at AT TIME ZONE 'Asia/Yekaterinburg')::date
         ELSE NULL END AS days_between_measurement_and_repair,
    partner_metrics.oil_rate_m3_day,
    partner_metrics.water_rate_m3_day,
    partner_metrics.gas_rate_thousand_m3_day,
    partner_metrics.water_cut_pct,
    partner_metrics.reservoir_pressure_mpa,
    partner_metrics.bottomhole_pressure_mpa,
    partner_metrics.temperature_c,
    partner_metrics.dynamic_fluid_level_m
FROM frac_mart.fact_well_repair fact
JOIN frac_mart.dim_date d
  ON d.date_key = fact.date_key
JOIN frac_mart.dim_field field
  ON field.field_key = fact.field_key
JOIN frac_mart.dim_repair_type rt
  ON rt.repair_type_key = fact.repair_type_key
JOIN frac_core.well_repair source_repair
  ON source_repair.repair_id = fact.source_repair_id
LEFT JOIN LATERAL (
    SELECT
        ms.session_id,
        ms.measured_at,
        MAX(wm.measured_value) FILTER (WHERE mp.parameter_code = 'OIL_RATE') AS oil_rate_m3_day,
        MAX(wm.measured_value) FILTER (WHERE mp.parameter_code = 'WATER_RATE') AS water_rate_m3_day,
        MAX(wm.measured_value) FILTER (WHERE mp.parameter_code = 'GAS_RATE') AS gas_rate_thousand_m3_day,
        MAX(wm.measured_value) FILTER (WHERE mp.parameter_code = 'WATER_CUT') AS water_cut_pct,
        MAX(wm.measured_value) FILTER (WHERE mp.parameter_code = 'RESERVOIR_PRESSURE') AS reservoir_pressure_mpa,
        MAX(wm.measured_value) FILTER (WHERE mp.parameter_code = 'BOTTOMHOLE_PRESSURE') AS bottomhole_pressure_mpa,
        MAX(wm.measured_value) FILTER (WHERE mp.parameter_code = 'TEMPERATURE') AS temperature_c,
        MAX(wm.measured_value) FILTER (WHERE mp.parameter_code = 'DYNAMIC_FLUID_LEVEL') AS dynamic_fluid_level_m
    FROM partner_1.source_field pf
    JOIN partner_1.source_well pw
      ON pw.source_field_id = pf.source_field_id
    JOIN partner_1.measurement_session ms
      ON ms.source_well_id = pw.source_well_id
    JOIN partner_1.well_measurement wm
      ON wm.session_id = ms.session_id
    JOIN partner_1.measurement_parameter mp
      ON mp.parameter_id = wm.parameter_id
    WHERE pf.field_code = field.field_code
      AND pw.well_code = fact.well_code
      AND ms.quality_status = 'valid'
      AND wm.quality_flag = 'valid'
      AND ms.measured_at < source_repair.actual_start_at
      AND ms.measured_at >= source_repair.actual_start_at - INTERVAL '90 days'
    GROUP BY ms.session_id, ms.measured_at
    ORDER BY ms.measured_at DESC
    LIMIT 1
) AS partner_metrics ON TRUE;

COMMENT ON VIEW frac_mart.v_repair_with_partner_well_measurements IS
'Междоменное представление: завершённые ремонты ГРП дополнены последними корректными замерами добычи/давления по той же скважине за 90 дней до ремонта.';

CREATE OR REPLACE VIEW frac_mart.v_quarterly_repairs_with_well_measurements AS
SELECT
    date_trunc('quarter', repair_date)::date AS quarter_start,
    field_code,
    field_name,
    repair_type_code,
    repair_type_name,
    COUNT(*) AS repairs_count,
    ROUND(AVG(actual_duration_hours), 2) AS avg_repair_duration_hours,
    ROUND(AVG(oil_rate_m3_day), 2) AS avg_oil_rate_m3_day,
    ROUND(AVG(water_cut_pct), 2) AS avg_water_cut_pct,
    ROUND(AVG(reservoir_pressure_mpa), 2) AS avg_reservoir_pressure_mpa,
    COUNT(partner_session_id) AS repairs_with_partner_measurement
FROM frac_mart.v_repair_with_partner_well_measurements
GROUP BY date_trunc('quarter', repair_date)::date,
         field_code, field_name, repair_type_code, repair_type_name;

COMMENT ON VIEW frac_mart.v_quarterly_repairs_with_well_measurements IS
'Квартальная аналитика ремонтов, дополненная добычными и пластовыми замерами из partner_1.';
