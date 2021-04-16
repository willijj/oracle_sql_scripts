set termout on;
set serveroutput on;
whenever sqlerror exit failure;
declare
v_change_track_file varchar2(4000);
v_run_string     varchar2(4000);
begin
for a in (select status, archiver from gv$instance where archiver = 'STARTED' and inst_id = 1) loop
  for b in (select status, filename from v$block_change_tracking where status != 'ENABLED') loop
select substr(file_name,1,instr(file_name,'sysaux')-1)||instance_name||'_rman_change_track.f'
  into v_change_track_file
  from dba_data_files, v$instance
 where tablespace_name = 'SYSAUX'
   and rownum = 1;
v_run_string := 'alter database enable block change tracking using file '||chr(39)||v_change_track_file||chr(39)||' reuse';
dbms_output.put_line('v_run_string is: '||v_run_string);
execute immediate v_run_string;
  end loop; /* end 'b' loop */
end loop;    /* end 'a' loop */
end;
/

