-- Проверка того, что DDL выполнен корректно.
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'frac_core' AND table_type = 'BASE TABLE'
ORDER BY table_name;

SELECT conrelid::regclass AS table_name, conname, contype
FROM pg_constraint
WHERE connamespace = 'frac_core'::regnamespace
ORDER BY conrelid::regclass::text, conname;

SELECT schemaname, tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'frac_core'
ORDER BY tablename, indexname;
