# Логическая модель БД замеров по скважинам

В стартовую модель включено 8 сущностей.

| Сущность | Ключевые атрибуты | Назначение |
|---|---|---|
| `source_field` | source_field_id, field_code | Месторождения источника |
| `source_well` | source_well_id, source_field_id, well_code | Скважины источника |
| `measurement_parameter` | parameter_id, parameter_code, unit_name | Типы измеряемых параметров |
| `measurement_method` | method_id, method_code | Методики измерений |
| `measuring_device` | device_id, device_code, serial_number | Средства измерений и калибровка |
| `measurement_operator` | operator_id, operator_code | Операторы замеров |
| `measurement_session` | session_id, source_well_id, measured_at | Сессия измерений по скважине |
| `well_measurement` | measurement_id, session_id, parameter_id, measured_value | Значения отдельных параметров |

## Связи

- `source_field` 1:N `source_well`.
- `source_well` 1:N `measurement_session`.
- `measurement_method` 1:N `measurement_session`.
- `measuring_device` 1:N `measurement_session`.
- `measurement_operator` 1:N `measurement_session`.
- `measurement_session` 1:N `well_measurement`.
- `measurement_parameter` 1:N `well_measurement`.

Ограничение `UNIQUE(session_id, parameter_id)` гарантирует, что один параметр не будет дважды записан в рамках одной сессии. Новое измерение того же параметра выполняется в новой сессии.

## Границы сущностей

Сущности `measurement_parameter`, `measurement_method`, `measuring_device` и `measurement_operator` вынесены отдельно, потому что их свойства повторно используются во множестве измерительных сессий. Таблица `well_measurement` хранит только факт измерения и ссылку на параметр. Время и контекст находятся в `measurement_session`, поэтому не дублируются в каждой строке измерения.

## Пространство идентификаторов

`source_well_id` — локальный ключ схемы `partner_1`. Его числовое значение нельзя напрямую приравнивать к `frac_core.well_id`. Для интеграции используется составная естественная идентификация: `field_code + well_code`.
