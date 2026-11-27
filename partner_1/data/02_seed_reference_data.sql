-- Заполнение справочников и локального регистра 100 скважин.
-- Коды месторождений и скважин намеренно совпадают с учебным frac_core,
-- а числовые ID partner_1 назначаются в обратном порядке. Это создаёт
-- наглядный конфликт локальных ID и требует сопоставления по field_code + well_code.
-- Все данные синтетические.

BEGIN;

WITH fields(field_code, field_name, region_name) AS (
    VALUES
    ('SYN-FLD-001','Северное тестовое месторождение 01','Северный учебный регион'),
    ('SYN-FLD-002','Северное тестовое месторождение 02','Северный учебный регион'),
    ('SYN-FLD-003','Приозёрное тестовое месторождение 03','Северный учебный регион'),
    ('SYN-FLD-004','Таёжное тестовое месторождение 04','Северный учебный регион'),
    ('SYN-FLD-005','Центральное тестовое месторождение 05','Центральный учебный регион'),
    ('SYN-FLD-006','Речное тестовое месторождение 06','Центральный учебный регион'),
    ('SYN-FLD-007','Уральское тестовое месторождение 07','Центральный учебный регион'),
    ('SYN-FLD-008','Южное тестовое месторождение 08','Южный учебный регион'),
    ('SYN-FLD-009','Степное тестовое месторождение 09','Южный учебный регион'),
    ('SYN-FLD-010','Восточное тестовое месторождение 10','Восточный учебный регион')
), ranked AS (
    SELECT row_number() OVER (ORDER BY field_code DESC)::bigint AS source_field_id,
           field_code, field_name, region_name
    FROM fields
)
INSERT INTO partner_1.source_field(source_field_id, field_code, field_name, region_name, description)
SELECT source_field_id, field_code, field_name, region_name,
       'Синтетическая запись партнёрской схемы замеров.'
FROM ranked
ON CONFLICT (source_field_id) DO UPDATE SET
    field_code = EXCLUDED.field_code,
    field_name = EXCLUDED.field_name,
    region_name = EXCLUDED.region_name,
    description = EXCLUDED.description;

WITH fields AS (
    SELECT source_field_id, field_code,
           row_number() OVER (ORDER BY field_code)::integer AS field_no
    FROM partner_1.source_field
), generated AS (
    SELECT
        f.field_code,
        f.source_field_id,
        ((f.field_no - 1) * 10 + w.well_no)::integer AS global_no,
        'SYN-W-' || lpad(w.well_no::text, 3, '0') AS well_code,
        CASE (((f.field_no - 1) * 10 + w.well_no) % 10)
            WHEN 0 THEN 'injection'
            WHEN 1 THEN 'observation'
            ELSE 'production'
        END AS well_type,
        CASE WHEN (((f.field_no - 1) * 10 + w.well_no) % 23) = 0
             THEN 'suspended' ELSE 'active' END AS well_status,
        DATE '2005-01-01' + ((((f.field_no - 1) * 10 + w.well_no) * 47) % 6500) AS commissioning_date,
        (1800 + ((((f.field_no - 1) * 10 + w.well_no) * 37) % 2400))::numeric(8,2) AS design_depth_m
    FROM fields f
    CROSS JOIN generate_series(1,10) AS w(well_no)
), ranked AS (
    SELECT row_number() OVER (ORDER BY field_code DESC, well_code DESC)::bigint AS source_well_id,
           source_field_id, well_code, well_type, well_status, commissioning_date, design_depth_m
    FROM generated
)
INSERT INTO partner_1.source_well(
    source_well_id, source_field_id, well_code, well_type, well_status, commissioning_date, design_depth_m
)
SELECT source_well_id, source_field_id, well_code, well_type, well_status, commissioning_date, design_depth_m
FROM ranked
ON CONFLICT (source_well_id) DO UPDATE SET
    source_field_id = EXCLUDED.source_field_id,
    well_code = EXCLUDED.well_code,
    well_type = EXCLUDED.well_type,
    well_status = EXCLUDED.well_status,
    commissioning_date = EXCLUDED.commissioning_date,
    design_depth_m = EXCLUDED.design_depth_m;

INSERT INTO partner_1.measurement_parameter
(parameter_id, parameter_code, parameter_name, unit_name, min_value, max_value, description)
VALUES
(1,'OIL_RATE','Дебит нефти','м3/сут',0,100,'Среднесуточный дебит нефти.'),
(2,'WATER_RATE','Дебит воды','м3/сут',0,150,'Среднесуточный дебит воды.'),
(3,'GAS_RATE','Дебит газа','тыс.м3/сут',0,25,'Среднесуточный дебит газа.'),
(4,'WATER_CUT','Обводнённость','%',0,100,'Доля воды в добываемой жидкости.'),
(5,'RESERVOIR_PRESSURE','Пластовое давление','МПа',0,60,'Учебное значение пластового давления.'),
(6,'BOTTOMHOLE_PRESSURE','Забойное давление','МПа',0,60,'Учебное значение забойного давления.'),
(7,'TEMPERATURE','Температура','°C',-20,180,'Температура измеряемой среды.'),
(8,'DYNAMIC_FLUID_LEVEL','Динамический уровень','м',0,5000,'Глубина динамического уровня жидкости.')
ON CONFLICT (parameter_id) DO UPDATE SET
    parameter_code=EXCLUDED.parameter_code, parameter_name=EXCLUDED.parameter_name,
    unit_name=EXCLUDED.unit_name, min_value=EXCLUDED.min_value,
    max_value=EXCLUDED.max_value, description=EXCLUDED.description;

INSERT INTO partner_1.measurement_method(method_id, method_code, method_name, description)
VALUES
(1,'PRODUCTION_TEST','Исследование режима работы','Комплексное исследование дебитов и обводнённости.'),
(2,'PRESSURE_SURVEY','Замер давления','Замер пластового и забойного давления.'),
(3,'FLUID_LEVEL','Замер уровня жидкости','Определение динамического уровня жидкости.'),
(4,'AUTOMATED_MONITORING','Автоматизированный мониторинг','Периодическая регистрация параметров датчиками.')
ON CONFLICT (method_id) DO UPDATE SET
    method_code=EXCLUDED.method_code, method_name=EXCLUDED.method_name, description=EXCLUDED.description;

INSERT INTO partner_1.measuring_device
(device_id, device_code, device_type, serial_number, manufacturer, calibration_date, next_calibration_date, device_status)
SELECT n,
       'SYN-MDEV-' || lpad(n::text,3,'0'),
       CASE n % 4 WHEN 0 THEN 'Манометрический комплекс' WHEN 1 THEN 'Дебитомер'
                 WHEN 2 THEN 'Уровнемер' ELSE 'Многофункциональный измерительный комплекс' END,
       'SYN-SN-' || lpad(n::text,5,'0'),
       CASE n % 3 WHEN 0 THEN 'Учебный приборостроительный завод А' WHEN 1 THEN 'Учебный приборостроительный завод Б' ELSE 'Учебный приборостроительный завод В' END,
       DATE '2024-01-01' + (n * 11),
       DATE '2027-01-01' + (n * 7),
       'operating'
FROM generate_series(1,12) AS g(n)
ON CONFLICT (device_id) DO UPDATE SET
    device_code=EXCLUDED.device_code, device_type=EXCLUDED.device_type,
    serial_number=EXCLUDED.serial_number, manufacturer=EXCLUDED.manufacturer,
    calibration_date=EXCLUDED.calibration_date,
    next_calibration_date=EXCLUDED.next_calibration_date,
    device_status=EXCLUDED.device_status;

INSERT INTO partner_1.measurement_operator
(operator_id, operator_code, operator_name, qualification, operator_status)
SELECT n,
       'SYN-OP-' || lpad(n::text,3,'0'),
       'Учебный оператор измерений № ' || lpad(n::text,2,'0'),
       CASE n % 3 WHEN 0 THEN 'Исследование скважин' WHEN 1 THEN 'Контроль давления' ELSE 'Промысловые измерения' END,
       'active'
FROM generate_series(1,10) AS g(n)
ON CONFLICT (operator_id) DO UPDATE SET
    operator_code=EXCLUDED.operator_code, operator_name=EXCLUDED.operator_name,
    qualification=EXCLUDED.qualification, operator_status=EXCLUDED.operator_status;

-- Синхронизация identity-последовательностей после явной загрузки локальных ID.
SELECT setval(pg_get_serial_sequence('partner_1.source_field','source_field_id'),
              (SELECT MAX(source_field_id) FROM partner_1.source_field), TRUE);
SELECT setval(pg_get_serial_sequence('partner_1.source_well','source_well_id'),
              (SELECT MAX(source_well_id) FROM partner_1.source_well), TRUE);
SELECT setval(pg_get_serial_sequence('partner_1.measurement_parameter','parameter_id'),
              (SELECT MAX(parameter_id) FROM partner_1.measurement_parameter), TRUE);
SELECT setval(pg_get_serial_sequence('partner_1.measurement_method','method_id'),
              (SELECT MAX(method_id) FROM partner_1.measurement_method), TRUE);
SELECT setval(pg_get_serial_sequence('partner_1.measuring_device','device_id'),
              (SELECT MAX(device_id) FROM partner_1.measuring_device), TRUE);
SELECT setval(pg_get_serial_sequence('partner_1.measurement_operator','operator_id'),
              (SELECT MAX(operator_id) FROM partner_1.measurement_operator), TRUE);

COMMIT;

SELECT 'source_field' AS table_name, COUNT(*) AS rows_count FROM partner_1.source_field
UNION ALL SELECT 'source_well', COUNT(*) FROM partner_1.source_well
UNION ALL SELECT 'measurement_parameter', COUNT(*) FROM partner_1.measurement_parameter
UNION ALL SELECT 'measurement_method', COUNT(*) FROM partner_1.measurement_method
UNION ALL SELECT 'measuring_device', COUNT(*) FROM partner_1.measuring_device
UNION ALL SELECT 'measurement_operator', COUNT(*) FROM partner_1.measurement_operator
ORDER BY table_name;
