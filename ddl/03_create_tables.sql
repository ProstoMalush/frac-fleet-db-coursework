-- PostgreSQL 15. Выполнять после 01_create_schema.sql и 02_extensions.sql.
-- Скрипт не удаляет существующие таблицы и данные.

CREATE TABLE frac_core.oil_field (
    oil_field_id BIGINT GENERATED ALWAYS AS IDENTITY,
    field_code VARCHAR(30) NOT NULL,
    field_name VARCHAR(150) NOT NULL,
    region_name VARCHAR(100) NOT NULL,
    description TEXT,
    CONSTRAINT pk_oil_field PRIMARY KEY (oil_field_id),
    CONSTRAINT uq_oil_field_code UNIQUE (field_code),
    CONSTRAINT ck_oil_field_code_nonempty CHECK (btrim(field_code) <> ''),
    CONSTRAINT ck_oil_field_name_nonempty CHECK (btrim(field_name) <> '')
);

CREATE TABLE frac_core.well (
    well_id BIGINT GENERATED ALWAYS AS IDENTITY,
    oil_field_id BIGINT NOT NULL,
    well_code VARCHAR(40) NOT NULL,
    well_type VARCHAR(20) NOT NULL,
    well_status VARCHAR(20) NOT NULL DEFAULT 'active',
    commissioning_date DATE,
    design_depth_m NUMERIC(8,2),
    CONSTRAINT pk_well PRIMARY KEY (well_id),
    CONSTRAINT fk_well_oil_field FOREIGN KEY (oil_field_id)
        REFERENCES frac_core.oil_field (oil_field_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT uq_well_field_code UNIQUE (oil_field_id, well_code),
    CONSTRAINT ck_well_code_nonempty CHECK (btrim(well_code) <> ''),
    CONSTRAINT ck_well_type CHECK (well_type IN ('production', 'injection', 'observation')),
    CONSTRAINT ck_well_status CHECK (well_status IN ('active', 'suspended', 'abandoned', 'under_repair')),
    CONSTRAINT ck_well_depth_positive CHECK (design_depth_m IS NULL OR design_depth_m > 0)
);

CREATE TABLE frac_core.frac_fleet (
    frac_fleet_id BIGINT GENERATED ALWAYS AS IDENTITY,
    fleet_code VARCHAR(30) NOT NULL,
    fleet_name VARCHAR(120) NOT NULL,
    fleet_status VARCHAR(20) NOT NULL DEFAULT 'active',
    max_operating_pressure_mpa NUMERIC(8,2),
    base_location VARCHAR(150),
    CONSTRAINT pk_frac_fleet PRIMARY KEY (frac_fleet_id),
    CONSTRAINT uq_frac_fleet_code UNIQUE (fleet_code),
    CONSTRAINT ck_frac_fleet_code_nonempty CHECK (btrim(fleet_code) <> ''),
    CONSTRAINT ck_frac_fleet_status CHECK (fleet_status IN ('active', 'standby', 'maintenance', 'decommissioned')),
    CONSTRAINT ck_frac_fleet_pressure_positive CHECK (max_operating_pressure_mpa IS NULL OR max_operating_pressure_mpa > 0)
);

CREATE TABLE frac_core.equipment_type (
    equipment_type_id BIGINT GENERATED ALWAYS AS IDENTITY,
    type_code VARCHAR(30) NOT NULL,
    type_name VARCHAR(120) NOT NULL,
    category VARCHAR(40) NOT NULL,
    description TEXT,
    CONSTRAINT pk_equipment_type PRIMARY KEY (equipment_type_id),
    CONSTRAINT uq_equipment_type_code UNIQUE (type_code),
    CONSTRAINT ck_equipment_type_category CHECK (category IN ('pumping', 'blending', 'manifold', 'control', 'transport', 'auxiliary', 'other')),
    CONSTRAINT ck_equipment_type_code_nonempty CHECK (btrim(type_code) <> '')
);

CREATE TABLE frac_core.equipment_unit (
    equipment_unit_id BIGINT GENERATED ALWAYS AS IDENTITY,
    equipment_type_id BIGINT NOT NULL,
    equipment_code VARCHAR(40) NOT NULL,
    serial_number VARCHAR(80),
    manufacturer VARCHAR(100),
    model_name VARCHAR(100),
    manufacture_year SMALLINT,
    commissioning_date DATE,
    technical_status VARCHAR(25) NOT NULL DEFAULT 'serviceable',
    CONSTRAINT pk_equipment_unit PRIMARY KEY (equipment_unit_id),
    CONSTRAINT fk_equipment_unit_type FOREIGN KEY (equipment_type_id)
        REFERENCES frac_core.equipment_type (equipment_type_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT uq_equipment_unit_code UNIQUE (equipment_code),
    CONSTRAINT uq_equipment_unit_serial UNIQUE (serial_number),
    CONSTRAINT ck_equipment_unit_code_nonempty CHECK (btrim(equipment_code) <> ''),
    CONSTRAINT ck_equipment_unit_year CHECK (manufacture_year IS NULL OR manufacture_year BETWEEN 1900 AND 2100),
    CONSTRAINT ck_equipment_unit_status CHECK (technical_status IN ('serviceable', 'restricted', 'under_maintenance', 'decommissioned'))
);

CREATE TABLE frac_core.fleet_unit_assignment (
    assignment_id BIGINT GENERATED ALWAYS AS IDENTITY,
    frac_fleet_id BIGINT NOT NULL,
    equipment_unit_id BIGINT NOT NULL,
    assigned_at TIMESTAMPTZ NOT NULL,
    released_at TIMESTAMPTZ,
    assignment_reason VARCHAR(250),
    CONSTRAINT pk_fleet_unit_assignment PRIMARY KEY (assignment_id),
    CONSTRAINT fk_fua_fleet FOREIGN KEY (frac_fleet_id)
        REFERENCES frac_core.frac_fleet (frac_fleet_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_fua_equipment FOREIGN KEY (equipment_unit_id)
        REFERENCES frac_core.equipment_unit (equipment_unit_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_fua_period CHECK (released_at IS NULL OR released_at > assigned_at)
);

CREATE TABLE frac_core.crew (
    crew_id BIGINT GENERATED ALWAYS AS IDENTITY,
    crew_code VARCHAR(30) NOT NULL,
    crew_name VARCHAR(120) NOT NULL,
    specialization VARCHAR(100) NOT NULL,
    crew_status VARCHAR(20) NOT NULL DEFAULT 'active',
    CONSTRAINT pk_crew PRIMARY KEY (crew_id),
    CONSTRAINT uq_crew_code UNIQUE (crew_code),
    CONSTRAINT ck_crew_status CHECK (crew_status IN ('active', 'inactive')),
    CONSTRAINT ck_crew_code_nonempty CHECK (btrim(crew_code) <> '')
);

CREATE TABLE frac_core.repair_type (
    repair_type_id BIGINT GENERATED ALWAYS AS IDENTITY,
    repair_type_code VARCHAR(30) NOT NULL,
    type_name VARCHAR(120) NOT NULL,
    description TEXT,
    planned_duration_hours NUMERIC(8,2),
    CONSTRAINT pk_repair_type PRIMARY KEY (repair_type_id),
    CONSTRAINT uq_repair_type_code UNIQUE (repair_type_code),
    CONSTRAINT ck_repair_type_duration CHECK (planned_duration_hours IS NULL OR planned_duration_hours > 0),
    CONSTRAINT ck_repair_type_code_nonempty CHECK (btrim(repair_type_code) <> '')
);

CREATE TABLE frac_core.well_repair (
    repair_id BIGINT GENERATED ALWAYS AS IDENTITY,
    repair_code VARCHAR(40) NOT NULL,
    well_id BIGINT NOT NULL,
    frac_fleet_id BIGINT NOT NULL,
    crew_id BIGINT NOT NULL,
    repair_type_id BIGINT NOT NULL,
    planned_start_at TIMESTAMPTZ NOT NULL,
    planned_end_at TIMESTAMPTZ,
    actual_start_at TIMESTAMPTZ,
    actual_end_at TIMESTAMPTZ,
    repair_status VARCHAR(20) NOT NULL DEFAULT 'planned',
    result_description TEXT,
    CONSTRAINT pk_well_repair PRIMARY KEY (repair_id),
    CONSTRAINT uq_well_repair_code UNIQUE (repair_code),
    CONSTRAINT fk_well_repair_well FOREIGN KEY (well_id)
        REFERENCES frac_core.well (well_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_well_repair_fleet FOREIGN KEY (frac_fleet_id)
        REFERENCES frac_core.frac_fleet (frac_fleet_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_well_repair_crew FOREIGN KEY (crew_id)
        REFERENCES frac_core.crew (crew_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_well_repair_type FOREIGN KEY (repair_type_id)
        REFERENCES frac_core.repair_type (repair_type_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_well_repair_code_nonempty CHECK (btrim(repair_code) <> ''),
    CONSTRAINT ck_well_repair_status CHECK (repair_status IN ('planned', 'in_progress', 'completed', 'cancelled')),
    CONSTRAINT ck_well_repair_planned_period CHECK (planned_end_at IS NULL OR planned_end_at >= planned_start_at),
    CONSTRAINT ck_well_repair_actual_period CHECK (actual_end_at IS NULL OR (actual_start_at IS NOT NULL AND actual_end_at >= actual_start_at)),
    CONSTRAINT ck_well_repair_completed CHECK (repair_status <> 'completed' OR (actual_start_at IS NOT NULL AND actual_end_at IS NOT NULL)),
    CONSTRAINT ck_well_repair_in_progress CHECK (repair_status <> 'in_progress' OR (actual_start_at IS NOT NULL AND actual_end_at IS NULL))
);

CREATE TABLE frac_core.repair_stage (
    repair_stage_id BIGINT GENERATED ALWAYS AS IDENTITY,
    repair_id BIGINT NOT NULL,
    stage_number SMALLINT NOT NULL,
    stage_name VARCHAR(120) NOT NULL,
    stage_status VARCHAR(20) NOT NULL DEFAULT 'planned',
    started_at TIMESTAMPTZ,
    ended_at TIMESTAMPTZ,
    CONSTRAINT pk_repair_stage PRIMARY KEY (repair_stage_id),
    CONSTRAINT fk_repair_stage_repair FOREIGN KEY (repair_id)
        REFERENCES frac_core.well_repair (repair_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT uq_repair_stage_number UNIQUE (repair_id, stage_number),
    CONSTRAINT ck_repair_stage_number CHECK (stage_number > 0),
    CONSTRAINT ck_repair_stage_status CHECK (stage_status IN ('planned', 'in_progress', 'completed', 'skipped')),
    CONSTRAINT ck_repair_stage_period CHECK (ended_at IS NULL OR (started_at IS NOT NULL AND ended_at >= started_at)),
    CONSTRAINT ck_repair_stage_completed CHECK (stage_status <> 'completed' OR (started_at IS NOT NULL AND ended_at IS NOT NULL)),
    CONSTRAINT ck_repair_stage_in_progress CHECK (stage_status <> 'in_progress' OR (started_at IS NOT NULL AND ended_at IS NULL))
);

CREATE TABLE frac_core.telemetry_measurement (
    measurement_id BIGINT GENERATED ALWAYS AS IDENTITY,
    repair_stage_id BIGINT NOT NULL,
    measured_at TIMESTAMPTZ NOT NULL,
    pressure_mpa NUMERIC(10,3),
    fluid_rate_m3_min NUMERIC(10,4),
    proppant_concentration_kg_m3 NUMERIC(10,3),
    cumulative_fluid_volume_m3 NUMERIC(14,3),
    cumulative_proppant_mass_t NUMERIC(14,3),
    CONSTRAINT pk_telemetry_measurement PRIMARY KEY (measurement_id),
    CONSTRAINT fk_telemetry_stage FOREIGN KEY (repair_stage_id)
        REFERENCES frac_core.repair_stage (repair_stage_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT uq_telemetry_stage_time UNIQUE (repair_stage_id, measured_at),
    CONSTRAINT ck_telemetry_pressure CHECK (pressure_mpa IS NULL OR pressure_mpa >= 0),
    CONSTRAINT ck_telemetry_fluid_rate CHECK (fluid_rate_m3_min IS NULL OR fluid_rate_m3_min >= 0),
    CONSTRAINT ck_telemetry_proppant_concentration CHECK (proppant_concentration_kg_m3 IS NULL OR proppant_concentration_kg_m3 >= 0),
    CONSTRAINT ck_telemetry_cumulative_fluid CHECK (cumulative_fluid_volume_m3 IS NULL OR cumulative_fluid_volume_m3 >= 0),
    CONSTRAINT ck_telemetry_cumulative_proppant CHECK (cumulative_proppant_mass_t IS NULL OR cumulative_proppant_mass_t >= 0),
    CONSTRAINT ck_telemetry_has_metric CHECK (
        pressure_mpa IS NOT NULL OR fluid_rate_m3_min IS NOT NULL OR
        proppant_concentration_kg_m3 IS NOT NULL OR cumulative_fluid_volume_m3 IS NOT NULL OR
        cumulative_proppant_mass_t IS NOT NULL
    )
);

CREATE TABLE frac_core.equipment_maintenance (
    maintenance_id BIGINT GENERATED ALWAYS AS IDENTITY,
    equipment_unit_id BIGINT NOT NULL,
    maintenance_type VARCHAR(25) NOT NULL,
    maintenance_status VARCHAR(20) NOT NULL DEFAULT 'planned',
    started_at TIMESTAMPTZ NOT NULL,
    ended_at TIMESTAMPTZ,
    next_due_date DATE,
    description TEXT,
    CONSTRAINT pk_equipment_maintenance PRIMARY KEY (maintenance_id),
    CONSTRAINT fk_equipment_maintenance_unit FOREIGN KEY (equipment_unit_id)
        REFERENCES frac_core.equipment_unit (equipment_unit_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_maintenance_type CHECK (maintenance_type IN ('planned_service', 'inspection', 'repair', 'unscheduled')),
    CONSTRAINT ck_maintenance_status CHECK (maintenance_status IN ('planned', 'in_progress', 'completed', 'cancelled')),
    CONSTRAINT ck_maintenance_period CHECK (ended_at IS NULL OR ended_at >= started_at),
    CONSTRAINT ck_maintenance_completed CHECK (maintenance_status <> 'completed' OR ended_at IS NOT NULL),
    CONSTRAINT ck_maintenance_in_progress CHECK (maintenance_status <> 'in_progress' OR ended_at IS NULL)
);
