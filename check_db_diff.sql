@@configdiffdb.sql
connect &&rep_schema_owner/&&rep_schema_owner_password&&repdbstring

set verify off
set heading off
set pagesize 0
set trimspool on
set linesize 200
set feedback off
set echo on
set serveroutput on size 1000000

spool check_diff.log;

DECLARE
    v_cnt1      NUMBER;
    v_cnt2      NUMBER;
    v_cnt_tot   NUMBER;
    v_primary_key VARCHAR2(200);

CURSOR rpt_tables_cursor IS
    SELECT table_name from user_tables where table_name like 'PF_%';
      --  and table_name != 'PF_CONTROLDATA_LONGRAW'
      --  and table_name != 'PF_COMMENT_LONG'
      --  and table_name != 'PF_RESOURCEDATA_LONGRAW';

BEGIN

   v_cnt_tot := 0;
   FOR rpt_tables_rec in rpt_tables_cursor LOOP
-- dbms_output.put_line(rpt_tables_rec.table_name);
       execute immediate 'select count(*) from (select * from &&trial_schema_owner'||'.'||rpt_tables_rec.table_name||' minus  select * from &&trial_schema_owner'||'.'||rpt_tables_rec.table_name||'&&rep_dblink_name_select)' into v_cnt1;
       execute immediate 'select count(*) from ( select * from &&trial_schema_owner'||'.'||rpt_tables_rec.table_name||'&&rep_dblink_name_select minus select * from &&trial_schema_owner'||'.'||rpt_tables_rec.table_name||')' into v_cnt2;
       if v_cnt1 > 0 or v_cnt2 > 0 then
           v_cnt_tot := v_cnt1;
           v_cnt_tot := v_cnt2;         
           dbms_output.put_line(chr(10));
           dbms_output.put_line('--' ||rpt_tables_rec.table_name);
           dbms_output.put_line(chr(10));
       end if;
       if v_cnt1 > 0 then       
            dbms_output.put_line('-- rpt - trial count = '||v_cnt1);
       end if;

       if v_cnt2 > 0 then       
            dbms_output.put_line('-- trial - rpt count = '||v_cnt2);
       end if;
       if v_cnt1 > 0 or v_cnt2 > 0 then
           dbms_output.put_line(chr(10));
           dbms_output.put_line('-- ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++');
           dbms_output.put_line(chr(10));
       end if;
       if v_cnt1 > 0 then  
           execute immediate 'select rpt_procs.pkfields('''||rpt_tables_rec.table_name||''','''||'&&trial_schema_owner'||''') from dual' into v_primary_key;
           dbms_output.put_line('delete from '||rpt_tables_rec.table_name||' where ');
           dbms_output.put_line(v_primary_key||' in');
           dbms_output.put_line('(select '||substr(v_primary_key,2,length(v_primary_key)-2));
           dbms_output.put_line('from (select * from '||rpt_tables_rec.table_name||' minus ');
           dbms_output.put_line('select * from '||'&&trial_schema_owner'||'.'||rpt_tables_rec.table_name||'&&rep_dblink_name_select'||'));');
       end if; 
       if v_cnt2 > 0 then
           dbms_output.put_line('insert into /*+ append */ '||rpt_tables_rec.table_name);
           dbms_output.put_line('select * from '||'&&trial_schema_owner'||'.'||rpt_tables_rec.table_name||'&&rep_dblink_name_select');
           dbms_output.put_line('minus select * from '||rpt_tables_rec.table_name||';');
       end if;
       if v_cnt1 > 0 or v_cnt2 > 0 then
           dbms_output.put_line(chr(10));
	   dbms_output.put_line('commit;');
           dbms_output.put_line('-- ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++');
       end if;

   END LOOP;
   if v_cnt_tot = 0 then
       dbms_output.put_line(chr(10));
       dbms_output.put_line('exit;');
       dbms_output.put_line('setenv');
       dbms_output.put_line('set oracle_sid='||substr('&&repdb_tnsnames_alias',instr('&&repdb_tnsnames_alias','_')+1,length('&&repdb_tnsnames_alias')));
       dbms_output.put_line('sqlplus strmadmin/oracle');
       dbms_output.put_line('exec dbms_apply_adm.delete_all_errors(''AP_'||upper('&&trial_schema_owner')||''');');
       dbms_output.put_line('delete from stream_autofix;');
   end if;
END;
/

spool off;

set feedback on

set feedback on
set echo on
set heading on

@@check_diff.log
