-- Запрет пересекающихся периодов закрепления одной единицы оборудования.
-- Диапазон полуоткрытый [начало, окончание); NULL-окончание трактуется как infinity.
ALTER TABLE frac_core.fleet_unit_assignment
    ADD CONSTRAINT ex_fua_equipment_period
    EXCLUDE USING gist (
        equipment_unit_id WITH =,
        (tstzrange(assigned_at, COALESCE(released_at, 'infinity'::timestamptz), '[)')) WITH &&
    );

-- Для одной единицы оборудования не допускаются параллельные интервалы ТО.
ALTER TABLE frac_core.equipment_maintenance
    ADD CONSTRAINT ex_maintenance_equipment_period
    EXCLUDE USING gist (
        equipment_unit_id WITH =,
        (tstzrange(started_at, COALESCE(ended_at, 'infinity'::timestamptz), '[)')) WITH &&
    );
