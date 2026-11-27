-- Сравнение с 05_telemetry_above_stage_average.sql.
-- Это некоррелированный вариант того же бизнес-расчёта.
-- Сначала CTE вычисляет среднее давление отдельно для каждого этапа,
-- затем результат присоединяется к телеметрии обычным JOIN.
-- Результат должен совпадать с коррелированным вариантом при одинаковых данных.

WITH stage_average AS (
    SELECT
        repair_stage_id,
        AVG(pressure_mpa) AS avg_pressure_mpa
    FROM frac_core.telemetry_measurement
    WHERE pressure_mpa IS NOT NULL
    GROUP BY repair_stage_id
)
SELECT
    f.field_name,
    w.well_code,
    r.repair_code,
    s.stage_number,
    s.stage_name,
    m.measured_at,
    m.pressure_mpa,
    ROUND(sa.avg_pressure_mpa, 2) AS stage_avg_pressure_mpa
FROM frac_core.telemetry_measurement AS m
JOIN stage_average AS sa
    ON sa.repair_stage_id = m.repair_stage_id
JOIN frac_core.repair_stage AS s
    ON s.repair_stage_id = m.repair_stage_id
JOIN frac_core.well_repair AS r
    ON r.repair_id = s.repair_id
JOIN frac_core.well AS w
    ON w.well_id = r.well_id
JOIN frac_core.oil_field AS f
    ON f.oil_field_id = w.oil_field_id
WHERE m.pressure_mpa > 1.03 * sa.avg_pressure_mpa
ORDER BY m.pressure_mpa DESC, m.measured_at
LIMIT 100;
