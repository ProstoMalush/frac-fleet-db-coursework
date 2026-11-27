-- ЭТАП 4.3. Генерация ремонтов и этапов выполнения.
-- 420 завершённых ремонтов за 2023–2026 гг. + 6 будущих запланированных ремонтов.
-- На каждый завершённый ремонт формируются 4 завершённых этапа.
-- Все данные синтетические; временные отметки зафиксированы для воспроизводимости.
-- Запускать после 01_reference_data.sql и 02_equipment_and_maintenance.sql.
-- Скрипт допускает повторный запуск.

BEGIN;

-- 1. Исторические завершённые ремонты.
WITH generated AS (
    SELECT n,
           TIMESTAMPTZ '2023-01-01 06:00:00+00'
             + (((n - 1) * 3 + (n % 3))::double precision * INTERVAL '1 day')
             + ((n % 8)::double precision * INTERVAL '1 hour') AS planned_start_at
    FROM generate_series(1, 420) AS g(n)
), wells AS (
    SELECT well_id, row_number() OVER (ORDER BY oil_field_id, well_code) AS rn
    FROM frac_core.well
    WHERE well_code LIKE 'SYN-W-%'
), fleets AS (
    SELECT frac_fleet_id, row_number() OVER (ORDER BY fleet_code) AS rn
    FROM frac_core.frac_fleet
    WHERE fleet_code LIKE 'SYN-FRAC-%'
), crews AS (
    SELECT crew_id, row_number() OVER (ORDER BY crew_code) AS rn
    FROM frac_core.crew
    WHERE crew_code LIKE 'SYN-CR-%'
), repair_types AS (
    SELECT repair_type_id, planned_duration_hours,
           row_number() OVER (ORDER BY repair_type_code) AS rn
    FROM frac_core.repair_type
    WHERE repair_type_code LIKE 'SYN-RTP-%'
), repair_rows AS (
    SELECT g.n,
           g.planned_start_at,
           w.well_id,
           f.frac_fleet_id,
           c.crew_id,
           rt.repair_type_id,
           rt.planned_duration_hours,
           g.planned_start_at + rt.planned_duration_hours::double precision * INTERVAL '1 hour' AS planned_end_at,
           g.planned_start_at + ((g.n % 7) - 3)::double precision * INTERVAL '1 hour' AS actual_start_at,
           (rt.planned_duration_hours * (0.80 + (g.n % 8) * 0.05))::double precision
               * INTERVAL '1 hour' AS actual_duration
    FROM generated g
    JOIN wells w ON w.rn = ((g.n - 1) % 100) + 1
    JOIN fleets f ON f.rn = ((g.n - 1) % 6) + 1
    JOIN crews c ON c.rn = ((g.n - 1) % 12) + 1
    JOIN repair_types rt ON rt.rn = ((g.n - 1) % 8) + 1
)
INSERT INTO frac_core.well_repair
    (repair_code, well_id, frac_fleet_id, crew_id, repair_type_id,
     planned_start_at, planned_end_at, actual_start_at, actual_end_at,
     repair_status, result_description)
SELECT
    'SYN-RPR-' || lpad(n::text, 6, '0'),
    well_id, frac_fleet_id, crew_id, repair_type_id,
    planned_start_at, planned_end_at,
    actual_start_at, actual_start_at + actual_duration,
    'completed',
    CASE n % 4
        WHEN 0 THEN 'Операция завершена; замечаний по учебному сценарию нет.'
        WHEN 1 THEN 'Операция завершена с корректировкой технологического режима.'
        WHEN 2 THEN 'Операция завершена после дополнительной проверки оборудования.'
        ELSE 'Операция завершена; параметры сохранены в телеметрии.'
    END
FROM repair_rows
ON CONFLICT (repair_code) DO NOTHING;

-- 2. Шесть будущих плановых ремонтов: они нужны, в частности, для проверки
-- частичного индекса по planned/in_progress. Фактических дат у них пока нет.
WITH generated AS (
    SELECT n,
           TIMESTAMPTZ '2026-12-01 06:00:00+00' + ((n - 1) * 7)::double precision * INTERVAL '1 day' AS planned_start_at
    FROM generate_series(1, 6) AS g(n)
), wells AS (
    SELECT well_id, row_number() OVER (ORDER BY oil_field_id, well_code) AS rn
    FROM frac_core.well WHERE well_code LIKE 'SYN-W-%'
), fleets AS (
    SELECT frac_fleet_id, row_number() OVER (ORDER BY fleet_code) AS rn
    FROM frac_core.frac_fleet WHERE fleet_code LIKE 'SYN-FRAC-%'
), crews AS (
    SELECT crew_id, row_number() OVER (ORDER BY crew_code) AS rn
    FROM frac_core.crew WHERE crew_code LIKE 'SYN-CR-%'
), repair_types AS (
    SELECT repair_type_id, planned_duration_hours,
           row_number() OVER (ORDER BY repair_type_code) AS rn
    FROM frac_core.repair_type WHERE repair_type_code LIKE 'SYN-RTP-%'
)
INSERT INTO frac_core.well_repair
    (repair_code, well_id, frac_fleet_id, crew_id, repair_type_id,
     planned_start_at, planned_end_at, actual_start_at, actual_end_at,
     repair_status, result_description)
SELECT
    'SYN-PLAN-' || lpad(g.n::text, 3, '0'),
    w.well_id, f.frac_fleet_id, c.crew_id, rt.repair_type_id,
    g.planned_start_at,
    g.planned_start_at + rt.planned_duration_hours::double precision * INTERVAL '1 hour',
    NULL, NULL, 'planned',
    'Запланированная синтетическая операция; фактические работы ещё не начались.'
FROM generated g
JOIN wells w ON w.rn = 80 + g.n
JOIN fleets f ON f.rn = ((g.n - 1) % 6) + 1
JOIN crews c ON c.rn = ((g.n - 1) % 12) + 1
JOIN repair_types rt ON rt.rn = ((g.n - 1) % 8) + 1
ON CONFLICT (repair_code) DO NOTHING;

-- 3. Четыре этапа для каждого завершённого ремонта.
-- Доли длительности: 10%, 15%, 55%, 20%; последний этап заканчивается точно в actual_end_at.
WITH stage_def AS (
    SELECT * FROM (VALUES
        (1::smallint, 'Подготовка площадки', 0.00::double precision, 0.10::double precision),
        (2::smallint, 'Монтаж и опрессовка оборудования', 0.10::double precision, 0.25::double precision),
        (3::smallint, 'Основная технологическая операция', 0.25::double precision, 0.80::double precision),
        (4::smallint, 'Завершение и демонтаж', 0.80::double precision, 1.00::double precision)
    ) AS v(stage_number, stage_name, start_fraction, end_fraction)
), completed_stage_rows AS (
    SELECT r.repair_id, d.stage_number, d.stage_name,
           r.actual_start_at + (r.actual_end_at - r.actual_start_at) * d.start_fraction AS started_at,
           r.actual_start_at + (r.actual_end_at - r.actual_start_at) * d.end_fraction AS ended_at
    FROM frac_core.well_repair r
    CROSS JOIN stage_def d
    WHERE r.repair_code LIKE 'SYN-RPR-%'
      AND r.repair_status = 'completed'
      AND r.actual_start_at IS NOT NULL
      AND r.actual_end_at IS NOT NULL
)
INSERT INTO frac_core.repair_stage
    (repair_id, stage_number, stage_name, stage_status, started_at, ended_at)
SELECT repair_id, stage_number, stage_name, 'completed', started_at, ended_at
FROM completed_stage_rows
ON CONFLICT (repair_id, stage_number) DO NOTHING;

-- 4. Для плановых ремонтов заранее создаём четыре этапа без фактических дат.
WITH stage_def AS (
    SELECT * FROM (VALUES
        (1::smallint, 'Подготовка площадки'),
        (2::smallint, 'Монтаж и опрессовка оборудования'),
        (3::smallint, 'Основная технологическая операция'),
        (4::smallint, 'Завершение и демонтаж')
    ) AS v(stage_number, stage_name)
)
INSERT INTO frac_core.repair_stage
    (repair_id, stage_number, stage_name, stage_status, started_at, ended_at)
SELECT r.repair_id, d.stage_number, d.stage_name, 'planned', NULL, NULL
FROM frac_core.well_repair r
CROSS JOIN stage_def d
WHERE r.repair_code LIKE 'SYN-PLAN-%'
  AND r.repair_status = 'planned'
ON CONFLICT (repair_id, stage_number) DO NOTHING;

COMMIT;

-- Контроль: ожидается 426 ремонтов (420 completed + 6 planned)
-- и 1 704 этапа (1 680 completed + 24 planned).
SELECT repair_status, count(*) AS repairs_count
FROM frac_core.well_repair
WHERE repair_code LIKE 'SYN-RPR-%' OR repair_code LIKE 'SYN-PLAN-%'
GROUP BY repair_status
ORDER BY repair_status;

SELECT stage_status, count(*) AS stages_count
FROM frac_core.repair_stage s
JOIN frac_core.well_repair r USING (repair_id)
WHERE r.repair_code LIKE 'SYN-RPR-%' OR r.repair_code LIKE 'SYN-PLAN-%'
GROUP BY stage_status
ORDER BY stage_status;
