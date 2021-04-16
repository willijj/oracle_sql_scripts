select a.serial#, a.sid, a.username, b.id1, c.sql_text
from v$session a, v$lock b, v$sqltext c
where b.id1 in
(select distinct e.id1
from v$session d, v$lock e
where d.lockwait = e.kaddr)
and a.sid = b.sid
and c.hash_value = a.sql_hash_value
and b.request = 0;
