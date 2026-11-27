-- Физическая сортировка временных измерений по measured_at для демонстрации BRIN.
-- Операция требует блокировки таблицы на время перестройки. Значения строк не меняются.
DROP INDEX IF EXISTS frac_core.tmp_telemetry_measured_at_btree;

CREATE INDEX tmp_telemetry_measured_at_btree
    ON frac_core.telemetry_measurement (measured_at);

CLUSTER frac_core.telemetry_measurement
    USING tmp_telemetry_measured_at_btree;

DROP INDEX frac_core.tmp_telemetry_measured_at_btree;
ANALYZE frac_core.telemetry_measurement;

-- Проверка correlation: ожидается значение, близкое к 1 после CLUSTER.
SELECT attname, correlation, n_distinct
FROM pg_stats
WHERE schemaname = 'frac_core'
  AND tablename = 'telemetry_measurement'
  AND attname = 'measured_at';
