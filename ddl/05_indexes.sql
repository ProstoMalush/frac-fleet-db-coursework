-- Три целевых индекса разных типов для основных таблиц по объёму данных.
-- PostgreSQL 15. Выполнять после создания таблиц и загрузки данных.

-- 1. B-tree: поиск этапов по времени начала (таблица repair_stage).
CREATE INDEX idx_repair_stage_started_at_btree
    ON frac_core.repair_stage USING btree (started_at);

-- 2. Составной частичный B-tree: поиск запланированных/текущих ремонтов флота.
CREATE INDEX idx_well_repair_active_fleet_start
    ON frac_core.well_repair USING btree (frac_fleet_id, planned_start_at DESC)
    WHERE repair_status IN ('planned', 'in_progress');

-- 3. BRIN: временной фильтр по большой таблице телеметрии.
-- Наиболее полезен, если физический порядок строк коррелирует с measured_at.
CREATE INDEX idx_telemetry_measured_at_brin
    ON frac_core.telemetry_measurement USING brin (measured_at)
    WITH (pages_per_range = 64);

-- Поддерживающие B-tree индексы для внешних ключей и типовых JOIN.
CREATE INDEX idx_well_oil_field_id ON frac_core.well (oil_field_id);
CREATE INDEX idx_equipment_unit_type_id ON frac_core.equipment_unit (equipment_type_id);
CREATE INDEX idx_fua_fleet_id ON frac_core.fleet_unit_assignment (frac_fleet_id);
CREATE INDEX idx_fua_equipment_id ON frac_core.fleet_unit_assignment (equipment_unit_id);
CREATE INDEX idx_well_repair_well_id ON frac_core.well_repair (well_id);
CREATE INDEX idx_well_repair_crew_id ON frac_core.well_repair (crew_id);
CREATE INDEX idx_well_repair_type_id ON frac_core.well_repair (repair_type_id);
CREATE INDEX idx_repair_stage_repair_id ON frac_core.repair_stage (repair_id);
CREATE INDEX idx_telemetry_stage_id ON frac_core.telemetry_measurement (repair_stage_id);
CREATE INDEX idx_maintenance_equipment_id ON frac_core.equipment_maintenance (equipment_unit_id);
