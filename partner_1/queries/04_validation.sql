-- Контроль наполнения partner_1.
SELECT 'source_field' AS table_name, COUNT(*) AS rows_count FROM partner_1.source_field
UNION ALL SELECT 'source_well', COUNT(*) FROM partner_1.source_well
UNION ALL SELECT 'measurement_parameter', COUNT(*) FROM partner_1.measurement_parameter
UNION ALL SELECT 'measurement_method', COUNT(*) FROM partner_1.measurement_method
UNION ALL SELECT 'measuring_device', COUNT(*) FROM partner_1.measuring_device
UNION ALL SELECT 'measurement_operator', COUNT(*) FROM partner_1.measurement_operator
UNION ALL SELECT 'measurement_session', COUNT(*) FROM partner_1.measurement_session
UNION ALL SELECT 'well_measurement', COUNT(*) FROM partner_1.well_measurement
ORDER BY table_name;

-- Ожидается: 10 месторождений, 100 скважин, 8 параметров, 4 методики,
-- 12 приборов, 10 операторов, 4 300 сессий, 34 400 измерений.

-- Проверка отсутствующих родителей.
SELECT 'session_without_well' AS check_name, COUNT(*) AS errors
FROM partner_1.measurement_session s
LEFT JOIN partner_1.source_well w USING (source_well_id)
WHERE w.source_well_id IS NULL
UNION ALL
SELECT 'measurement_without_session', COUNT(*)
FROM partner_1.well_measurement m
LEFT JOIN partner_1.measurement_session s USING (session_id)
WHERE s.session_id IS NULL
UNION ALL
SELECT 'measurement_without_parameter', COUNT(*)
FROM partner_1.well_measurement m
LEFT JOIN partner_1.measurement_parameter p USING (parameter_id)
WHERE p.parameter_id IS NULL;

-- Диапазоны параметров и доля сессий с сомнительным качеством.
SELECT p.parameter_code, p.unit_name,
       COUNT(*) AS readings_count,
       ROUND(MIN(m.measured_value), 3) AS min_value,
       ROUND(AVG(m.measured_value), 3) AS avg_value,
       ROUND(MAX(m.measured_value), 3) AS max_value
FROM partner_1.well_measurement m
JOIN partner_1.measurement_parameter p USING (parameter_id)
GROUP BY p.parameter_code, p.unit_name
ORDER BY p.parameter_code;

SELECT quality_status, COUNT(*) AS sessions_count
FROM partner_1.measurement_session
GROUP BY quality_status
ORDER BY quality_status;
