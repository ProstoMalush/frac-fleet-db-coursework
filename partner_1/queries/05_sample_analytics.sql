-- Примеры аналитических запросов для самостоятельной БД замеров.

-- 1. Последние корректные замеры по выбранной скважине.
SELECT sf.field_code, sw.well_code, ms.measured_at,
       mp.parameter_code, mp.parameter_name, wm.measured_value, mp.unit_name
FROM partner_1.source_well sw
JOIN partner_1.source_field sf USING (source_field_id)
JOIN partner_1.measurement_session ms USING (source_well_id)
JOIN partner_1.well_measurement wm USING (session_id)
JOIN partner_1.measurement_parameter mp USING (parameter_id)
WHERE sf.field_code = 'SYN-FLD-001'
  AND sw.well_code = 'SYN-W-001'
  AND ms.quality_status = 'valid'
ORDER BY ms.measured_at DESC, mp.parameter_code
LIMIT 16;

-- 2. Средний дебит нефти и обводнённость по месторождениям за 2025 год.
SELECT sf.field_code, sf.field_name,
       ROUND(AVG(wm.measured_value) FILTER (WHERE mp.parameter_code = 'OIL_RATE'), 2) AS avg_oil_rate_m3_day,
       ROUND(AVG(wm.measured_value) FILTER (WHERE mp.parameter_code = 'WATER_CUT'), 2) AS avg_water_cut_pct,
       COUNT(DISTINCT ms.session_id) AS sessions_count
FROM partner_1.source_field sf
JOIN partner_1.source_well sw USING (source_field_id)
JOIN partner_1.measurement_session ms USING (source_well_id)
JOIN partner_1.well_measurement wm USING (session_id)
JOIN partner_1.measurement_parameter mp USING (parameter_id)
WHERE ms.measured_at >= TIMESTAMPTZ '2025-01-01 00:00:00+05'
  AND ms.measured_at <  TIMESTAMPTZ '2026-01-01 00:00:00+05'
  AND ms.quality_status = 'valid'
  AND wm.quality_flag = 'valid'
GROUP BY sf.field_code, sf.field_name
ORDER BY sf.field_code;

-- 3. Временной ряд давления выбранной скважины.
SELECT sf.field_code, sw.well_code, ms.measured_at,
       mp.parameter_name, wm.measured_value, mp.unit_name
FROM partner_1.source_well sw
JOIN partner_1.source_field sf USING (source_field_id)
JOIN partner_1.measurement_session ms USING (source_well_id)
JOIN partner_1.well_measurement wm USING (session_id)
JOIN partner_1.measurement_parameter mp USING (parameter_id)
WHERE sf.field_code = 'SYN-FLD-001'
  AND sw.well_code = 'SYN-W-001'
  AND mp.parameter_code IN ('RESERVOIR_PRESSURE','BOTTOMHOLE_PRESSURE')
  AND ms.quality_status = 'valid'
ORDER BY ms.measured_at;
