-- Генерация синтетических временных рядов замеров.
-- 100 скважин x 43 ежемесячные сессии x 8 параметров = 34 400 измерений.
-- Период с декабря 2022 по июнь 2026. Скрипт допускает повторный запуск.

BEGIN;

INSERT INTO partner_1.measurement_session
(session_code, source_well_id, method_id, device_id, operator_id, period_no, measured_at, quality_status, notes)
SELECT
    'SYN-MS-' || lpad(sw.source_well_id::text,3,'0') || '-' || lpad(g.period_no::text,2,'0') AS session_code,
    sw.source_well_id,
    (1 + mod(sw.source_well_id + g.period_no, 4))::bigint AS method_id,
    (1 + mod(sw.source_well_id * 3 + g.period_no, 12))::bigint AS device_id,
    (1 + mod(sw.source_well_id + g.period_no * 2, 10))::bigint AS operator_id,
    g.period_no::smallint,
    (TIMESTAMP '2022-12-15 08:00:00'
        + g.period_no * INTERVAL '1 month'
        + make_interval(mins => mod((sw.source_well_id * 7 + g.period_no * 13)::integer, 180)))
        AT TIME ZONE 'Asia/Yekaterinburg' AS measured_at,
    CASE WHEN mod(sw.source_well_id + g.period_no, 37) = 0 THEN 'suspect' ELSE 'valid' END AS quality_status,
    'Синтетическая ежемесячная сессия для учебной демонстрации.'
FROM partner_1.source_well AS sw
CROSS JOIN generate_series(0,42) AS g(period_no)
ON CONFLICT (session_code) DO UPDATE SET
    source_well_id=EXCLUDED.source_well_id,
    method_id=EXCLUDED.method_id,
    device_id=EXCLUDED.device_id,
    operator_id=EXCLUDED.operator_id,
    period_no=EXCLUDED.period_no,
    measured_at=EXCLUDED.measured_at,
    quality_status=EXCLUDED.quality_status,
    notes=EXCLUDED.notes;

WITH values_to_insert AS (
    SELECT
        s.session_id,
        s.quality_status,
        sw.source_well_id,
        s.period_no,
        v.parameter_code,
        v.measured_value::numeric(14,4) AS measured_value
    FROM partner_1.measurement_session AS s
    JOIN partner_1.source_well AS sw
      ON sw.source_well_id = s.source_well_id
    CROSS JOIN LATERAL (VALUES
        ('OIL_RATE', 5.0 + mod(sw.source_well_id * 173 + s.period_no * 137, 4500)::numeric / 100),
        ('WATER_RATE', 1.0 + mod(sw.source_well_id * 137 + s.period_no * 97, 5000)::numeric / 100),
        ('GAS_RATE', 0.2 + mod(sw.source_well_id * 83 + s.period_no * 47, 800)::numeric / 100),
        ('WATER_CUT', 15.0 + mod(sw.source_well_id * 157 + s.period_no * 109, 7500)::numeric / 100),
        ('RESERVOIR_PRESSURE', 12.0 + mod(sw.source_well_id * 71 + s.period_no * 59, 1800)::numeric / 100),
        ('BOTTOMHOLE_PRESSURE', 5.0 + mod(sw.source_well_id * 127 + s.period_no * 89, 2200)::numeric / 100),
        ('TEMPERATURE', 45.0 + mod(sw.source_well_id * 151 + s.period_no * 113, 3500)::numeric / 100),
        ('DYNAMIC_FLUID_LEVEL', 600.0 + mod(sw.source_well_id * 31 + s.period_no * 17, 1600)::numeric)
    ) AS v(parameter_code, measured_value)
)
INSERT INTO partner_1.well_measurement(session_id, parameter_id, measured_value, quality_flag)
SELECT
    v.session_id,
    p.parameter_id,
    v.measured_value,
    v.quality_status
FROM values_to_insert AS v
JOIN partner_1.measurement_parameter AS p
  ON p.parameter_code = v.parameter_code
ON CONFLICT (session_id, parameter_id) DO UPDATE SET
    measured_value=EXCLUDED.measured_value,
    quality_flag=EXCLUDED.quality_flag;

COMMIT;

ANALYZE partner_1.measurement_session;
ANALYZE partner_1.well_measurement;

SELECT 'measurement_session' AS table_name, COUNT(*) AS rows_count FROM partner_1.measurement_session
UNION ALL
SELECT 'well_measurement', COUNT(*) FROM partner_1.well_measurement
ORDER BY table_name;
