-- Диагностика дат ТО.
-- Запрос помогает объяснить результат этапа 5, где все 72 записи ТО
-- классифицировались как просроченные относительно CURRENT_DATE.
-- Никакие данные не изменяются.

SELECT
    CURRENT_DATE AS query_date,
    COUNT(*) AS maintenance_rows,
    COUNT(*) FILTER (WHERE next_due_date IS NULL) AS without_due_date,
    COUNT(*) FILTER (WHERE next_due_date < CURRENT_DATE) AS overdue,
    COUNT(*) FILTER (WHERE next_due_date = CURRENT_DATE) AS due_today,
    COUNT(*) FILTER (WHERE next_due_date BETWEEN CURRENT_DATE + 1 AND CURRENT_DATE + 30) AS due_in_next_30_days,
    MIN(next_due_date) AS earliest_due_date,
    MAX(next_due_date) AS latest_due_date
FROM frac_core.equipment_maintenance;

SELECT
    e.equipment_code,
    f.fleet_code,
    m.maintenance_status,
    m.started_at,
    m.next_due_date,
    CASE
        WHEN m.next_due_date IS NULL THEN 'Дата ТО не задана'
        WHEN m.next_due_date < CURRENT_DATE THEN 'Просрочено'
        WHEN m.next_due_date = CURRENT_DATE THEN 'Срок сегодня'
        WHEN m.next_due_date <= CURRENT_DATE + 30 THEN 'В ближайшие 30 дней'
        ELSE 'Срок позднее 30 дней'
    END AS due_state
FROM frac_core.equipment_maintenance AS m
JOIN frac_core.equipment_unit AS e
    ON e.equipment_unit_id = m.equipment_unit_id
LEFT JOIN frac_core.fleet_unit_assignment AS a
    ON a.equipment_unit_id = e.equipment_unit_id
   AND a.released_at IS NULL
LEFT JOIN frac_core.frac_fleet AS f
    ON f.frac_fleet_id = a.frac_fleet_id
ORDER BY m.next_due_date NULLS LAST, e.equipment_code;
