-- Контроль наполнения БД после выполнения data/01–04.
-- Все приведённые количества относятся к записям с кодами SYN-*.

-- 1. Количество строк по основным таблицам.
SELECT 'oil_field' AS table_name, count(*) AS rows_count
FROM frac_core.oil_field WHERE field_code LIKE 'SYN-FLD-%'
UNION ALL SELECT 'well', count(*) FROM frac_core.well WHERE well_code LIKE 'SYN-W-%'
UNION ALL SELECT 'frac_fleet', count(*) FROM frac_core.frac_fleet WHERE fleet_code LIKE 'SYN-FRAC-%'
UNION ALL SELECT 'equipment_type', count(*) FROM frac_core.equipment_type WHERE type_code LIKE 'SYN-TYP-%'
UNION ALL SELECT 'equipment_unit', count(*) FROM frac_core.equipment_unit WHERE equipment_code LIKE 'SYN-EQP-%'
UNION ALL SELECT 'fleet_unit_assignment', count(*)
    FROM frac_core.fleet_unit_assignment a
    JOIN frac_core.equipment_unit e USING (equipment_unit_id)
    WHERE e.equipment_code LIKE 'SYN-EQP-%'
UNION ALL SELECT 'crew', count(*) FROM frac_core.crew WHERE crew_code LIKE 'SYN-CR-%'
UNION ALL SELECT 'repair_type', count(*) FROM frac_core.repair_type WHERE repair_type_code LIKE 'SYN-RTP-%'
UNION ALL SELECT 'well_repair', count(*)
    FROM frac_core.well_repair WHERE repair_code LIKE 'SYN-RPR-%' OR repair_code LIKE 'SYN-PLAN-%'
UNION ALL SELECT 'repair_stage', count(*)
    FROM frac_core.repair_stage s JOIN frac_core.well_repair r USING (repair_id)
    WHERE r.repair_code LIKE 'SYN-RPR-%' OR r.repair_code LIKE 'SYN-PLAN-%'
UNION ALL SELECT 'telemetry_measurement', count(*)
    FROM frac_core.telemetry_measurement tm
    JOIN frac_core.repair_stage s USING (repair_stage_id)
    JOIN frac_core.well_repair r USING (repair_id)
    WHERE r.repair_code LIKE 'SYN-RPR-%'
UNION ALL SELECT 'equipment_maintenance', count(*)
    FROM frac_core.equipment_maintenance m
    JOIN frac_core.equipment_unit e USING (equipment_unit_id)
    WHERE e.equipment_code LIKE 'SYN-EQP-%'
ORDER BY table_name;

-- 2. Распределение ремонтов по статусам.
SELECT repair_status, count(*) AS repairs_count
FROM frac_core.well_repair
WHERE repair_code LIKE 'SYN-RPR-%' OR repair_code LIKE 'SYN-PLAN-%'
GROUP BY repair_status
ORDER BY repair_status;

-- 3. Контроль ссылочной целостности телеметрии (ожидается 0).
SELECT count(*) AS orphan_measurements
FROM frac_core.telemetry_measurement tm
LEFT JOIN frac_core.repair_stage rs USING (repair_stage_id)
WHERE rs.repair_stage_id IS NULL;

-- 4. Контроль отрицательных технических значений (ожидается 0).
SELECT count(*) AS invalid_telemetry_values
FROM frac_core.telemetry_measurement
WHERE pressure_mpa < 0
   OR fluid_rate_m3_min < 0
   OR proppant_concentration_kg_m3 < 0
   OR cumulative_fluid_volume_m3 < 0
   OR cumulative_proppant_mass_t < 0;

-- 5. Контроль числа измерений (должно быть больше 1 000; ожидаемо 53 760).
SELECT count(*) AS telemetry_measurements
FROM frac_core.telemetry_measurement tm
JOIN frac_core.repair_stage rs USING (repair_stage_id)
JOIN frac_core.well_repair wr USING (repair_id)
WHERE wr.repair_code LIKE 'SYN-RPR-%';

-- 6. Пример последних десяти измерений.
SELECT
    wr.repair_code,
    rs.stage_number,
    tm.measured_at,
    tm.pressure_mpa,
    tm.fluid_rate_m3_min,
    tm.proppant_concentration_kg_m3,
    tm.cumulative_fluid_volume_m3,
    tm.cumulative_proppant_mass_t
FROM frac_core.telemetry_measurement tm
JOIN frac_core.repair_stage rs USING (repair_stage_id)
JOIN frac_core.well_repair wr USING (repair_id)
WHERE wr.repair_code LIKE 'SYN-RPR-%'
ORDER BY tm.measured_at DESC
LIMIT 10;
