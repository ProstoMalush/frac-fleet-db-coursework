-- Бизнес-вопрос 1.
-- Какие ремонты проводились на каждом месторождении за квартал?
-- Результат: количество завершённых ремонтов, число скважин и средняя длительность.
-- Данные синтетические. Запрос не изменяет данные.

SELECT
    f.field_code,
    f.field_name,
    date_trunc('quarter', r.actual_start_at)::date AS quarter_start,
    COUNT(*) AS completed_repairs,
    COUNT(DISTINCT w.well_id) AS wells_repaired,
    ROUND(
        AVG(EXTRACT(EPOCH FROM (r.actual_end_at - r.actual_start_at)) / 3600.0)::numeric,
        2
    ) AS avg_actual_duration_hours
FROM frac_core.well_repair AS r
JOIN frac_core.well AS w
    ON w.well_id = r.well_id
JOIN frac_core.oil_field AS f
    ON f.oil_field_id = w.oil_field_id
WHERE r.repair_status = 'completed'
  AND r.actual_start_at IS NOT NULL
  AND r.actual_end_at IS NOT NULL
GROUP BY
    f.field_code,
    f.field_name,
    date_trunc('quarter', r.actual_start_at)::date
ORDER BY quarter_start, f.field_name;

-- Для просмотра одного квартала добавьте, например:
-- AND r.actual_start_at >= TIMESTAMPTZ '2025-01-01 00:00:00+00'
-- AND r.actual_start_at <  TIMESTAMPTZ '2025-04-01 00:00:00+00'
