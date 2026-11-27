-- ЭТАП 4.1. Наполнение справочников и регистра скважин.
-- PostgreSQL 15. Все записи синтетические и не относятся к реальным активам Газпром нефти.
-- Запускать после создания схемы frac_core и всех 12 таблиц.
-- Скрипт допускает повторный запуск: используются естественные уникальные коды и ON CONFLICT.

BEGIN;

-- 1. Месторождения: условные учебные объекты.
INSERT INTO frac_core.oil_field (field_code, field_name, region_name, description)
VALUES
 ('SYN-FLD-001', 'Северное тестовое месторождение 01', 'Северный учебный регион', 'Синтетический объект для учебного проекта.'),
 ('SYN-FLD-002', 'Северное тестовое месторождение 02', 'Северный учебный регион', 'Синтетический объект для учебного проекта.'),
 ('SYN-FLD-003', 'Приозёрное тестовое месторождение 03', 'Северный учебный регион', 'Синтетический объект для учебного проекта.'),
 ('SYN-FLD-004', 'Таёжное тестовое месторождение 04', 'Северный учебный регион', 'Синтетический объект для учебного проекта.'),
 ('SYN-FLD-005', 'Центральное тестовое месторождение 05', 'Центральный учебный регион', 'Синтетический объект для учебного проекта.'),
 ('SYN-FLD-006', 'Речное тестовое месторождение 06', 'Центральный учебный регион', 'Синтетический объект для учебного проекта.'),
 ('SYN-FLD-007', 'Уральское тестовое месторождение 07', 'Центральный учебный регион', 'Синтетический объект для учебного проекта.'),
 ('SYN-FLD-008', 'Южное тестовое месторождение 08', 'Южный учебный регион', 'Синтетический объект для учебного проекта.'),
 ('SYN-FLD-009', 'Степное тестовое месторождение 09', 'Южный учебный регион', 'Синтетический объект для учебного проекта.'),
 ('SYN-FLD-010', 'Восточное тестовое месторождение 10', 'Восточный учебный регион', 'Синтетический объект для учебного проекта.')
ON CONFLICT (field_code) DO NOTHING;

-- 2. Флоты ГРП.
INSERT INTO frac_core.frac_fleet
    (fleet_code, fleet_name, fleet_status, max_operating_pressure_mpa, base_location)
VALUES
 ('SYN-FRAC-01', 'Учебный флот ГРП № 01', 'active', 70.00, 'База Север-01 (условно)'),
 ('SYN-FRAC-02', 'Учебный флот ГРП № 02', 'active', 85.00, 'База Север-02 (условно)'),
 ('SYN-FRAC-03', 'Учебный флот ГРП № 03', 'active', 90.00, 'База Центр-01 (условно)'),
 ('SYN-FRAC-04', 'Учебный флот ГРП № 04', 'active', 105.00, 'База Центр-02 (условно)'),
 ('SYN-FRAC-05', 'Учебный флот ГРП № 05', 'standby', 85.00, 'База Юг-01 (условно)'),
 ('SYN-FRAC-06', 'Учебный флот ГРП № 06', 'active', 100.00, 'База Восток-01 (условно)')
ON CONFLICT (fleet_code) DO NOTHING;

-- 3. Типы оборудования. Категории соответствуют CHECK-ограничению equipment_type.
INSERT INTO frac_core.equipment_type (type_code, type_name, category, description)
VALUES
 ('SYN-TYP-01', 'Насосная установка высокого давления', 'pumping', 'Синтетический пример насосного оборудования.'),
 ('SYN-TYP-02', 'Блендерная установка', 'blending', 'Смешивание рабочей жидкости и проппанта.'),
 ('SYN-TYP-03', 'Манифольд высокого давления', 'manifold', 'Распределение потока высокого давления.'),
 ('SYN-TYP-04', 'Система сбора и контроля данных', 'control', 'Контроль и регистрация параметров операции.'),
 ('SYN-TYP-05', 'Установка подачи химических реагентов', 'auxiliary', 'Дозирование химических реагентов.'),
 ('SYN-TYP-06', 'Установка приготовления жидкости', 'auxiliary', 'Подготовка технологической жидкости.'),
 ('SYN-TYP-07', 'Пескосмесительная установка', 'blending', 'Подготовка проппантной смеси.'),
 ('SYN-TYP-08', 'Силовой модуль', 'auxiliary', 'Вспомогательное энергетическое оборудование.'),
 ('SYN-TYP-09', 'Ёмкость и транспортный модуль', 'transport', 'Транспортировка и временное хранение жидкости.'),
 ('SYN-TYP-10', 'Комплект трубной обвязки', 'manifold', 'Соединительная обвязка технологической линии.'),
 ('SYN-TYP-11', 'Прицепная насосная установка', 'pumping', 'Дополнительная насосная установка.'),
 ('SYN-TYP-12', 'Сервисный автомобиль', 'transport', 'Вспомогательная транспортная единица.')
ON CONFLICT (type_code) DO NOTHING;

-- 4. Бригады.
INSERT INTO frac_core.crew (crew_code, crew_name, specialization, crew_status)
SELECT
    'SYN-CR-' || lpad(n::text, 3, '0'),
    'Учебная бригада ГРП № ' || lpad(n::text, 2, '0'),
    CASE n % 4
        WHEN 0 THEN 'Проведение операций ГРП'
        WHEN 1 THEN 'Монтаж и опрессовка оборудования'
        WHEN 2 THEN 'Технологическое сопровождение'
        ELSE 'Комплексные ремонтные работы'
    END,
    CASE WHEN n = 12 THEN 'inactive' ELSE 'active' END
FROM generate_series(1, 12) AS g(n)
ON CONFLICT (crew_code) DO NOTHING;

-- 5. Виды ремонтно-технологических операций.
INSERT INTO frac_core.repair_type
    (repair_type_code, type_name, description, planned_duration_hours)
VALUES
 ('SYN-RTP-01', 'Гидравлический разрыв пласта', 'Синтетическая типовая операция ГРП.', 36.00),
 ('SYN-RTP-02', 'Повторный гидравлический разрыв пласта', 'Учебный пример повторной операции ГРП.', 48.00),
 ('SYN-RTP-03', 'Ремонтно-изоляционные работы', 'Учебный вид ремонтно-изоляционных работ.', 30.00),
 ('SYN-RTP-04', 'Промывка скважины', 'Учебная операция промывки ствола скважины.', 18.00),
 ('SYN-RTP-05', 'Кислотная обработка', 'Синтетический пример кислотной обработки.', 24.00),
 ('SYN-RTP-06', 'Освоение скважины после ремонта', 'Учебная операция освоения скважины.', 20.00),
 ('SYN-RTP-07', 'Опрессовка колонны и оборудования', 'Проверка герметичности оборудования.', 12.00),
 ('SYN-RTP-08', 'Ликвидация технологических осложнений', 'Учебный пример устранения осложнений.', 42.00)
ON CONFLICT (repair_type_code) DO NOTHING;

-- 6. Каталог из 100 условных скважин: по 10 скважин на каждое месторождение.
WITH field_ranked AS (
    SELECT oil_field_id, row_number() OVER (ORDER BY field_code) AS field_no
    FROM frac_core.oil_field
    WHERE field_code LIKE 'SYN-FLD-%'
), generated_wells AS (
    SELECT n,
           ((n - 1) / 10) + 1 AS field_no,
           ((n - 1) % 10) + 1 AS well_no
    FROM generate_series(1, 100) AS g(n)
)
INSERT INTO frac_core.well
    (oil_field_id, well_code, well_type, well_status, commissioning_date, design_depth_m)
SELECT
    f.oil_field_id,
    'SYN-W-' || lpad(gw.well_no::text, 3, '0'),
    CASE gw.n % 10
        WHEN 0 THEN 'injection'
        WHEN 1 THEN 'observation'
        ELSE 'production'
    END,
    CASE WHEN gw.n % 23 = 0 THEN 'suspended' ELSE 'active' END,
    DATE '2005-01-01' + ((gw.n * 47) % 6500),
    (1800 + ((gw.n * 37) % 2400))::numeric(8,2)
FROM generated_wells gw
JOIN field_ranked f ON f.field_no = gw.field_no
ON CONFLICT (oil_field_id, well_code) DO NOTHING;

COMMIT;

-- Контроль: ожидается 10 месторождений, 100 скважин, 6 флотов,
-- 12 типов оборудования, 12 бригад и 8 видов ремонта.
SELECT 'oil_field' AS table_name, count(*) AS rows_count FROM frac_core.oil_field WHERE field_code LIKE 'SYN-FLD-%'
UNION ALL SELECT 'well', count(*) FROM frac_core.well WHERE well_code LIKE 'SYN-W-%'
UNION ALL SELECT 'frac_fleet', count(*) FROM frac_core.frac_fleet WHERE fleet_code LIKE 'SYN-FRAC-%'
UNION ALL SELECT 'equipment_type', count(*) FROM frac_core.equipment_type WHERE type_code LIKE 'SYN-TYP-%'
UNION ALL SELECT 'crew', count(*) FROM frac_core.crew WHERE crew_code LIKE 'SYN-CR-%'
UNION ALL SELECT 'repair_type', count(*) FROM frac_core.repair_type WHERE repair_type_code LIKE 'SYN-RTP-%'
ORDER BY table_name;
