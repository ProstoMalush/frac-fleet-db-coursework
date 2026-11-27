-- Размер таблиц схемы frac_core с учётом TOAST и индексов.
-- Запрос только читает системный каталог.
SELECT
    c.relname AS table_name,
    pg_size_pretty(pg_table_size(c.oid)) AS table_size,
    pg_size_pretty(pg_indexes_size(c.oid)) AS indexes_size,
    pg_size_pretty(pg_total_relation_size(c.oid)) AS total_size,
    pg_total_relation_size(c.oid) AS total_size_bytes
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'frac_core'
  AND c.relkind = 'r'
ORDER BY pg_total_relation_size(c.oid) DESC, c.relname;
