-- Бизнес-вопрос 3.
-- На каких скважинах ремонты проводились повторно и сколько времени прошло
-- между завершением предыдущего ремонта и началом следующего?
-- LAG() — оконная функция, возвращающая значение из предыдущей строки в группе.
-- Данные синтетические. Запрос не изменяет данные.

WITH repair_history AS (
    SELECT
        f.field_name,
        w.well_code,
        r.repair_id,
        r.repair_code,
        r.actual_start_at,
        r.actual_end_at,
        LAG(r.repair_code) OVER (
            PARTITION BY r.well_id
            ORDER BY r.actual_start_at, r.repair_id
        ) AS previous_repair_code,
        LAG(r.actual_end_at) OVER (
            PARTITION BY r.well_id
            ORDER BY r.actual_start_at, r.repair_id
        ) AS previous_repair_end_at
    FROM frac_core.well_repair AS r
    JOIN frac_core.well AS w
        ON w.well_id = r.well_id
    JOIN frac_core.oil_field AS f
        ON f.oil_field_id = w.oil_field_id
    WHERE r.repair_status = 'completed'
      AND r.actual_start_at IS NOT NULL
      AND r.actual_end_at IS NOT NULL
)
SELECT
    field_name,
    well_code,
    previous_repair_code,
    repair_code AS current_repair_code,
    previous_repair_end_at,
    actual_start_at AS current_repair_start_at,
    ROUND(
        (EXTRACT(EPOCH FROM (actual_start_at - previous_repair_end_at)) / 86400.0)::numeric,
        2
    ) AS days_between_repairs
FROM repair_history
WHERE previous_repair_end_at IS NOT NULL
ORDER BY days_between_repairs, field_name, well_code;
