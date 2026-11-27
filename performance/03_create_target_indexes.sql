-- Создание трёх целевых индексов после сохранения baseline.
-- Если индекс уже существует, CREATE IF NOT EXISTS не пересоздаёт его.

CREATE INDEX IF NOT EXISTS idx_repair_stage_started_at_btree
    ON frac_core.repair_stage USING btree (started_at);

CREATE INDEX IF NOT EXISTS idx_well_repair_active_fleet_start
    ON frac_core.well_repair USING btree (frac_fleet_id, planned_start_at DESC)
    WHERE repair_status IN ('planned', 'in_progress');

CREATE INDEX IF NOT EXISTS idx_telemetry_measured_at_brin
    ON frac_core.telemetry_measurement USING brin (measured_at)
    WITH (pages_per_range = 64);

ANALYZE frac_core.repair_stage;
ANALYZE frac_core.well_repair;
ANALYZE frac_core.telemetry_measurement;
