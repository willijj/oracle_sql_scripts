select a.username,a.osuser,b.spid,a.sid
from v$session a,v$process b
where a.paddr=b.addr
and a.sid=27
/


prompt - now --- cmd> orakill <SID> <SPID>