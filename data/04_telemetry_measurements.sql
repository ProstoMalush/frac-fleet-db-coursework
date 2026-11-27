-- ЭТАП 4.4. Генерация временного ряда телеметрии.
-- Для каждого из 1 680 завершённых этапов создаётся 32 измерения:
-- 1 680 * 32 = 53 760 записей при первом запуске на пустой таблице.
-- Данные синтетические, диапазоны предназначены только для учебной аналитики.
-- Запускать после 03_repairs_and_stages.sql.
-- Скрипт допускает повторный запуск благодаря UNIQUE(repair_stage_id, measured_at).

BEGIN;

WITH completed_stages AS (
    SELECT repair_stage_id, stage_number, started_at, ended_at,
           EXTRACT(EPOCH FROM (ended_at - started_at)) / 60.0 AS duration_minutes,
           (2.6 + (repair_stage_id % 7) * 0.20)::numeric AS base_fluid_rate,
           CASE WHEN stage_number = 3
                THEN (70 + (repair_stage_id % 6) * 12)::numeric
                ELSE 0::numeric
           END AS base_proppant_concentration
    FROM frac_core.repair_stage
    WHERE stage_status = 'completed'
      AND started_at IS NOT NULL
      AND ended_at IS NOT NULL
), points AS (
    SELECT s.*,
           g.point_no,
           s.duration_minutes * g.point_no / 32.0 AS elapsed_minutes,
           s.started_at + (s.ended_at - s.started_at)
               * (g.point_no::double precision / 32.0) AS measured_at
    FROM completed_stages s
    CROSS JOIN generate_series(0, 31) AS g(point_no)
), values_to_insert AS (
    SELECT
        repair_stage_id,
        measured_at,
        (25.0 + stage_number * 8.0
             + (point_no % 7) * 0.90
             + (repair_stage_id % 5) * 0.20)::numeric(10,3) AS pressure_mpa,
        (2.50 + (point_no % 5) * 0.25
             + (repair_stage_id % 4) * 0.08)::numeric(10,4) AS fluid_rate_m3_min,
        CASE WHEN stage_number = 3
             THEN (base_proppant_concentration + (point_no % 6) * 10)::numeric(10,3)
             ELSE 0::numeric(10,3)
        END AS proppant_concentration_kg_m3,
        (base_fluid_rate * elapsed_minutes)::numeric(14,3) AS cumulative_fluid_volume_m3,
        (base_proppant_concentration * base_fluid_rate * elapsed_minutes / 1000.0)::numeric(14,3)
            AS cumulative_proppant_mass_t
    FROM points
)
INSERT INTO frac_core.telemetry_measurement
    (repair_stage_id, measured_at, pressure_mpa, fluid_rate_m3_min,
     proppant_concentration_kg_m3, cumulative_fluid_volume_m3,
     cumulative_proppant_mass_t)
SELECT repair_stage_id, measured_at, pressure_mpa, fluid_rate_m3_min,
       proppant_concentration_kg_m3, cumulative_fluid_volume_m3,
       cumulative_proppant_mass_t
FROM values_to_insert
ON CONFLICT (repair_stage_id, measured_at) DO NOTHING;

COMMIT;

-- Контроль количества и временного диапазона телеметрии.
SELECT
    count(*) AS telemetry_rows,
    count(DISTINCT repair_stage_id) AS stages_with_measurements,
    min(measured_at) AS first_measurement_at,
    max(measured_at) AS last_measurement_at,
    round(avg(pressure_mpa), 2) AS avg_pressure_mpa,
    round(max(pressure_mpa), 2) AS max_pressure_mpa,
    round(avg(fluid_rate_m3_min), 2) AS avg_fluid_rate_m3_min
FROM frac_core.telemetry_measurement tm
JOIN frac_core.repair_stage rs USING (repair_stage_id)
JOIN frac_core.well_repair wr USING (repair_id)
WHERE wr.repair_code LIKE 'SYN-RPR-%';
