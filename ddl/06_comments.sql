-- Комментарии к таблицам.
COMMENT ON TABLE frac_core.oil_field IS 'Справочник месторождений.';
COMMENT ON TABLE frac_core.well IS 'Скважины, относящиеся к месторождениям.';
COMMENT ON TABLE frac_core.frac_fleet IS 'Флоты гидравлического разрыва пласта.';
COMMENT ON TABLE frac_core.equipment_type IS 'Справочник типов оборудования флотов ГРП.';
COMMENT ON TABLE frac_core.equipment_unit IS 'Отдельные инвентарные единицы оборудования.';
COMMENT ON TABLE frac_core.fleet_unit_assignment IS 'История закрепления единиц оборудования за флотами; интервалы не должны пересекаться.';
COMMENT ON TABLE frac_core.crew IS 'Рабочие бригады, ответственные за проведение операций.';
COMMENT ON TABLE frac_core.repair_type IS 'Справочник видов ремонтно-технологических работ.';
COMMENT ON TABLE frac_core.well_repair IS 'Ремонтно-технологические операции на скважинах.';
COMMENT ON TABLE frac_core.repair_stage IS 'Этапы выполнения ремонтной операции.';
COMMENT ON TABLE frac_core.telemetry_measurement IS 'Временные измерения технологических параметров на этапах ремонта.';
COMMENT ON TABLE frac_core.equipment_maintenance IS 'События технического обслуживания единиц оборудования.';

-- Комментарии к полям: oil_field.
COMMENT ON COLUMN frac_core.oil_field.oil_field_id IS 'Первичный суррогатный идентификатор месторождения.';
COMMENT ON COLUMN frac_core.oil_field.field_code IS 'Уникальный бизнес-код месторождения.';
COMMENT ON COLUMN frac_core.oil_field.field_name IS 'Наименование месторождения.';
COMMENT ON COLUMN frac_core.oil_field.region_name IS 'Регион расположения месторождения.';
COMMENT ON COLUMN frac_core.oil_field.description IS 'Дополнительное описание месторождения.';

-- well.
COMMENT ON COLUMN frac_core.well.well_id IS 'Первичный суррогатный идентификатор скважины.';
COMMENT ON COLUMN frac_core.well.oil_field_id IS 'Внешний ключ на месторождение.';
COMMENT ON COLUMN frac_core.well.well_code IS 'Код скважины, уникальный в пределах месторождения.';
COMMENT ON COLUMN frac_core.well.well_type IS 'Тип скважины: production, injection или observation.';
COMMENT ON COLUMN frac_core.well.well_status IS 'Текущий статус скважины.';
COMMENT ON COLUMN frac_core.well.commissioning_date IS 'Дата ввода скважины в эксплуатацию.';
COMMENT ON COLUMN frac_core.well.design_depth_m IS 'Проектная глубина скважины, м.';

-- frac_fleet.
COMMENT ON COLUMN frac_core.frac_fleet.frac_fleet_id IS 'Первичный суррогатный идентификатор флота.';
COMMENT ON COLUMN frac_core.frac_fleet.fleet_code IS 'Уникальный код флота ГРП.';
COMMENT ON COLUMN frac_core.frac_fleet.fleet_name IS 'Наименование флота.';
COMMENT ON COLUMN frac_core.frac_fleet.fleet_status IS 'Состояние флота: active, standby, maintenance или decommissioned.';
COMMENT ON COLUMN frac_core.frac_fleet.max_operating_pressure_mpa IS 'Максимальное рабочее давление флота, МПа.';
COMMENT ON COLUMN frac_core.frac_fleet.base_location IS 'Базовое место размещения флота.';

-- equipment_type.
COMMENT ON COLUMN frac_core.equipment_type.equipment_type_id IS 'Первичный суррогатный идентификатор типа оборудования.';
COMMENT ON COLUMN frac_core.equipment_type.type_code IS 'Уникальный код типа оборудования.';
COMMENT ON COLUMN frac_core.equipment_type.type_name IS 'Наименование типа оборудования.';
COMMENT ON COLUMN frac_core.equipment_type.category IS 'Категория оборудования.';
COMMENT ON COLUMN frac_core.equipment_type.description IS 'Описание назначения типа оборудования.';

-- equipment_unit.
COMMENT ON COLUMN frac_core.equipment_unit.equipment_unit_id IS 'Первичный суррогатный идентификатор единицы оборудования.';
COMMENT ON COLUMN frac_core.equipment_unit.equipment_type_id IS 'Внешний ключ на тип оборудования.';
COMMENT ON COLUMN frac_core.equipment_unit.equipment_code IS 'Уникальный внутренний инвентарный код.';
COMMENT ON COLUMN frac_core.equipment_unit.serial_number IS 'Заводской номер оборудования, если известен.';
COMMENT ON COLUMN frac_core.equipment_unit.manufacturer IS 'Производитель оборудования.';
COMMENT ON COLUMN frac_core.equipment_unit.model_name IS 'Модель оборудования.';
COMMENT ON COLUMN frac_core.equipment_unit.manufacture_year IS 'Год изготовления оборудования.';
COMMENT ON COLUMN frac_core.equipment_unit.commissioning_date IS 'Дата ввода оборудования в эксплуатацию.';
COMMENT ON COLUMN frac_core.equipment_unit.technical_status IS 'Техническое состояние единицы оборудования.';

-- fleet_unit_assignment.
COMMENT ON COLUMN frac_core.fleet_unit_assignment.assignment_id IS 'Первичный суррогатный идентификатор назначения.';
COMMENT ON COLUMN frac_core.fleet_unit_assignment.frac_fleet_id IS 'Флот, за которым закреплена единица оборудования.';
COMMENT ON COLUMN frac_core.fleet_unit_assignment.equipment_unit_id IS 'Единица оборудования, включённая в состав флота.';
COMMENT ON COLUMN frac_core.fleet_unit_assignment.assigned_at IS 'Момент начала закрепления оборудования.';
COMMENT ON COLUMN frac_core.fleet_unit_assignment.released_at IS 'Момент окончания закрепления; NULL означает действующее назначение.';
COMMENT ON COLUMN frac_core.fleet_unit_assignment.assignment_reason IS 'Причина или комментарий к назначению.';

-- crew.
COMMENT ON COLUMN frac_core.crew.crew_id IS 'Первичный суррогатный идентификатор бригады.';
COMMENT ON COLUMN frac_core.crew.crew_code IS 'Уникальный код бригады.';
COMMENT ON COLUMN frac_core.crew.crew_name IS 'Наименование бригады.';
COMMENT ON COLUMN frac_core.crew.specialization IS 'Основная специализация бригады.';
COMMENT ON COLUMN frac_core.crew.crew_status IS 'Статус бригады: active или inactive.';

-- repair_type.
COMMENT ON COLUMN frac_core.repair_type.repair_type_id IS 'Первичный суррогатный идентификатор вида ремонта.';
COMMENT ON COLUMN frac_core.repair_type.repair_type_code IS 'Уникальный код вида ремонта.';
COMMENT ON COLUMN frac_core.repair_type.type_name IS 'Наименование вида ремонта.';
COMMENT ON COLUMN frac_core.repair_type.description IS 'Описание вида ремонта.';
COMMENT ON COLUMN frac_core.repair_type.planned_duration_hours IS 'Нормативная или плановая продолжительность, ч.';

-- well_repair.
COMMENT ON COLUMN frac_core.well_repair.repair_id IS 'Первичный суррогатный идентификатор ремонтной операции.';
COMMENT ON COLUMN frac_core.well_repair.repair_code IS 'Уникальный код ремонтной операции.';
COMMENT ON COLUMN frac_core.well_repair.well_id IS 'Скважина, на которой проводится ремонт.';
COMMENT ON COLUMN frac_core.well_repair.frac_fleet_id IS 'Основной флот ГРП, выполняющий ремонт.';
COMMENT ON COLUMN frac_core.well_repair.crew_id IS 'Ответственная рабочая бригада.';
COMMENT ON COLUMN frac_core.well_repair.repair_type_id IS 'Вид ремонтно-технологической операции.';
COMMENT ON COLUMN frac_core.well_repair.planned_start_at IS 'Плановое время начала операции.';
COMMENT ON COLUMN frac_core.well_repair.planned_end_at IS 'Плановое время окончания операции.';
COMMENT ON COLUMN frac_core.well_repair.actual_start_at IS 'Фактическое время начала операции.';
COMMENT ON COLUMN frac_core.well_repair.actual_end_at IS 'Фактическое время окончания операции.';
COMMENT ON COLUMN frac_core.well_repair.repair_status IS 'Статус ремонта: planned, in_progress, completed или cancelled.';
COMMENT ON COLUMN frac_core.well_repair.result_description IS 'Описание результата и замечания по операции.';

-- repair_stage.
COMMENT ON COLUMN frac_core.repair_stage.repair_stage_id IS 'Первичный суррогатный идентификатор этапа.';
COMMENT ON COLUMN frac_core.repair_stage.repair_id IS 'Ремонтная операция, к которой относится этап.';
COMMENT ON COLUMN frac_core.repair_stage.stage_number IS 'Порядковый номер этапа в рамках ремонта.';
COMMENT ON COLUMN frac_core.repair_stage.stage_name IS 'Наименование этапа.';
COMMENT ON COLUMN frac_core.repair_stage.stage_status IS 'Статус выполнения этапа.';
COMMENT ON COLUMN frac_core.repair_stage.started_at IS 'Фактическое начало этапа.';
COMMENT ON COLUMN frac_core.repair_stage.ended_at IS 'Фактическое окончание этапа.';

-- telemetry_measurement.
COMMENT ON COLUMN frac_core.telemetry_measurement.measurement_id IS 'Первичный суррогатный идентификатор измерения.';
COMMENT ON COLUMN frac_core.telemetry_measurement.repair_stage_id IS 'Этап ремонта, к которому относится измерение.';
COMMENT ON COLUMN frac_core.telemetry_measurement.measured_at IS 'Время фиксации технологических показателей.';
COMMENT ON COLUMN frac_core.telemetry_measurement.pressure_mpa IS 'Давление, МПа.';
COMMENT ON COLUMN frac_core.telemetry_measurement.fluid_rate_m3_min IS 'Расход жидкости, м3/мин.';
COMMENT ON COLUMN frac_core.telemetry_measurement.proppant_concentration_kg_m3 IS 'Концентрация проппанта, кг/м3.';
COMMENT ON COLUMN frac_core.telemetry_measurement.cumulative_fluid_volume_m3 IS 'Накопительный объём жидкости по счётчику, м3.';
COMMENT ON COLUMN frac_core.telemetry_measurement.cumulative_proppant_mass_t IS 'Накопительная масса проппанта по счётчику, т.';

-- equipment_maintenance.
COMMENT ON COLUMN frac_core.equipment_maintenance.maintenance_id IS 'Первичный суррогатный идентификатор обслуживания.';
COMMENT ON COLUMN frac_core.equipment_maintenance.equipment_unit_id IS 'Единица оборудования, проходящая обслуживание.';
COMMENT ON COLUMN frac_core.equipment_maintenance.maintenance_type IS 'Тип обслуживания: planned_service, inspection, repair или unscheduled.';
COMMENT ON COLUMN frac_core.equipment_maintenance.maintenance_status IS 'Статус обслуживания.';
COMMENT ON COLUMN frac_core.equipment_maintenance.started_at IS 'Начало обслуживания или запланированное начало.';
COMMENT ON COLUMN frac_core.equipment_maintenance.ended_at IS 'Окончание обслуживания.';
COMMENT ON COLUMN frac_core.equipment_maintenance.next_due_date IS 'Плановая дата следующего обслуживания.';
COMMENT ON COLUMN frac_core.equipment_maintenance.description IS 'Описание выполненных работ или замечаний.';
