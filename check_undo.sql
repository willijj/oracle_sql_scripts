set serverout on size 1000000
set feedback off
set heading off
set lines 132
declare
  cursor get_undo_stat is
         select d.undo_size/(1024*1024) "C1",
                substr(e.value,1,25)    "C2",
                (to_number(e.value) * to_number(f.value) *
g.undo_block_per_sec) / (1024*1024) "C3",
                round((d.undo_size / (to_number(f.value) *
g.undo_block_per_sec)))             "C4"
           from (select sum(a.bytes) undo_size
                   from v$datafile      a,
                        v$tablespace    b,
                        dba_tablespaces c
                  where c.contents = 'UNDO' 
                    and c.status = 'ONLINE'
                    and b.name = c.tablespace_name
                    and a.ts# = b.ts#)  d,
                v$parameter e,
                v$parameter f,
                (select max(undoblks/((end_time-begin_time)*3600*24))
undo_block_per_sec from v$undostat)  g
          where e.name = 'undo_retention'
            and f.name = 'db_block_size';
begin
dbms_output.put_line(chr(10)||chr(10)||chr(10)||chr(10) || 'To optimize UNDO you have two choices :'); dbms_output.put_line('==================================================
==' || chr(10));
  for rec1 in get_undo_stat loop
      dbms_output.put_line('A) Adjust UNDO tablespace size according to UNDO_RETENTION :' || chr(10));
      dbms_output.put_line(rpad('ACTUAL UNDO SIZE ',65,'.')|| ' : ' ||
TO_CHAR(rec1.c1,'999999') || ' MEGS');
      dbms_output.put_line(rpad('OPTIMAL UNDO SIZE WITH ACTUAL UNDO_RETENTION (' || ltrim(TO_CHAR(rec1.c2/60,'999999')) || ' MINUTES)
',65,'.') || ' : ' || TO_CHAR(rec1.c3,'999999') || ' MEGS');
      dbms_output.put_line(chr(10));
      dbms_output.put_line('B) Adjust UNDO_RETENTION according to UNDO tablespace size :' || chr(10));
      dbms_output.put_line(rpad('ACTUAL UNDO RETENTION ',65,'.') || ' : ' || TO_CHAR(rec1.c2/60,'999999') || ' MINUTES');
      dbms_output.put_line(rpad('OPTIMAL UNDO RETENTION WITH ACTUAL UNDO SIZE (' || ltrim(TO_CHAR(rec1.c1,'999999')) || ' MEGS) ',65,'.') || ' : ' || TO_CHAR(rec1.c4/60,'999999') || ' MINUTES');
  end loop;
dbms_output.put_line(chr(10)||chr(10));
end;
/

select 'Number of "ORA-01555 (Snapshot too old)" encountered since the last startup of the instance : ' || sum(ssolderrcnt)
  from v$undostat;


