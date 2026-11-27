-- ВНИМАНИЕ: временно удаляет три целевых индекса и старый дублирующий индекс,
-- если он остался от первоначальной версии этапа 3. Данные не удаляются.
-- После baseline обязательно выполните 03_create_target_indexes.sql.
DROP INDEX IF EXISTS frac_core.idx_well_repair_actual_start_btree;
DROP INDEX IF EXISTS frac_core.idx_repair_stage_started_at_btree;
DROP INDEX IF EXISTS frac_core.idx_well_repair_active_fleet_start;
DROP INDEX IF EXISTS frac_core.idx_telemetry_measured_at_brin;

ANALYZE frac_core.repair_stage;
ANALYZE frac_core.well_repair;
ANALYZE frac_core.telemetry_measurement;
