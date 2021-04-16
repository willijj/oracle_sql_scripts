set heading off
set lines 132
set pages 0

spool stop_start_applies.sql

Select 'Stop Apply' from dual;

select 'Connect strmadmin/oracle'

select 'EXEC DBMS_APPLY_ADM.STOP_APPLY(apply_name => '||chr(39)||upper(apply_name)||chr(39)||'  );'
from dba_apply;

Select 'Start Applies' from dual;

select 'EXEC DBMS_APPLY_ADM.START_APPLY(apply_name => '||chr(39)||upper(apply_name)||chr(39)||'  );'
from dba_apply;


select 'spool off' from dual;
           					  





select 'select apply_name,status from dba_apply;' from dual
/


spool off