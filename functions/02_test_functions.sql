-- Проверочные вызовы всех 10 функций.
-- Выполнять после functions/01_create_functions.sql.
-- Все SELECT только читают данные.

-- 1. Продолжительность пяти последних завершённых ремонтов.
SELECT
    r.repair_code,
    frac_core.fn_repair_actual_duration_hours(r.repair_id) AS actual_duration_hours
FROM frac_core.well_repair AS r
WHERE r.repair_status = 'completed'
ORDER BY r.actual_end_at DESC
LIMIT 5;

-- 2–5. Показатели первого этапа, для которого имеются измерения.
WITH sample_stage AS (
    SELECT s.repair_stage_id
    FROM frac_core.repair_stage AS s
    JOIN frac_core.telemetry_measurement AS m
        ON m.repair_stage_id = s.repair_stage_id
    GROUP BY s.repair_stage_id
    ORDER BY s.repair_stage_id
    LIMIT 1
)
SELECT
    ss.repair_stage_id,
    frac_core.fn_stage_avg_pressure_mpa(ss.repair_stage_id) AS avg_pressure_mpa,
    frac_core.fn_stage_max_pressure_mpa(ss.repair_stage_id) AS max_pressure_mpa,
    frac_core.fn_stage_total_fluid_volume_m3(ss.repair_stage_id) AS total_fluid_volume_m3,
    frac_core.fn_stage_total_proppant_mass_t(ss.repair_stage_id) AS total_proppant_mass_t
FROM sample_stage AS ss;

-- 6. Последний завершённый ремонт для первых десяти скважин.
SELECT
    w.well_code,
    frac_core.fn_last_completed_repair_id(w.well_id) AS last_completed_repair_id
FROM frac_core.well AS w
ORDER BY w.well_code
LIMIT 10;

-- 7. Текущее количество оборудования по каждому флоту.
SELECT
    f.fleet_code,
    frac_core.fn_fleet_equipment_count(f.frac_fleet_id, CURRENT_TIMESTAMP) AS current_equipment_count
FROM frac_core.frac_fleet AS f
ORDER BY f.fleet_code;

-- 8. Проверка фактического текущего назначения для первых десяти записей.
SELECT
    e.equipment_code,
    f.fleet_code,
    frac_core.fn_is_equipment_assigned_to_fleet(
        e.equipment_unit_id,
        f.frac_fleet_id,
        CURRENT_TIMESTAMP
    ) AS is_assigned_now
FROM frac_core.fleet_unit_assignment AS a
JOIN frac_core.equipment_unit AS e
    ON e.equipment_unit_id = a.equipment_unit_id
JOIN frac_core.frac_fleet AS f
    ON f.frac_fleet_id = a.frac_fleet_id
WHERE a.released_at IS NULL
ORDER BY e.equipment_code
LIMIT 10;

-- 9. Количество завершённых ремонтов по флотам за 2025 год.
SELECT
    f.fleet_code,
    frac_core.fn_completed_repairs_count(
        f.frac_fleet_id,
        TIMESTAMPTZ '2025-01-01 00:00:00+00',
        TIMESTAMPTZ '2026-01-01 00:00:00+00'
    ) AS completed_repairs_2025
FROM frac_core.frac_fleet AS f
ORDER BY f.fleet_code;

-- 10. Реальное использование предела давления: максимальное зарегистрированное
-- давление по флоту относительно max_operating_pressure_mpa.
SELECT
    f.fleet_code,
    f.max_operating_pressure_mpa AS fleet_pressure_limit_mpa,
    MAX(m.pressure_mpa) AS max_measured_pressure_mpa,
    frac_core.fn_pressure_limit_utilization_pct(
        MAX(m.pressure_mpa),
        f.max_operating_pressure_mpa
    ) AS pressure_limit_utilization_pct
FROM frac_core.frac_fleet AS f
JOIN frac_core.well_repair AS r
    ON r.frac_fleet_id = f.frac_fleet_id
JOIN frac_core.repair_stage AS s
    ON s.repair_id = r.repair_id
JOIN frac_core.telemetry_measurement AS m
    ON m.repair_stage_id = s.repair_stage_id
GROUP BY f.frac_fleet_id, f.fleet_code, f.max_operating_pressure_mpa
ORDER BY f.fleet_code;

-- Граничные случаи для PL/pgSQL-функции №10.
-- Ожидается: NULL, NULL, 75.00 соответственно.
SELECT
    frac_core.fn_pressure_limit_utilization_pct(NULL::numeric, 60::numeric)
        AS null_measured_pressure_returns_null,
    frac_core.fn_pressure_limit_utilization_pct(45::numeric, NULL::numeric)
        AS null_limit_returns_null,
    frac_core.fn_pressure_limit_utilization_pct(45::numeric, 0::numeric)
        AS zero_limit_returns_null,
    frac_core.fn_pressure_limit_utilization_pct(45::numeric, 60::numeric)
        AS normal_result_pct;

-- Дополнительная обработка ошибочных границ периода функции №9.
-- Ожидается 0.
SELECT frac_core.fn_completed_repairs_count(
    1,
    TIMESTAMPTZ '2025-12-31 00:00:00+00',
    TIMESTAMPTZ '2025-01-01 00:00:00+00'
) AS invalid_period_returns_zero;

-- NULL ID и неизвестный ID для функции №1: ожидается NULL.
SELECT
    frac_core.fn_repair_actual_duration_hours(NULL::bigint) AS null_id_returns_null,
    frac_core.fn_repair_actual_duration_hours(-1::bigint) AS unknown_id_returns_null;
