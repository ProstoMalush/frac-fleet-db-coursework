-- Те же самые запросы после создания индексов.
-- Сравните actual time, rows, loops, shared hit/read blocks и тип доступа.

-- A. B-tree для repair_stage.started_at.
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT repair_stage_id, repair_id, stage_number, stage_name, started_at
FROM frac_core.repair_stage
WHERE started_at >= TIMESTAMPTZ '2025-01-01 00:00:00+00'
  AND started_at <  TIMESTAMPTZ '2025-04-01 00:00:00+00'
ORDER BY started_at;

-- B. Составной частичный B-tree для ремонтов выбранного флота.
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT repair_id, repair_code, frac_fleet_id, planned_start_at, repair_status
FROM frac_core.well_repair
WHERE frac_fleet_id = (
        SELECT frac_fleet_id
        FROM frac_core.frac_fleet
        WHERE fleet_code = 'SYN-FRAC-01'
      )
  AND repair_status IN ('planned', 'in_progress')
  AND planned_start_at >= TIMESTAMPTZ '2026-12-01 00:00:00+00'
  AND planned_start_at <  TIMESTAMPTZ '2027-02-01 00:00:00+00'
ORDER BY planned_start_at DESC;

-- C. BRIN для короткого временного диапазона в таблице телеметрии.
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT measurement_id, repair_stage_id, measured_at, pressure_mpa, fluid_rate_m3_min
FROM frac_core.telemetry_measurement
WHERE measured_at >= TIMESTAMPTZ '2025-01-20 00:00:00+00'
  AND measured_at <  TIMESTAMPTZ '2025-01-27 00:00:00+00'
ORDER BY measured_at;
