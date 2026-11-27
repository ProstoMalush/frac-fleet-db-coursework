# Логическая модель БД (ЛМД)

## 1. Назначение модели

Логическая модель описывает состав отношений (таблиц), атрибуты, ключи и связи предметной области «Флоты ГРП для проведения ремонтов на скважинах». В основной операционной модели выделено 12 сущностей. Модель ориентирована на реляционную СУБД PostgreSQL 15.

В таблицах ниже приведены рекомендуемые типы PostgreSQL. Окончательные физические параметры, имена ограничений, индексы и SQL DDL будут закреплены на этапе физического проектирования.

Обозначения: **PK** — первичный ключ; **FK** — внешний ключ; **UQ** — уникальность; **NN** — NOT NULL; **NULL** — значение допускается не указывать.

## 2. Состав таблиц и атрибутов

### 2.1. `frac_core.oil_field` — месторождение

| Атрибут | Тип | Обязательность | Ключ / ограничение | Назначение |
|---|---|---|---|---|
| `oil_field_id` | BIGINT | NN | PK, identity | Идентификатор месторождения |
| `field_code` | VARCHAR(30) | NN | UQ | Уникальный код месторождения |
| `field_name` | VARCHAR(150) | NN |  | Наименование |
| `region_name` | VARCHAR(100) | NN |  | Регион расположения |
| `description` | TEXT | NULL |  | Дополнительное описание |

**Ключ:** `oil_field_id`. Код `field_code` является альтернативным бизнес-ключом.

### 2.2. `frac_core.well` — скважина

| Атрибут | Тип | Обязательность | Ключ / ограничение | Назначение |
|---|---|---|---|---|
| `well_id` | BIGINT | NN | PK, identity | Идентификатор скважины |
| `oil_field_id` | BIGINT | NN | FK → `oil_field.oil_field_id` | Месторождение |
| `well_code` | VARCHAR(40) | NN | UQ в пределах месторождения | Номер/код скважины |
| `well_type` | VARCHAR(20) | NN | CHECK IN (production, injection, observation) | Тип скважины: добывающая, нагнетательная, наблюдательная |
| `well_status` | VARCHAR(20) | NN | CHECK IN (active, suspended, abandoned, under_repair) | Статус скважины |
| `commissioning_date` | DATE | NULL |  | Дата ввода в эксплуатацию |
| `design_depth_m` | NUMERIC(8,2) | NULL | CHECK > 0 | Проектная глубина, м |

**Ключи:** PK `well_id`; FK `oil_field_id`; UQ (`oil_field_id`, `well_code`). Код скважины уникален в рамках месторождения, а не обязательно глобально.

### 2.3. `frac_core.frac_fleet` — флот ГРП

| Атрибут | Тип | Обязательность | Ключ / ограничение | Назначение |
|---|---|---|---|---|
| `frac_fleet_id` | BIGINT | NN | PK, identity | Идентификатор флота |
| `fleet_code` | VARCHAR(30) | NN | UQ | Уникальный код флота |
| `fleet_name` | VARCHAR(120) | NN |  | Наименование флота |
| `fleet_status` | VARCHAR(20) | NN | CHECK IN (active, standby, maintenance, decommissioned) | Состояние флота |
| `max_operating_pressure_mpa` | NUMERIC(8,2) | NULL | CHECK > 0 | Предельное рабочее давление, МПа |
| `base_location` | VARCHAR(150) | NULL |  | Базовое место размещения |

### 2.4. `frac_core.equipment_type` — тип оборудования

| Атрибут | Тип | Обязательность | Ключ / ограничение | Назначение |
|---|---|---|---|---|
| `equipment_type_id` | BIGINT | NN | PK, identity | Идентификатор типа |
| `type_code` | VARCHAR(30) | NN | UQ | Код типа оборудования |
| `type_name` | VARCHAR(120) | NN |  | Наименование типа |
| `category` | VARCHAR(40) | NN | CHECK | Категория: pumping, blending, manifold, control, transport, auxiliary, other |
| `description` | TEXT | NULL |  | Описание назначения |

### 2.5. `frac_core.equipment_unit` — единица оборудования

| Атрибут | Тип | Обязательность | Ключ / ограничение | Назначение |
|---|---|---|---|---|
| `equipment_unit_id` | BIGINT | NN | PK, identity | Идентификатор единицы оборудования |
| `equipment_type_id` | BIGINT | NN | FK → `equipment_type.equipment_type_id` | Тип оборудования |
| `equipment_code` | VARCHAR(40) | NN | UQ | Внутренний инвентарный код |
| `serial_number` | VARCHAR(80) | NULL | UQ | Заводской номер, если известен |
| `manufacturer` | VARCHAR(100) | NULL |  | Производитель |
| `model_name` | VARCHAR(100) | NULL |  | Модель |
| `manufacture_year` | SMALLINT | NULL | CHECK BETWEEN 1900 AND 2100 | Год изготовления |
| `commissioning_date` | DATE | NULL |  | Дата ввода в эксплуатацию |
| `technical_status` | VARCHAR(25) | NN | CHECK IN (serviceable, restricted, under_maintenance, decommissioned) | Техническое состояние |

Текущий флот намеренно не хранится в `equipment_unit`: принадлежность к флоту меняется во времени и фиксируется в `fleet_unit_assignment`.

### 2.6. `frac_core.fleet_unit_assignment` — история закрепления оборудования за флотами

| Атрибут | Тип | Обязательность | Ключ / ограничение | Назначение |
|---|---|---|---|---|
| `assignment_id` | BIGINT | NN | PK, identity | Идентификатор назначения |
| `frac_fleet_id` | BIGINT | NN | FK → `frac_fleet.frac_fleet_id` | Флот |
| `equipment_unit_id` | BIGINT | NN | FK → `equipment_unit.equipment_unit_id` | Единица оборудования |
| `assigned_at` | TIMESTAMPTZ | NN |  | Начало закрепления |
| `released_at` | TIMESTAMPTZ | NULL | CHECK (`released_at` IS NULL OR `released_at` > `assigned_at`) | Окончание закрепления; NULL означает текущее назначение |
| `assignment_reason` | VARCHAR(250) | NULL |  | Причина/комментарий к перемещению |

**Ключи:** PK `assignment_id`; FK на флот и единицу оборудования. В физической модели будет предусмотрено ограничение, запрещающее пересекающиеся интервалы закрепления одной единицы оборудования за разными флотами.

### 2.7. `frac_core.crew` — рабочая бригада

| Атрибут | Тип | Обязательность | Ключ / ограничение | Назначение |
|---|---|---|---|---|
| `crew_id` | BIGINT | NN | PK, identity | Идентификатор бригады |
| `crew_code` | VARCHAR(30) | NN | UQ | Код бригады |
| `crew_name` | VARCHAR(120) | NN |  | Наименование бригады |
| `specialization` | VARCHAR(100) | NN |  | Специализация |
| `crew_status` | VARCHAR(20) | NN | CHECK IN (active, inactive) | Статус бригады |

Персональный состав и кадровые сведения работников в границы данной курсовой не входят; учитывается ответственная бригада как организационная единица.

### 2.8. `frac_core.repair_type` — вид ремонта

| Атрибут | Тип | Обязательность | Ключ / ограничение | Назначение |
|---|---|---|---|---|
| `repair_type_id` | BIGINT | NN | PK, identity | Идентификатор вида ремонта |
| `repair_type_code` | VARCHAR(30) | NN | UQ | Код вида ремонта |
| `type_name` | VARCHAR(120) | NN |  | Наименование вида ремонта |
| `description` | TEXT | NULL |  | Описание |
| `planned_duration_hours` | NUMERIC(8,2) | NULL | CHECK > 0 | Нормативная/плановая продолжительность, ч |

### 2.9. `frac_core.well_repair` — ремонтная операция на скважине

| Атрибут | Тип | Обязательность | Ключ / ограничение | Назначение |
|---|---|---|---|---|
| `repair_id` | BIGINT | NN | PK, identity | Идентификатор операции |
| `repair_code` | VARCHAR(40) | NN | UQ | Уникальный код операции |
| `well_id` | BIGINT | NN | FK → `well.well_id` | Скважина |
| `frac_fleet_id` | BIGINT | NN | FK → `frac_fleet.frac_fleet_id` | Основной флот ГРП |
| `crew_id` | BIGINT | NN | FK → `crew.crew_id` | Ответственная бригада |
| `repair_type_id` | BIGINT | NN | FK → `repair_type.repair_type_id` | Вид ремонта |
| `planned_start_at` | TIMESTAMPTZ | NN |  | Плановое начало |
| `planned_end_at` | TIMESTAMPTZ | NULL | CHECK (`planned_end_at` IS NULL OR `planned_end_at` >= `planned_start_at`) | Плановое окончание |
| `actual_start_at` | TIMESTAMPTZ | NULL |  | Фактическое начало |
| `actual_end_at` | TIMESTAMPTZ | NULL | CHECK (`actual_end_at` IS NULL OR (`actual_start_at` IS NOT NULL AND `actual_end_at` >= `actual_start_at`)) | Фактическое окончание |
| `repair_status` | VARCHAR(20) | NN | CHECK IN (planned, in_progress, completed, cancelled) | Статус ремонта |
| `result_description` | TEXT | NULL |  | Результат/комментарий по операции |

`oil_field_id` в этой таблице отсутствует намеренно: месторождение определяется через `well_id` → `well.oil_field_id`. Повторное хранение `oil_field_id` создало бы транзитивную зависимость и риск несогласованности. Для статуса `completed` дополнительно зададим CHECK: `actual_start_at IS NOT NULL AND actual_end_at IS NOT NULL`.

### 2.10. `frac_core.repair_stage` — этап ремонта

| Атрибут | Тип | Обязательность | Ключ / ограничение | Назначение |
|---|---|---|---|---|
| `repair_stage_id` | BIGINT | NN | PK, identity | Идентификатор этапа |
| `repair_id` | BIGINT | NN | FK → `well_repair.repair_id` | Ремонтная операция |
| `stage_number` | SMALLINT | NN | UQ совместно с `repair_id`, CHECK > 0 | Порядковый номер этапа в операции |
| `stage_name` | VARCHAR(120) | NN |  | Наименование этапа |
| `stage_status` | VARCHAR(20) | NN | CHECK IN (planned, in_progress, completed, skipped) | Статус этапа |
| `started_at` | TIMESTAMPTZ | NULL |  | Фактическое начало этапа |
| `ended_at` | TIMESTAMPTZ | NULL | CHECK (`ended_at` IS NULL OR (`started_at` IS NOT NULL AND `ended_at` >= `started_at`)) | Фактическое окончание этапа |

### 2.11. `frac_core.telemetry_measurement` — технологическое измерение

| Атрибут | Тип | Обязательность | Ключ / ограничение | Назначение |
|---|---|---|---|---|
| `measurement_id` | BIGINT | NN | PK, identity | Идентификатор измерения |
| `repair_stage_id` | BIGINT | NN | FK → `repair_stage.repair_stage_id` | Этап, к которому относится измерение |
| `measured_at` | TIMESTAMPTZ | NN | UQ совместно с `repair_stage_id` | Время измерения |
| `pressure_mpa` | NUMERIC(10,3) | NULL | CHECK ≥ 0 | Давление, МПа |
| `fluid_rate_m3_min` | NUMERIC(10,4) | NULL | CHECK ≥ 0 | Расход жидкости, м³/мин |
| `proppant_concentration_kg_m3` | NUMERIC(10,3) | NULL | CHECK ≥ 0 | Концентрация проппанта, кг/м³ |
| `cumulative_fluid_volume_m3` | NUMERIC(14,3) | NULL | CHECK ≥ 0 | Накопленный объём жидкости, м³ |
| `cumulative_proppant_mass_t` | NUMERIC(14,3) | NULL | CHECK ≥ 0 | Накопленная масса проппанта, т |

Запись может содержать NULL для отдельных показателей, например при недоступности датчика. CHECK потребует, чтобы хотя бы один из пяти технологических показателей был заполнен. Составные значения и списки в одной ячейке не используются. Накопительные значения относятся к конкретному этапу и представляют показания счётчика на момент измерения.

### 2.12. `frac_core.equipment_maintenance` — техническое обслуживание оборудования

| Атрибут | Тип | Обязательность | Ключ / ограничение | Назначение |
|---|---|---|---|---|
| `maintenance_id` | BIGINT | NN | PK, identity | Идентификатор обслуживания |
| `equipment_unit_id` | BIGINT | NN | FK → `equipment_unit.equipment_unit_id` | Единица оборудования |
| `maintenance_type` | VARCHAR(25) | NN | CHECK IN (planned_service, inspection, repair, unscheduled) | Тип обслуживания |
| `maintenance_status` | VARCHAR(20) | NN | CHECK IN (planned, in_progress, completed, cancelled) | Статус обслуживания |
| `started_at` | TIMESTAMPTZ | NN |  | Начало обслуживания |
| `ended_at` | TIMESTAMPTZ | NULL | CHECK (`ended_at` IS NULL OR `ended_at` >= `started_at`) | Окончание обслуживания |
| `next_due_date` | DATE | NULL |  | Плановая дата следующего обслуживания |
| `description` | TEXT | NULL |  | Выполненные работы/замечания |

## 3. Связи и кардинальности

| Родительская сущность | Дочерняя сущность | Кардинальность | Реализация |
|---|---|---|---|
| `oil_field` | `well` | 1:N | FK `well.oil_field_id` |
| `well` | `well_repair` | 1:N | FK `well_repair.well_id` |
| `frac_fleet` | `well_repair` | 1:N | FK `well_repair.frac_fleet_id` |
| `crew` | `well_repair` | 1:N | FK `well_repair.crew_id` |
| `repair_type` | `well_repair` | 1:N | FK `well_repair.repair_type_id` |
| `well_repair` | `repair_stage` | 1:0..N | FK `repair_stage.repair_id` |
| `repair_stage` | `telemetry_measurement` | 1:N | FK `telemetry_measurement.repair_stage_id` |
| `equipment_type` | `equipment_unit` | 1:N | FK `equipment_unit.equipment_type_id` |
| `frac_fleet` | `fleet_unit_assignment` | 1:N | FK `fleet_unit_assignment.frac_fleet_id` |
| `equipment_unit` | `fleet_unit_assignment` | 1:N | FK `fleet_unit_assignment.equipment_unit_id` |
| `equipment_unit` | `equipment_maintenance` | 1:N | FK `equipment_maintenance.equipment_unit_id` |

Связь `frac_fleet` ↔ `equipment_unit` является M:N во времени и разрешается ассоциативной сущностью `fleet_unit_assignment`.

## 4. Правила целостности предметной области

1. Код месторождения, флота, бригады, вида ремонта, единицы оборудования и ремонтной операции уникален в пределах соответствующей таблицы.
2. Код скважины уникален в пределах одного месторождения.
3. У одной единицы оборудования не должно быть пересекающихся интервалов закрепления за флотами.
4. Для одной единицы оборудования не допускаются интервалы технического обслуживания с окончанием раньше начала.
5. Время окончания ремонта, этапа или обслуживания не может быть раньше времени начала; если окончание указано, начало должно быть заполнено.
6. Этапы одного ремонта нумеруются без повторений и имеют положительный номер.
7. Время измерения одного этапа уникально.
8. Давление, расход, концентрация и накопленные объёмы не могут быть отрицательными; в измерении должно быть заполнено хотя бы одно значение технологического показателя.
9. Завершённая ремонтная операция должна иметь фактическое начало и фактическое окончание; это можно реализовать обычным CHECK в самой таблице `well_repair`. Завершённый этап и завершённое обслуживание также должны иметь обе фактические временные отметки.
10. Нельзя назначать оборудование на флот на период, в который оно выведено из эксплуатации или находится на обслуживании. Это правило требует проверки временных интервалов и будет реализовано отдельно, поскольку простой CHECK не может проверять другую таблицу.

## 5. Производные показатели, которые не храним как исходные атрибуты

Чтобы не дублировать данные, следующие показатели будут вычисляться запросами или функциями:

- месторождение ремонта — через скважину;
- фактическая продолжительность ремонта — разница `actual_end_at - actual_start_at`;
- количество измерений этапа — `COUNT(*)` по `telemetry_measurement`;
- состав флота на заданный момент — по интервалам `fleet_unit_assignment`;
- максимальное/среднее давление — агрегирование телеметрии;
- использованный объём/масса — по накопительным показателям телеметрии (с учётом последнего корректного значения этапа).

## 6. Что не включено в операционную модель

- **Сотрудник:** курсовая учитывает ответственную бригаду, а не персональный кадровый состав.
- **Запчасти и склад:** не относятся к основной задаче учёта флотов и ремонтов; при необходимости это отдельный домен.
- **Закупки, договоры и финансы:** не требуются для пяти заявленных бизнес-вопросов.
- **Геологическая модель и пластовые свойства:** не моделируются, так как предмет работы — учёт флотов, ремонтных операций и технологических измерений.
- **Отдельный справочник датчиков:** пока не включён, поскольку на первом этапе достаточно хранения измерений, связанных с этапом операции. Источник/идентификатор датчика можно добавить при появлении такого требования.

## 7. Проверка соответствия 3НФ

Схема спроектирована так, чтобы:

- каждое поле содержало одно атомарное значение;
- каждый неключевой атрибут зависел от полного ключа своей таблицы;
- справочные характеристики хранились в таблицах соответствующих сущностей, а не дублировались в дочерних таблицах;
- транзитивные сведения, например наименование месторождения в записи ремонта, не дублировались.

Подробный пример преобразования широкой таблицы в 1НФ, 2НФ и 3НФ приведён в `normalization.md`.
