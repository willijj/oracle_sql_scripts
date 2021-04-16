prompt
prompt
prompt *********************************************************** 
prompt  Buffer Busy Waits may signal a high update table with too 
prompt  few freelists.  Find the offending table and add more freelists. 
prompt 
prompt 
prompt *********************************************************** 
prompt 
prompt 

column buffer_busy_wait format 999,999,999 
column mydate heading 'yr.  mo dy Hr.' 

select
   to_char(snap_time,'yyyy-mm-dd HH24')      mydate, 
   new.name, 
   new.buffer_busy_wait-old.buffer_busy_wait buffer_busy_wait 
from 
   perfstat.stats$buffer_pool_statistics old, 
   perfstat.stats$buffer_pool_statistics new, 
   perfstat.stats$snapshot               sn 
where 
   snap_time > sysdate-&1 
and 
   new.name <> 'FAKE VIEW' 
and 
   new.snap_id = sn.snap_id 
and 
   old.snap_id = sn.snap_id-1 
and 
   new.buffer_busy_wait-old.buffer_busy_wait > 1 
group by 
   to_char(snap_time,'yyyy-mm-dd HH24'), 
   new.name, 
   new.buffer_busy_wait-old.buffer_busy_wait 
; 
