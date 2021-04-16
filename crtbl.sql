/**************************************************************
 * Filename: crtbl.sql                                        *
 * Date: 12/22/98                                             *
 * Purpose: generate a create table script.  Input parameters *
 *          are table owner and name.                         * 
 **************************************************************/

set head off
set feedback off
set verify off

define owner=&1
define tbl=&2

col dummy new_value max_col_id noprint;
col column_name for a40
col data_type   for a30
col nullable    for a20

select max(column_id) dummy
from sys.dba_tab_columns
where owner = upper('&owner')
  and table_name = upper('&tbl');

spool tbl.&tbl;

select 'create table '||table_name
from sys.dba_tables
where table_name = upper('&tbl');

select decode(column_id,1,'(','')||column_name column_name, 
       data_type||decode(data_type,'DATE','','('||data_length||')')   data_type,
        decode(nullable,'N','NOT NULL','')||
              decode(column_id,&max_col_id,')',',') nullable
from sys.dba_tab_columns
where table_name = upper('&tbl')
and owner = upper('&owner')
order by column_id;

spool off;
