/*   Taken from the bounce_streams code - must be connected as strmadmin to execute the PL/SQL !!!! */


spool bounce_list.txt

set serverout on size 100000

declare

cursor getcapture is
	select 	capture_name 
	from 	dba_capture;

cursor getpropagation is 
	select 	SOURCE_QUEUE_NAME,
		DESTINATION_DBLINK 
	from 	dba_propagation ;

begin
  for gc in getcapture 
  LOOP

    begin
 	IF '&&1' = 'STOP' THEN
        	dbms_capture_adm.stop_capture(capture_name => upper(gc.capture_name));
  	ELSE
   		dbms_capture_adm.start_capture(capture_name => upper(gc.capture_name));
   	END IF;
    exception
        when others then 
            dbms_output.put_line( 'failed' || gc.capture_name );
    end;

  end LOOP;

  for gp in getpropagation 
  LOOP
    begin

   	IF '&&1' = 'STOP' THEN
          	dbms_aqadm.disable_propagation_schedule(
            					  queue_name 	=> gp.source_queue_name,
           					  destination 	=> gp.destination_dblink
           					     );
   	ELSE
   		dbms_aqadm.enable_propagation_schedule(
               					 queue_name => gp.source_queue_name,
              					 destination => gp.destination_dblink
						);
	END IF;
    exception
        when others then 
                    dbms_output.put_line( 'failed' || gp.source_queue_name );
                    dbms_output.put_line( 'failed' || gp.destination_dblink );
    end;

  end LOOP;

end;
/



spool off



/*   Here is the SQL :) again, you must connect as STRMADMIN  */


set heading off
set lines 132
set pages 0

spool stop_start_capture.sql

Select 'prompt'||chr(39)||' Stop Capture'||chr(39) from dual;

select 'Connect strmadmin/oracle'

select 'exec dbms_capture_adm.stop_capture(capture_name =>'||chr(39)||upper(capture_name)||chr(39)||'  );'
from dba_capture;

Select 'prompt'||chr(39)||' Start Capture'||chr(39) from dual;

select 'exec dbms_capture_adm.start_capture(capture_name =>'||chr(39)||upper(capture_name)||chr(39)||'  );'
from dba_capture;

select ' select CAPTURE_NAME,STATUS from dba_capture;' from dual;

spool off

spool stop_start_propagat.sql

Select 'prompt'||chr(39)||' Stop propagation'||chr(39) from dual;


select 'spool bounce_propagat.log'

select 'exec dbms_aqadm.disable_propagation_schedule(queue_name => '
        ||chr(39)||SOURCE_QUEUE_NAME||chr(39)||',destination => '||chr(39)||DESTINATION_DBLINK||chr(39)||');' from dba_propagation ;

Select 'prompt'||chr(39)||' Start propagation'||chr(39) from dual;

select 'exec dbms_aqadm.enable_propagation_schedule(queue_name => '
        ||chr(39)||SOURCE_QUEUE_NAME||chr(39)||',destination => '||chr(39)||DESTINATION_DBLINK||chr(39)||');' from dba_propagation ;


select ' select CAPTURE_NAME,STATUS from dba_capture;' from dual;

select 'spool off'
           					  
spool off






select capture_name,status
from dba_capture
/

prompt 'Connect as strmadmin to run '


