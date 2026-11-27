# Порядок наполнения базы данных

Таблицы `frac_core` уже созданы в работающем Docker PostgreSQL. Повторно выполнять DDL не нужно.

1. `01_reference_data.sql`
2. `02_equipment_and_maintenance.sql`
3. `03_repairs_and_stages.sql`
4. `04_telemetry_measurements.sql`
5. `../queries/01_verify_generated_data.sql`

Запускайте каждый файл в DBeaver отдельно через Execute SQL Script. После ошибки остановитесь и передайте полный текст сообщения. Не удаляйте таблицы и не очищайте Docker volume.

Ожидаемая телеметрия: 53 760 строк. Все данные синтетические.
