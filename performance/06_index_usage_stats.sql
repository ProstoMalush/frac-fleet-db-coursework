-- Статистика использования индексов после выполнения рабочих запросов.
-- pg_stat_user_indexes показывает статистику с момента последнего сброса статистики.
SELECT
    relname AS table_name,
    indexrelname AS index_name,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
WHERE schemaname = 'frac_core'
  AND indexrelname IN (
      'idx_repair_stage_started_at_btree',
      'idx_well_repair_active_fleet_start',
      'idx_telemetry_measured_at_brin'
  )
ORDER BY relname, indexrelname;
