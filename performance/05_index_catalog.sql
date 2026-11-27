-- Проверка наличия целевых индексов и их определения.
SELECT
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'frac_core'
  AND indexname IN (
      'idx_repair_stage_started_at_btree',
      'idx_well_repair_active_fleet_start',
      'idx_telemetry_measured_at_brin'
  )
ORDER BY tablename, indexname;
