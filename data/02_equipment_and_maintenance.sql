-- ЭТАП 4.2. Наполнение парка оборудования, истории его распределения и обслуживания.
-- Все активы являются синтетическими учебными примерами.
-- Запускать после 01_reference_data.sql.
-- Скрипт допускает повторный запуск.

BEGIN;

-- 1. Создаём 72 единицы оборудования: по 6 единиц каждого из 12 типов.
WITH generated AS (
    SELECT n,
           ((n - 1) % 12) + 1 AS type_no
    FROM generate_series(1, 72) AS g(n)
), type_map AS (
    SELECT equipment_type_id,
           row_number() OVER (ORDER BY type_code) AS type_no
    FROM frac_core.equipment_type
    WHERE type_code LIKE 'SYN-TYP-%'
)
INSERT INTO frac_core.equipment_unit
    (equipment_type_id, equipment_code, serial_number, manufacturer,
     model_name, manufacture_year, commissioning_date, technical_status)
SELECT
    tm.equipment_type_id,
    'SYN-EQP-' || lpad(g.n::text, 4, '0'),
    'SYN-SN-' || lpad(g.n::text, 6, '0'),
    CASE g.n % 4
        WHEN 0 THEN 'Производитель-А (синтетический)'
        WHEN 1 THEN 'Производитель-Б (синтетический)'
        WHEN 2 THEN 'Производитель-В (синтетический)'
        ELSE 'Производитель-Г (синтетический)'
    END,
    'Учебная модель ' || lpad(g.type_no::text, 2, '0'),
    (2015 + (g.n % 10))::smallint,
    DATE '2018-01-01' + ((g.n * 19) % 1500),
    CASE WHEN g.n % 13 = 0 THEN 'restricted' ELSE 'serviceable' END
FROM generated g
JOIN type_map tm ON tm.type_no = g.type_no
ON CONFLICT (equipment_code) DO NOTHING;

-- 2. Исторические назначения для первых 12 единиц оборудования.
-- Период закрывается точно в момент начала следующего назначения (границы [)).
WITH equipment_ranked AS (
    SELECT equipment_unit_id,
           row_number() OVER (ORDER BY equipment_code) AS rn
    FROM frac_core.equipment_unit
    WHERE equipment_code LIKE 'SYN-EQP-%'
), fleet_ranked AS (
    SELECT frac_fleet_id,
           row_number() OVER (ORDER BY fleet_code) AS rn
    FROM frac_core.frac_fleet
    WHERE fleet_code LIKE 'SYN-FRAC-%'
)
INSERT INTO frac_core.fleet_unit_assignment
    (frac_fleet_id, equipment_unit_id, assigned_at, released_at, assignment_reason)
SELECT
    f.frac_fleet_id,
    e.equipment_unit_id,
    TIMESTAMPTZ '2023-01-01 08:00:00+00' + (e.rn % 28)::double precision * INTERVAL '1 day',
    TIMESTAMPTZ '2024-01-01 08:00:00+00' + (e.rn % 28)::double precision * INTERVAL '1 day',
    'Историческое закрепление; синтетические данные'
FROM equipment_ranked e
JOIN fleet_ranked f ON f.rn = (e.rn % 6) + 1
WHERE e.rn <= 12
  AND NOT EXISTS (
      SELECT 1
      FROM frac_core.fleet_unit_assignment x
      WHERE x.equipment_unit_id = e.equipment_unit_id
        AND x.assigned_at = TIMESTAMPTZ '2023-01-01 08:00:00+00' + (e.rn % 28)::double precision * INTERVAL '1 day'
  );

-- 3. Текущее закрепление всех 72 единиц за одним из шести флотов.
WITH equipment_ranked AS (
    SELECT equipment_unit_id,
           row_number() OVER (ORDER BY equipment_code) AS rn
    FROM frac_core.equipment_unit
    WHERE equipment_code LIKE 'SYN-EQP-%'
), fleet_ranked AS (
    SELECT frac_fleet_id,
           row_number() OVER (ORDER BY fleet_code) AS rn
    FROM frac_core.frac_fleet
    WHERE fleet_code LIKE 'SYN-FRAC-%'
), assignment_rows AS (
    SELECT e.equipment_unit_id,
           f.frac_fleet_id,
           TIMESTAMPTZ '2024-01-01 08:00:00+00' + (e.rn % 28)::double precision * INTERVAL '1 day' AS assigned_at
    FROM equipment_ranked e
    JOIN fleet_ranked f ON f.rn = ((e.rn - 1) % 6) + 1
)
INSERT INTO frac_core.fleet_unit_assignment
    (frac_fleet_id, equipment_unit_id, assigned_at, released_at, assignment_reason)
SELECT frac_fleet_id, equipment_unit_id, assigned_at, NULL,
       'Текущее закрепление в составе учебного флота'
FROM assignment_rows a
WHERE NOT EXISTS (
    SELECT 1
    FROM frac_core.fleet_unit_assignment x
    WHERE x.equipment_unit_id = a.equipment_unit_id
      AND x.assigned_at = a.assigned_at
);

-- 4. По одной завершённой записи ТО на каждую единицу оборудования.
-- Интервалы не пересекаются, так как для каждого оборудования создаётся одна запись.
WITH equipment_ranked AS (
    SELECT equipment_unit_id,
           row_number() OVER (ORDER BY equipment_code) AS rn
    FROM frac_core.equipment_unit
    WHERE equipment_code LIKE 'SYN-EQP-%'
), maintenance_rows AS (
    SELECT equipment_unit_id,
           TIMESTAMPTZ '2024-02-01 07:00:00+00' + rn::double precision * INTERVAL '5 days' AS started_at,
           (4 + (rn % 5)) * INTERVAL '1 hour' AS duration,
           rn
    FROM equipment_ranked
)
INSERT INTO frac_core.equipment_maintenance
    (equipment_unit_id, maintenance_type, maintenance_status,
     started_at, ended_at, next_due_date, description)
SELECT
    equipment_unit_id,
    CASE rn % 4
        WHEN 0 THEN 'planned_service'
        WHEN 1 THEN 'inspection'
        WHEN 2 THEN 'repair'
        ELSE 'unscheduled'
    END,
    'completed',
    started_at,
    started_at + duration,
    (started_at::date + 365),
    'Синтетическая запись технического обслуживания для учебной БД.'
FROM maintenance_rows m
WHERE NOT EXISTS (
    SELECT 1
    FROM frac_core.equipment_maintenance x
    WHERE x.equipment_unit_id = m.equipment_unit_id
      AND x.started_at = m.started_at
);

COMMIT;

-- Контрольные количества.
SELECT 'equipment_unit' AS table_name, count(*) AS rows_count
FROM frac_core.equipment_unit WHERE equipment_code LIKE 'SYN-EQP-%'
UNION ALL
SELECT 'fleet_unit_assignment', count(*)
FROM frac_core.fleet_unit_assignment a
JOIN frac_core.equipment_unit e USING (equipment_unit_id)
WHERE e.equipment_code LIKE 'SYN-EQP-%'
UNION ALL
SELECT 'equipment_maintenance', count(*)
FROM frac_core.equipment_maintenance m
JOIN frac_core.equipment_unit e USING (equipment_unit_id)
WHERE e.equipment_code LIKE 'SYN-EQP-%'
ORDER BY table_name;
