select snap_id, disk_reads_delta reads_delta,
                executions_delta exec_delta,
                disk_reads_delta / decode(executions_delta, 0, 1, executions_delta) rds_exec_ratio, sql_id
from dba_hist_sqlstat
where disk_reads_delta > 100000
order by disk_reads_delta desc
/
