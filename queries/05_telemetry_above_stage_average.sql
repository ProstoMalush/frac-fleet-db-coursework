-- Бизнес-вопрос 4.
-- Какие измерения давления заметно превышают среднее давление своего этапа?
-- Это пример коррелированного подзапроса: внутренний запрос зависит от
-- repair_stage_id внешней строки m.
-- Выводятся измерения выше среднего по этапу более чем на 3%.
-- Данные синтетические. Порог 3% выбран для демонстрации аналитического запроса,
-- а не является нормативным технологическим пределом.

SELECT
    f.field_name,
    w.well_code,
    r.repair_code,
    s.stage_number,
    s.stage_name,
    m.measured_at,
    m.pressure_mpa,
    (
        SELECT ROUND(AVG(m2.pressure_mpa), 2)
        FROM frac_core.telemetry_measurement AS m2
        WHERE m2.repair_stage_id = m.repair_stage_id
    ) AS stage_avg_pressure_mpa
FROM frac_core.telemetry_measurement AS m
JOIN frac_core.repair_stage AS s
    ON s.repair_stage_id = m.repair_stage_id
JOIN frac_core.well_repair AS r
    ON r.repair_id = s.repair_id
JOIN frac_core.well AS w
    ON w.well_id = r.well_id
JOIN frac_core.oil_field AS f
    ON f.oil_field_id = w.oil_field_id
WHERE m.pressure_mpa > 1.03 * (
    SELECT AVG(m2.pressure_mpa)
    FROM frac_core.telemetry_measurement AS m2
    WHERE m2.repair_stage_id = m.repair_stage_id
)
ORDER BY m.pressure_mpa DESC, m.measured_at
LIMIT 100;
