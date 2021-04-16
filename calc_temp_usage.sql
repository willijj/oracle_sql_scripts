select nvl(b.tablespace_name,nvl(a.tablespace_name,'UNKNOWN')) name ,
       round(((mbytes_alloc-nvl(mbytes_free,0))/mbytes_max)*100,2) pct_used
from (select sum(bytes)/1024/1024 mbytes_free , tablespace_name from dba_free_space group by tablespace_name) a ,
(select sum(bytes)/1024/1024 mbytes_alloc ,
        case when (sum(maxbytes/1024/1024) < sum(bytes)/1024/1024) then sum(bytes)/1024/1024
        else sum(maxbytes/1024/1024) end mbytes_max ,
        tablespace_name from dba_data_files group by tablespace_name) b
where a.tablespace_name (+) = b.tablespace_name
union
select tablespace_name,
       round(("used_blocks" / "alloc_blocks") * 100,2) pct_used
from
(
select distinct a.tablespace_name,
       sum(decode(a.autoextensible,'NO',a.blocks,a.maxblocks)) "alloc_blocks",
       nvl(b.Used_blcks,0) "used_blocks"
from dba_temp_files a, 
     (select tablespace, sum(nvl(blocks,0)) Used_blcks
        from v$tempseg_usage
       group by tablespace) b
where a.tablespace_name = b.tablespace (+)
group by a.tablespace_name, nvl(b.Used_blcks,0)
);