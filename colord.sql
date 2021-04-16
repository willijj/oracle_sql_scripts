select column_name, column_id, data_type, data_length, nullable
from dba_tab_columns
where table_name = upper('dhr_t')
and column_name = upper('&1')
/
