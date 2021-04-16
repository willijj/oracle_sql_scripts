/* 
   check_archlogs.sql
   
   Locate archive needed to start captures for this instance

   INPUTS: File name of the spool file||instance name
*/



set lines 100

spool &&1


 

prompt =========================================================================================
prompt
prompt ++ Minimum Archive Log Necessary to Restart Capture ++   
prompt Note:  This query is valid for databases where the capture processes exist for the same source database.
prompt

set serveroutput on
DECLARE
 hScn number := 0;
 lScn number := 0;
 sScn number;
 ascn number;
 alog varchar2(1000);
begin
  select min(start_scn), min(applied_scn) into sScn, ascn
    from dba_capture;


  DBMS_OUTPUT.ENABLE(2000); 

  for cr in (select distinct(a.ckpt_scn)
             from system.logmnr_restart_ckpt$ a
             where a.ckpt_scn <= ascn and a.valid = 1
             and exists (select * from system.logmnr_log$ l
               where a.ckpt_scn between l.first_change# and l.next_change#)
             order by a.ckpt_scn desc)
  loop
    if (hScn = 0) then
       hScn := cr.ckpt_scn;
    else
       lScn := cr.ckpt_scn;
       exit;
    end if;
  end loop;

  if lScn = 0 then
    lScn := sScn;
  end if;

 dbms_output.put_line('Capture will restart from SCN ' || lScn ||' in the following file:');
   for cr in (select name, first_time  
               from DBA_REGISTERED_ARCHIVED_LOG 
               where lScn between first_scn and next_scn order by thread#)
  loop

     dbms_output.put_line(cr.name||' ('||cr.first_time||')');

  end loop;
end;
/



spool off

exit;



 
