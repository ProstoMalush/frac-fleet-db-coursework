-- Бизнес-вопрос 5.
-- Какое оборудование закреплено за каждым флотом и сколько единиц
-- имеют ограниченный технический статус или просроченную дату ТО?
-- Запрос использует CTE (WITH) для выделения текущих назначений и
-- последней записи технического обслуживания по каждой единице оборудования.
-- Значение просрочки рассчитывается относительно CURRENT_DATE на момент запуска.
-- Данные синтетические. Запрос не изменяет данные.

WITH current_assignment AS (
    SELECT
        a.equipment_unit_id,
        a.frac_fleet_id
    FROM frac_core.fleet_unit_assignment AS a
    WHERE a.released_at IS NULL
), latest_maintenance AS (
    SELECT
        m.equipment_unit_id,
        m.maintenance_type,
        m.maintenance_status,
        m.started_at,
        m.ended_at,
        m.next_due_date,
        ROW_NUMBER() OVER (
            PARTITION BY m.equipment_unit_id
            ORDER BY m.started_at DESC, m.maintenance_id DESC
        ) AS rn
    FROM frac_core.equipment_maintenance AS m
), fleet_equipment AS (
    SELECT
        f.frac_fleet_id,
        f.fleet_code,
        f.fleet_name,
        e.equipment_unit_id,
        e.equipment_code,
        et.type_name AS equipment_type_name,
        e.technical_status,
        lm.maintenance_type,
        lm.maintenance_status,
        lm.started_at AS last_maintenance_at,
        lm.next_due_date
    FROM current_assignment AS ca
    JOIN frac_core.frac_fleet AS f
        ON f.frac_fleet_id = ca.frac_fleet_id
    JOIN frac_core.equipment_unit AS e
        ON e.equipment_unit_id = ca.equipment_unit_id
    JOIN frac_core.equipment_type AS et
        ON et.equipment_type_id = e.equipment_type_id
    LEFT JOIN latest_maintenance AS lm
        ON lm.equipment_unit_id = e.equipment_unit_id
       AND lm.rn = 1
)
SELECT
    fleet_code,
    fleet_name,
    COUNT(equipment_unit_id) AS assigned_equipment_count,
    COUNT(*) FILTER (WHERE technical_status = 'restricted') AS restricted_equipment_count,
    COUNT(*) FILTER (
        WHERE next_due_date IS NOT NULL
          AND next_due_date < CURRENT_DATE
    ) AS overdue_maintenance_count,
    COUNT(*) FILTER (
        WHERE next_due_date BETWEEN CURRENT_DATE AND CURRENT_DATE + 30
    ) AS maintenance_due_within_30_days
FROM fleet_equipment
GROUP BY frac_fleet_id, fleet_code, fleet_name
ORDER BY fleet_code;

-- Для детализации конкретных единиц оборудования можно временно заменить
-- финальный SELECT на:
-- SELECT * FROM fleet_equipment ORDER BY fleet_code, equipment_code;
