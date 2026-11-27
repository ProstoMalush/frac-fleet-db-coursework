-- Бизнес-вопрос 2.
-- Какие флоты выполнили больше всего ремонтов и сколько часов заняли работы?
-- Оконная функция DENSE_RANK() ранжирует флоты по суммарной длительности завершённых ремонтов.
-- Данные синтетические. Запрос не изменяет данные.

WITH fleet_metrics AS (
    SELECT
        f.frac_fleet_id,
        f.fleet_code,
        f.fleet_name,
        COUNT(r.repair_id) FILTER (WHERE r.repair_status = 'completed') AS completed_repairs,
        ROUND(
            SUM(
                EXTRACT(EPOCH FROM (r.actual_end_at - r.actual_start_at)) / 3600.0
            ) FILTER (WHERE r.repair_status = 'completed')::numeric,
            2
        ) AS total_actual_hours,
        ROUND(
            AVG(
                EXTRACT(EPOCH FROM (r.actual_end_at - r.actual_start_at)) / 3600.0
            ) FILTER (WHERE r.repair_status = 'completed')::numeric,
            2
        ) AS avg_actual_hours
    FROM frac_core.frac_fleet AS f
    LEFT JOIN frac_core.well_repair AS r
        ON r.frac_fleet_id = f.frac_fleet_id
    GROUP BY f.frac_fleet_id, f.fleet_code, f.fleet_name
)
SELECT
    DENSE_RANK() OVER (ORDER BY COALESCE(total_actual_hours, 0) DESC) AS fleet_rank,
    fleet_code,
    fleet_name,
    completed_repairs,
    COALESCE(total_actual_hours, 0) AS total_actual_hours,
    avg_actual_hours
FROM fleet_metrics
ORDER BY fleet_rank, fleet_code;
