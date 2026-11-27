-- Этап 6. Десять полезных функций для PostgreSQL 15.
-- Схема: frac_core. Все функции безопасны для повторного создания.
-- Функции только читают данные; INSERT/UPDATE/DELETE не выполняются.

-- 1. Фактическая продолжительность ремонта в часах.
-- Возвращает NULL, если ремонт не найден или фактические даты ещё не заполнены.
CREATE OR REPLACE FUNCTION frac_core.fn_repair_actual_duration_hours(
    p_repair_id BIGINT
)
RETURNS NUMERIC
LANGUAGE sql
STABLE
PARALLEL SAFE
AS $$
    SELECT CASE
        WHEN r.actual_start_at IS NULL OR r.actual_end_at IS NULL THEN NULL::numeric
        ELSE ROUND(
            (EXTRACT(EPOCH FROM (r.actual_end_at - r.actual_start_at)) / 3600.0)::numeric,
            2
        )
    END
    FROM frac_core.well_repair AS r
    WHERE r.repair_id = p_repair_id;
$$;

-- 2. Среднее давление на этапе, МПа.
-- AVG игнорирует NULL; если измерений давления нет, результат NULL.
CREATE OR REPLACE FUNCTION frac_core.fn_stage_avg_pressure_mpa(
    p_repair_stage_id BIGINT
)
RETURNS NUMERIC
LANGUAGE sql
STABLE
PARALLEL SAFE
AS $$
    SELECT ROUND(AVG(m.pressure_mpa), 2)
    FROM frac_core.telemetry_measurement AS m
    WHERE m.repair_stage_id = p_repair_stage_id;
$$;

-- 3. Максимальное давление на этапе, МПа.
CREATE OR REPLACE FUNCTION frac_core.fn_stage_max_pressure_mpa(
    p_repair_stage_id BIGINT
)
RETURNS NUMERIC
LANGUAGE sql
STABLE
PARALLEL SAFE
AS $$
    SELECT MAX(m.pressure_mpa)
    FROM frac_core.telemetry_measurement AS m
    WHERE m.repair_stage_id = p_repair_stage_id;
$$;

-- 4. Итоговый объём жидкости на этапе, м3.
-- Поле cumulative_fluid_volume_m3 является накопительным рядом,
-- поэтому итог берётся как MAX, а не SUM всех временных точек.
CREATE OR REPLACE FUNCTION frac_core.fn_stage_total_fluid_volume_m3(
    p_repair_stage_id BIGINT
)
RETURNS NUMERIC
LANGUAGE sql
STABLE
PARALLEL SAFE
AS $$
    SELECT MAX(m.cumulative_fluid_volume_m3)
    FROM frac_core.telemetry_measurement AS m
    WHERE m.repair_stage_id = p_repair_stage_id;
$$;

-- 5. Итоговая масса проппанта на этапе, тонн.
-- Накопительный показатель также агрегируется через MAX.
CREATE OR REPLACE FUNCTION frac_core.fn_stage_total_proppant_mass_t(
    p_repair_stage_id BIGINT
)
RETURNS NUMERIC
LANGUAGE sql
STABLE
PARALLEL SAFE
AS $$
    SELECT MAX(m.cumulative_proppant_mass_t)
    FROM frac_core.telemetry_measurement AS m
    WHERE m.repair_stage_id = p_repair_stage_id;
$$;

-- 6. Идентификатор последнего завершённого ремонта скважины.
-- При отсутствии завершённых ремонтов возвращает NULL.
CREATE OR REPLACE FUNCTION frac_core.fn_last_completed_repair_id(
    p_well_id BIGINT
)
RETURNS BIGINT
LANGUAGE sql
STABLE
PARALLEL SAFE
AS $$
    SELECT r.repair_id
    FROM frac_core.well_repair AS r
    WHERE r.well_id = p_well_id
      AND r.repair_status = 'completed'
      AND r.actual_end_at IS NOT NULL
    ORDER BY r.actual_end_at DESC, r.repair_id DESC
    LIMIT 1;
$$;

-- 7. Количество единиц оборудования, закреплённых за флотом на заданный момент.
-- Интервал назначения полуоткрытый: [assigned_at, released_at).
-- Если p_as_of не передан или равен NULL, используется текущее время.
CREATE OR REPLACE FUNCTION frac_core.fn_fleet_equipment_count(
    p_frac_fleet_id BIGINT,
    p_as_of TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
)
RETURNS BIGINT
LANGUAGE sql
STABLE
PARALLEL SAFE
AS $$
    SELECT COUNT(DISTINCT a.equipment_unit_id)::bigint
    FROM frac_core.fleet_unit_assignment AS a
    WHERE a.frac_fleet_id = p_frac_fleet_id
      AND a.assigned_at <= COALESCE(p_as_of, CURRENT_TIMESTAMP)
      AND (a.released_at IS NULL OR a.released_at > COALESCE(p_as_of, CURRENT_TIMESTAMP));
$$;

-- 8. Проверка, закреплено ли оборудование за конкретным флотом на заданный момент.
CREATE OR REPLACE FUNCTION frac_core.fn_is_equipment_assigned_to_fleet(
    p_equipment_unit_id BIGINT,
    p_frac_fleet_id BIGINT,
    p_as_of TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
PARALLEL SAFE
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM frac_core.fleet_unit_assignment AS a
        WHERE a.equipment_unit_id = p_equipment_unit_id
          AND a.frac_fleet_id = p_frac_fleet_id
          AND a.assigned_at <= COALESCE(p_as_of, CURRENT_TIMESTAMP)
          AND (a.released_at IS NULL OR a.released_at > COALESCE(p_as_of, CURRENT_TIMESTAMP))
    );
$$;

-- 9. Количество завершённых ремонтов флота за период [p_from, p_to).
-- Для NULL-параметров или некорректного периода возвращает 0.
CREATE OR REPLACE FUNCTION frac_core.fn_completed_repairs_count(
    p_frac_fleet_id BIGINT,
    p_from TIMESTAMPTZ,
    p_to TIMESTAMPTZ
)
RETURNS BIGINT
LANGUAGE sql
STABLE
PARALLEL SAFE
AS $$
    SELECT CASE
        WHEN p_frac_fleet_id IS NULL
          OR p_from IS NULL
          OR p_to IS NULL
          OR p_to <= p_from
        THEN 0::bigint
        ELSE (
            SELECT COUNT(*)::bigint
            FROM frac_core.well_repair AS r
            WHERE r.frac_fleet_id = p_frac_fleet_id
              AND r.repair_status = 'completed'
              AND r.actual_start_at >= p_from
              AND r.actual_start_at < p_to
              AND r.actual_end_at IS NOT NULL
        )
    END;
$$;

-- 10. Использование допустимого давления флота, %.
-- Пример: давление 45 МПа при пределе 60 МПа = 75%.
-- NULL на входе и нулевой предел возвращают NULL (деление на ноль исключено).
-- Отрицательные значения считаются ошибочными входными данными.
CREATE OR REPLACE FUNCTION frac_core.fn_pressure_limit_utilization_pct(
    p_measured_pressure_mpa NUMERIC,
    p_limit_mpa NUMERIC
)
RETURNS NUMERIC
LANGUAGE plpgsql
STABLE
PARALLEL SAFE
AS $$
BEGIN
    IF p_measured_pressure_mpa IS NULL OR p_limit_mpa IS NULL THEN
        RETURN NULL;
    END IF;

    IF p_limit_mpa = 0 THEN
        RETURN NULL;
    END IF;

    IF p_measured_pressure_mpa < 0 OR p_limit_mpa < 0 THEN
        RAISE EXCEPTION 'Давление и предел давления не могут быть отрицательными: measured=%, limit=%',
            p_measured_pressure_mpa, p_limit_mpa
            USING ERRCODE = '22023';
    END IF;

    RETURN ROUND(
        (p_measured_pressure_mpa / NULLIF(p_limit_mpa, 0)) * 100,
        2
    );
END;
$$;

COMMENT ON FUNCTION frac_core.fn_repair_actual_duration_hours(BIGINT)
    IS 'Возвращает фактическую продолжительность ремонта в часах; NULL для незавершённой или отсутствующей записи.';
COMMENT ON FUNCTION frac_core.fn_stage_avg_pressure_mpa(BIGINT)
    IS 'Рассчитывает среднее давление телеметрии на этапе, МПа.';
COMMENT ON FUNCTION frac_core.fn_stage_max_pressure_mpa(BIGINT)
    IS 'Возвращает максимальное давление телеметрии на этапе, МПа.';
COMMENT ON FUNCTION frac_core.fn_stage_total_fluid_volume_m3(BIGINT)
    IS 'Возвращает последнее накопительное значение объёма жидкости на этапе через MAX, м3.';
COMMENT ON FUNCTION frac_core.fn_stage_total_proppant_mass_t(BIGINT)
    IS 'Возвращает последнее накопительное значение массы проппанта на этапе через MAX, тонн.';
COMMENT ON FUNCTION frac_core.fn_last_completed_repair_id(BIGINT)
    IS 'Возвращает ID последнего завершённого ремонта указанной скважины.';
COMMENT ON FUNCTION frac_core.fn_fleet_equipment_count(BIGINT, TIMESTAMPTZ)
    IS 'Считает количество единиц оборудования, закреплённых за флотом на заданный момент времени.';
COMMENT ON FUNCTION frac_core.fn_is_equipment_assigned_to_fleet(BIGINT, BIGINT, TIMESTAMPTZ)
    IS 'Проверяет, закреплена ли единица оборудования за указанным флотом на заданный момент.';
COMMENT ON FUNCTION frac_core.fn_completed_repairs_count(BIGINT, TIMESTAMPTZ, TIMESTAMPTZ)
    IS 'Считает завершённые ремонты флота за полуоткрытый период [начало, конец).';
COMMENT ON FUNCTION frac_core.fn_pressure_limit_utilization_pct(NUMERIC, NUMERIC)
    IS 'Рассчитывает процент использования предела давления; обрабатывает NULL и нулевой делитель.';
