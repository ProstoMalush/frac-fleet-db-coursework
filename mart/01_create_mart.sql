-- ЭТАП 8.1. Создание аналитической схемы frac_mart.
-- СУБД: PostgreSQL 15. Выполнять один раз перед загрузкой измерений.
-- Требуется ранее установленное расширение btree_gist (этап 3).
-- Таблицы операционной схемы frac_core не изменяются.

CREATE SCHEMA IF NOT EXISTS frac_mart;

COMMENT ON SCHEMA frac_mart IS
'Аналитическая витрина по ремонтам скважин и работе флотов ГРП. Источник данных — frac_core; тестовые данные синтетические.';

-- Измерение даты. Ключ формируется как YYYYMMDD.
CREATE TABLE IF NOT EXISTS frac_mart.dim_date (
    date_key           INTEGER PRIMARY KEY,
    full_date          DATE NOT NULL UNIQUE,
    calendar_year      SMALLINT NOT NULL,
    quarter_number     SMALLINT NOT NULL,
    month_number       SMALLINT NOT NULL,
    day_of_month       SMALLINT NOT NULL,
    iso_day_of_week    SMALLINT NOT NULL,
    is_weekend         BOOLEAN NOT NULL,
    year_quarter       VARCHAR(7) NOT NULL,
    CONSTRAINT ck_dim_date_quarter CHECK (quarter_number BETWEEN 1 AND 4),
    CONSTRAINT ck_dim_date_month CHECK (month_number BETWEEN 1 AND 12),
    CONSTRAINT ck_dim_date_day CHECK (day_of_month BETWEEN 1 AND 31),
    CONSTRAINT ck_dim_date_weekday CHECK (iso_day_of_week BETWEEN 1 AND 7)
);

COMMENT ON TABLE frac_mart.dim_date IS
'Календарное измерение для группировки ремонтных операций по годам, кварталам, месяцам и дням.';

-- Измерение месторождения с историчностью SCD Type 2.
-- valid_to является исключающей верхней границей периода: [valid_from, valid_to).
-- NULL в valid_to означает отсутствие даты окончания (текущая версия).
CREATE TABLE IF NOT EXISTS frac_mart.dim_field (
    field_key             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_oil_field_id   BIGINT NOT NULL,
    field_code            VARCHAR(30) NOT NULL,
    field_name            VARCHAR(150) NOT NULL,
    region_name           VARCHAR(100) NOT NULL,
    description           TEXT,
    valid_from            DATE NOT NULL,
    valid_to              DATE,
    is_current            BOOLEAN NOT NULL,
    change_reason         VARCHAR(300) NOT NULL,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_dim_field_source FOREIGN KEY (source_oil_field_id)
        REFERENCES frac_core.oil_field (oil_field_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_dim_field_period CHECK (valid_to IS NULL OR valid_to > valid_from),
    CONSTRAINT ck_dim_field_current CHECK (is_current = (valid_to IS NULL)),
    CONSTRAINT ck_dim_field_code_nonempty CHECK (btrim(field_code) <> ''),
    CONSTRAINT ck_dim_field_name_nonempty CHECK (btrim(field_name) <> '')
);

-- Не более одной текущей версии для каждого исходного месторождения.
CREATE UNIQUE INDEX IF NOT EXISTS uq_dim_field_current
    ON frac_mart.dim_field (source_oil_field_id)
    WHERE is_current;

-- Запрещаем пересекающиеся интервалы версий одного месторождения.
ALTER TABLE frac_mart.dim_field
    DROP CONSTRAINT IF EXISTS ex_dim_field_no_overlapping_periods;
ALTER TABLE frac_mart.dim_field
    ADD CONSTRAINT ex_dim_field_no_overlapping_periods
    EXCLUDE USING gist (
        source_oil_field_id WITH =,
        daterange(valid_from, COALESCE(valid_to, 'infinity'::date), '[)') WITH &&
    );

COMMENT ON TABLE frac_mart.dim_field IS
'Измерение месторождения SCD Type 2: новая версия атрибутов добавляется отдельной строкой с периодом действия.';
COMMENT ON COLUMN frac_mart.dim_field.field_key IS
'Суррогатный ключ версии месторождения; используется в таблице фактов.';
COMMENT ON COLUMN frac_mart.dim_field.source_oil_field_id IS
'Естественный идентификатор месторождения из frac_core.oil_field; одинаков для всех исторических версий.';
COMMENT ON COLUMN frac_mart.dim_field.valid_from IS
'Дата начала действия версии включительно.';
COMMENT ON COLUMN frac_mart.dim_field.valid_to IS
'Дата окончания действия версии исключительно; NULL у текущей версии.';
COMMENT ON COLUMN frac_mart.dim_field.is_current IS
'Признак текущей версии; согласован с valid_to через CHECK.';

-- Измерение вида ремонта. Изменения справочника обновляются по SCD Type 1.
CREATE TABLE IF NOT EXISTS frac_mart.dim_repair_type (
    repair_type_key       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_repair_type_id BIGINT NOT NULL UNIQUE,
    repair_type_code      VARCHAR(30) NOT NULL UNIQUE,
    type_name             VARCHAR(120) NOT NULL,
    description           TEXT,
    planned_duration_hours NUMERIC(8,2),
    CONSTRAINT fk_dim_repair_type_source FOREIGN KEY (source_repair_type_id)
        REFERENCES frac_core.repair_type (repair_type_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_dim_repair_type_duration
        CHECK (planned_duration_hours IS NULL OR planned_duration_hours > 0)
);

COMMENT ON TABLE frac_mart.dim_repair_type IS
'Измерение классификации ремонтов; в данной витрине используется SCD Type 1.';

-- Факт: одна строка соответствует одному завершённому ремонту скважины.
-- fleet_code и well_code — вырожденные измерения (degenerate dimensions):
-- отдельные таблицы измерений для них не создаются, чтобы сохранить 3 измерения по заданию.
CREATE TABLE IF NOT EXISTS frac_mart.fact_well_repair (
    fact_repair_key       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_repair_id      BIGINT NOT NULL UNIQUE,
    repair_code           VARCHAR(40) NOT NULL UNIQUE,
    well_code             VARCHAR(40) NOT NULL,
    fleet_code            VARCHAR(30) NOT NULL,
    date_key              INTEGER NOT NULL,
    field_key             BIGINT NOT NULL,
    repair_type_key       BIGINT NOT NULL,
    repair_count          SMALLINT NOT NULL DEFAULT 1,
    stage_count           SMALLINT NOT NULL,
    measurement_count     INTEGER NOT NULL,
    actual_duration_hours NUMERIC(12,2) NOT NULL,
    avg_pressure_mpa      NUMERIC(10,3),
    max_pressure_mpa      NUMERIC(10,3),
    total_fluid_volume_m3 NUMERIC(14,3),
    total_proppant_mass_t NUMERIC(14,3),
    loaded_at             TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_fact_source_repair FOREIGN KEY (source_repair_id)
        REFERENCES frac_core.well_repair (repair_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_fact_date FOREIGN KEY (date_key)
        REFERENCES frac_mart.dim_date (date_key)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_fact_field FOREIGN KEY (field_key)
        REFERENCES frac_mart.dim_field (field_key)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_fact_repair_type FOREIGN KEY (repair_type_key)
        REFERENCES frac_mart.dim_repair_type (repair_type_key)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT ck_fact_repair_count CHECK (repair_count = 1),
    CONSTRAINT ck_fact_stage_count CHECK (stage_count >= 0),
    CONSTRAINT ck_fact_measurement_count CHECK (measurement_count >= 0),
    CONSTRAINT ck_fact_duration CHECK (actual_duration_hours >= 0),
    CONSTRAINT ck_fact_avg_pressure CHECK (avg_pressure_mpa IS NULL OR avg_pressure_mpa >= 0),
    CONSTRAINT ck_fact_max_pressure CHECK (max_pressure_mpa IS NULL OR max_pressure_mpa >= 0),
    CONSTRAINT ck_fact_fluid_volume CHECK (total_fluid_volume_m3 IS NULL OR total_fluid_volume_m3 >= 0),
    CONSTRAINT ck_fact_proppant_mass CHECK (total_proppant_mass_t IS NULL OR total_proppant_mass_t >= 0)
);

CREATE INDEX IF NOT EXISTS idx_fact_repair_date_key
    ON frac_mart.fact_well_repair (date_key);
CREATE INDEX IF NOT EXISTS idx_fact_repair_field_key
    ON frac_mart.fact_well_repair (field_key);
CREATE INDEX IF NOT EXISTS idx_fact_repair_type_key
    ON frac_mart.fact_well_repair (repair_type_key);

COMMENT ON TABLE frac_mart.fact_well_repair IS
'Таблица фактов: одна строка на один завершённый ремонт; хранит показатели длительности и технологические метрики.';
COMMENT ON COLUMN frac_mart.fact_well_repair.repair_count IS
'Аддитивная мера количества ремонтов; всегда равна 1 на одну строку факта.';
COMMENT ON COLUMN frac_mart.fact_well_repair.total_fluid_volume_m3 IS
'Сумма последних накопительных значений объёма жидкости по этапам данного ремонта.';
COMMENT ON COLUMN frac_mart.fact_well_repair.total_proppant_mass_t IS
'Сумма последних накопительных значений массы проппанта по этапам данного ремонта.';
