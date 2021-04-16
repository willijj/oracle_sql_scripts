@@configdiffdb.sql
connect &&trial_schema_owner/&&trial_schema_owner_password@&&trialdb_tnsnames_alias

set serveroutput on;
set linesize 120;

spool create_neg_rule.log;

begin
  for y1 in (select trim(sys_context('userenv','session_user')) trial_name,
                    trim(sys_context('userenv','instance_name')) instance_name from dual) loop
dbms_output.put_line('begin');
   for x1 in (select table_name from user_tables where table_name like 'PFEX_PENDINGTRANS%') loop    
dbms_output.put_line('dbms_streams_adm.add_table_rules(table_name=>'''||y1.trial_name||'.'||x1.table_name||''',');
dbms_output.put_line('streams_type=>''CAPTURE'',');
dbms_output.put_line('streams_name=>''CP_'||upper(y1.instance_name)||''',');
dbms_output.put_line('queue_name=>''STRMADMIN.CP_'||upper(y1.instance_name)||'_Q'||''',');
dbms_output.put_line('inclusion_rule=>FALSE);');
dbms_output.put_line('commit;');
   end loop;
dbms_output.put_line('end;');
dbms_output.put_line('/');
  end loop;
end;
/

spool off;

connect strmadmin/&&streams_admin_user_rep_passwd@&&trialdb_tnsnames_alias

set feedback on

set feedback on
set echo on
set heading on

@@create_neg_rule.log;

exit;
 
  
