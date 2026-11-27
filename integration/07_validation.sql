-- Проверка интеграции. Выполнять после integration/06_create_cross_domain_views.sql.

-- 1. Сколько скважин сопоставлено по составному естественному ключу.
SELECT COUNT(*) AS mapped_wells,
       COUNT(DISTINCT (field_code, well_code)) AS distinct_natural_keys,
       COUNT(*) FILTER (WHERE numeric_ids_equal) AS same_numeric_ids,
       COUNT(*) FILTER (WHERE NOT numeric_ids_equal) AS different_numeric_ids
FROM frac_mart.v_partner_1_well_crosswalk;

-- 2. Демонстрация коллизии ID: неправильное соединение только по числовому ID.
-- Здесь пары намеренно не совпадают по естественному ключу.
SELECT
    pw.source_well_id AS partner_local_well_id,
    pf.field_code AS partner_field_code,
    pw.well_code AS partner_well_code,
    cw.well_id AS frac_core_well_id,
    cf.field_code AS frac_core_field_code,
    cw.well_code AS frac_core_well_code
FROM partner_1.source_well pw
JOIN partner_1.source_field pf USING (source_field_id)
JOIN frac_core.well cw
  ON cw.well_id = pw.source_well_id
JOIN frac_core.oil_field cf
  ON cf.oil_field_id = cw.oil_field_id
WHERE (pf.field_code, pw.well_code) IS DISTINCT FROM (cf.field_code, cw.well_code)
ORDER BY pw.source_well_id
LIMIT 20;

-- Количество неверных пар, которые получились бы при соединении только по числовому ID.
SELECT COUNT(*) AS incorrect_matches_by_numeric_id
FROM partner_1.source_well pw
JOIN partner_1.source_field pf USING (source_field_id)
JOIN frac_core.well cw
  ON cw.well_id = pw.source_well_id
JOIN frac_core.oil_field cf
  ON cf.oil_field_id = cw.oil_field_id
WHERE (pf.field_code, pw.well_code) IS DISTINCT FROM (cf.field_code, cw.well_code);

-- 3. Проверка покрытия фактов последними замерами партнёра.
SELECT COUNT(*) AS fact_rows,
       COUNT(partner_session_id) AS facts_with_partner_session,
       COUNT(*) - COUNT(partner_session_id) AS facts_without_partner_session,
       ROUND(AVG(days_between_measurement_and_repair), 2) AS avg_days_before_repair
FROM frac_mart.v_repair_with_partner_well_measurements;

-- 4. Квартальная аналитика двух доменов.
SELECT *
FROM frac_mart.v_quarterly_repairs_with_well_measurements
ORDER BY quarter_start, field_code, repair_type_code
LIMIT 50;
