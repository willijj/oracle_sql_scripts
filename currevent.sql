REM Copyright (C) Think Forward.com 1998- 2004. All rights reserved. 
set pages 999
set lines 90

column c1 heading 'Event|Name'             format a30
column c2 heading 'Total|Waits'            format 999,999,999
column c3 heading 'Seconds|Waiting'        format 999,999
column c4 heading 'Total|Timeouts'         format 999,999,999
column c5 heading 'Average|Wait|(in secs)' format 99.999

ttitle 'System-wide Wait Analysis|for current wait events'

select
   event                         c1,
   total_waits                   c2,
   time_waited / 100             c3,
   total_timeouts                c4,
   average_wait    /100          c5
from
   sys.v_$system_event
where
   event not in (
    'dispatcher timer',
    'lock element cleanup',
    'Null event',
    'parallel query dequeue wait',
    'parallel query idle wait - Slaves',
    'pipe get',
    'PL/SQL lock timer',
    'pmon timer',
    'rdbms ipc message',
    'slave wait',
    'smon timer',
    'SQL*Net break/reset to client',
    'SQL*Net message from client',
    'SQL*Net message to client',
    'SQL*Net more data to client',
    'virtual circuit status',
    'WMON goes to sleep'
   )
AND
 event not like 'DFS%'
and
   event not like '%done%'
and
   event not like '%Idle%'
AND
 event not like 'KXFX%'
order by
   c2 desc
;


