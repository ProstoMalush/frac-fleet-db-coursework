-- btree_gist добавляет GiST operator class для равенства BIGINT,
-- необходимый для EXCLUDE по equipment_unit_id и временному диапазону.
CREATE EXTENSION IF NOT EXISTS btree_gist;
