# Этап 6. Каталог функций PostgreSQL

Все десять функций располагаются в схеме `frac_core` и предназначены для PostgreSQL 15.

| № | Функция | Назначение | Тип |
|---:|---|---|---|
| 1 | `fn_repair_actual_duration_hours` | Фактическая длительность ремонта в часах | SQL |
| 2 | `fn_stage_avg_pressure_mpa` | Среднее давление этапа | SQL |
| 3 | `fn_stage_max_pressure_mpa` | Максимальное давление этапа | SQL |
| 4 | `fn_stage_total_fluid_volume_m3` | Итоговый накопительный объём жидкости на этапе | SQL |
| 5 | `fn_stage_total_proppant_mass_t` | Итоговая накопительная масса проппанта на этапе | SQL |
| 6 | `fn_last_completed_repair_id` | Последний завершённый ремонт скважины | SQL |
| 7 | `fn_fleet_equipment_count` | Число единиц оборудования флота на заданный момент | SQL |
| 8 | `fn_is_equipment_assigned_to_fleet` | Проверка закрепления оборудования за флотом на заданный момент | SQL |
| 9 | `fn_completed_repairs_count` | Число завершённых ремонтов флота в периоде | SQL |
| 10 | `fn_pressure_limit_utilization_pct` | Процент использования предела давления | PL/pgSQL |

## Граничные случаи PL/pgSQL-функции

`fn_pressure_limit_utilization_pct(measured, limit)` возвращает `NULL`, если один из аргументов равен `NULL` или предел равен нулю. Нулевой предел отдельно проверяется до деления; в выражении также применяется `NULLIF` как дополнительная защита. Отрицательные давления приводят к исключению с SQLSTATE `22023`.

Примеры:

```sql
SELECT frac_core.fn_pressure_limit_utilization_pct(45, 60); -- 75.00
SELECT frac_core.fn_pressure_limit_utilization_pct(NULL, 60); -- NULL
SELECT frac_core.fn_pressure_limit_utilization_pct(45, NULL); -- NULL
SELECT frac_core.fn_pressure_limit_utilization_pct(45, 0); -- NULL, деления на ноль нет
```

## Важное решение по накопительным показателям

В телеметрии `cumulative_fluid_volume_m3` и `cumulative_proppant_mass_t` — накопительные показатели. Их нельзя суммировать по временным точкам одного этапа, иначе один и тот же накопленный объём будет посчитан многократно. Поэтому функции №4 и №5 возвращают `MAX()` по соответствующему этапу — конечное накопительное значение при монотонном временном ряде.

## Порядок выполнения

1. `functions/01_create_functions.sql` — создать или обновить функции.
2. `functions/02_test_functions.sql` — вызвать все функции и проверить граничные случаи.
3. `queries/08_maintenance_due_date_profile.sql` — отдельно изучить распределение дат ТО.

Все тестовые скрипты — SELECT-запросы, они не изменяют данные.
