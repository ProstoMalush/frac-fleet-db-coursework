-- ЭТАП 8.3. Функция изменения измерения месторождения по SCD Type 2.
-- Функция закрывает текущую версию и добавляет новую строку.
-- valid_to является исключающей верхней границей периода.

CREATE OR REPLACE FUNCTION frac_mart.fn_apply_field_scd2_change(
    p_source_oil_field_id BIGINT,
    p_field_name          VARCHAR(150),
    p_region_name         VARCHAR(100),
    p_description         TEXT,
    p_effective_from      DATE,
    p_change_reason       VARCHAR(300)
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_current frac_mart.dim_field%ROWTYPE;
    v_new_field_key BIGINT;
BEGIN
    IF p_source_oil_field_id IS NULL OR p_effective_from IS NULL THEN
        RAISE EXCEPTION 'Идентификатор месторождения и дата начала действия обязательны';
    END IF;

    IF p_field_name IS NULL OR BTRIM(p_field_name) = ''
       OR p_region_name IS NULL OR BTRIM(p_region_name) = '' THEN
        RAISE EXCEPTION 'Название месторождения и регион не могут быть пустыми';
    END IF;

    SELECT *
    INTO v_current
    FROM frac_mart.dim_field
    WHERE source_oil_field_id = p_source_oil_field_id
      AND is_current = TRUE
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Текущая версия месторождения % не найдена в dim_field',
            p_source_oil_field_id;
    END IF;

    IF p_effective_from <= v_current.valid_from THEN
        RAISE EXCEPTION 'Дата изменения % должна быть позже начала текущей версии %',
            p_effective_from, v_current.valid_from;
    END IF;

    -- Если атрибуты не изменились, новую версию не создаём.
    IF v_current.field_name IS NOT DISTINCT FROM p_field_name
       AND v_current.region_name IS NOT DISTINCT FROM p_region_name
       AND v_current.description IS NOT DISTINCT FROM p_description THEN
        RETURN v_current.field_key;
    END IF;

    -- Закрываем текущую версию на дату начала новой версии.
    UPDATE frac_mart.dim_field
    SET valid_to = p_effective_from,
        is_current = FALSE
    WHERE field_key = v_current.field_key;

    -- Добавляем новую версию с тем же естественным ключом и новым суррогатным ключом.
    INSERT INTO frac_mart.dim_field (
        source_oil_field_id, field_code, field_name, region_name, description,
        valid_from, valid_to, is_current, change_reason
    )
    VALUES (
        v_current.source_oil_field_id,
        v_current.field_code,
        p_field_name,
        p_region_name,
        p_description,
        p_effective_from,
        NULL,
        TRUE,
        COALESCE(NULLIF(BTRIM(p_change_reason), ''), 'Изменение атрибутов по SCD Type 2')
    )
    RETURNING field_key INTO v_new_field_key;

    RETURN v_new_field_key;
END;
$$;

COMMENT ON FUNCTION frac_mart.fn_apply_field_scd2_change(
    BIGINT, VARCHAR, VARCHAR, TEXT, DATE, VARCHAR
) IS
'Закрывает действующую версию месторождения и создаёт новую версию измерения dim_field по правилам SCD Type 2.';

-- Демонстрационное изменение только в аналитическом измерении.
-- Это искусственная учебная история, а не реальное изменение данных месторождения.
-- Для SYN-FLD-001 с 2025-01-01 обновляется описание; имя и регион не меняются.
-- Скрипт идемпотентен: повторное выполнение не создаёт повторную версию.
DO $$
DECLARE
    v_oil_field_id BIGINT;
    v_field_name VARCHAR(150);
    v_region_name VARCHAR(100);
BEGIN
    SELECT oil_field_id, field_name, region_name
    INTO v_oil_field_id, v_field_name, v_region_name
    FROM frac_core.oil_field
    WHERE field_code = 'SYN-FLD-001';

    IF v_oil_field_id IS NULL THEN
        RAISE EXCEPTION 'В frac_core.oil_field не найдено тестовое месторождение SYN-FLD-001';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM frac_mart.dim_field
        WHERE source_oil_field_id = v_oil_field_id
          AND valid_from = DATE '2025-01-01'
    ) THEN
        PERFORM frac_mart.fn_apply_field_scd2_change(
            v_oil_field_id,
            v_field_name,
            v_region_name,
            'Учебное обновление описания с 2025-01-01; синтетическая демонстрация SCD-2, не производственные сведения.',
            DATE '2025-01-01',
            'Демонстрация SCD Type 2 на синтетических данных'
        );
    END IF;
END;
$$;

-- Контроль: у SYN-FLD-001 должно быть две версии с непересекающимися датами.
SELECT
    field_code,
    field_name,
    valid_from,
    valid_to,
    is_current,
    change_reason
FROM frac_mart.dim_field
WHERE field_code = 'SYN-FLD-001'
ORDER BY valid_from;
