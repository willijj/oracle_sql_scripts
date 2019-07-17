-- For the most comprehensive treatment of Oracle SQL tuning with AWR, 
-- see the book Oracle Tuning: The Definitive Reference and Oracle SQL Tuning: The Definitive Reference. 

-- The AWR tables contain super-useful information about the time-series execution plans for SQL statements 
-- and this repository can be used to display details about the frequency of usage for table and indexes. 
-- This article will explore these AWR tables and expose their secrets.

-- The AWR tables contain super-useful information about the time-series execution plans for SQL statements 
-- and this repository can be used to display details about the frequency of usage for table and indexes. 
-- This article will explore these AWR tables and expose their secrets.

-- We have the following AWR tables for SQL tuning.

-- dba_hist_sqlstat 
-- dba_hist_sql_summary 
-- dba_hist_sql_workarea 
-- dba_hist_sql_plan 
-- dba_hist_sql_workarea_histogram 

-- These simple tables represent a revolution in Oracle SQL tuning and we can now employ time-series 
-- techniques to optimizer SQL with better results than ever before. Let's take a closer look at these views. 



-- dba_hist_sqlstat

-- This view is very similar to the v$sql view but it contains important SQL metrics for each snapshot. 
-- These include important delta (change) information on disk reads and buffer gets, as well as time-series 
-- delta information on application, I/O and concurrency wait times.

col c1 heading 'Begin|Interval|time'    format a20
col c2 heading 'SQL|ID'                 format a13
col c3 heading 'Executions|Delta'       format 9,999
col c4 heading 'Buffer|Gets|Delta'      format 9,999
col c5 heading 'Disk|Reads|Delta'       format 9,999
col c6 heading 'IO Wait|Delta'          format 9,999
col c7 heading 'Application|Wait|Delta' format 9,999
col c8 heading 'Concurrency|Wait|Delta' format 9,999


break on c1 skip 2
break on c2 skip 2
select
   begin_interval_time c1,
   sql_id              c2, 
   executions_delta    c3,
   buffer_gets_delta   c4,
   disk_reads_delta    c5,
   iowait_delta        c6,
   apwait_delta        c7,
   ccwait_delta        c8
from
   dba_hist_snapshot
natural join
   dba_hist_sqlstat
order by
   c1, c2;

-- dba_hist_sql_plan

-- The dba_hist_sql_plan table contains time-series data about each object (table, index, view) involved in the query. 
-- The important columns include the cardinality, cpu_cost, io_cost and temp_space required for the object.

-- The query below will show the main predicates involved for each object component in a SQL execution plan:

col c1 heading 'Begin|Interval|time' format a20
col c2 heading 'SQL|ID'              format a13
col c3 heading 'Object|Name'         format a20
col c4 heading 'Search Columns'      format 99
col c5 heading 'Cardinality'         format 99
col c6 heading 'Access|Predicates'   format a80
col c6 heading 'Filter|Predicates'   format a80


break on c1 skip 2
break on c2 skip 2
select
   begin_interval_time c1,
   sql_id              c2, 
   object_name         c3,
   search_columns      c4,
   cardinality         c5,
   access_predicates   c6, 
   filter_predicates   c7
from
   dba_hist_snapshot
natural join
   dba_hist_sql_plan
order by
   c1, c2;


-- But there is lots more information in dba_hist_sql_plan that is useful. The query below will extract importing 
-- costing information for all objects involved in each query.

col c1 heading 'Begin|Interval|time' format a20
col c2 heading 'SQL|ID'              format a13
col c3 heading 'Object|Name'         format a20
col c4 heading 'Search Columns'      format 9,999
col c5 heading 'Cardinality'         format 9,999
col c6 heading 'Disk|Reads|Delta'    format 9,999
col c7 heading 'Rows|Processed'      format 9,999

break on c1 skip 2
break on c2 skip 2
select
   begin_interval_time c1,
   sql_id              c2, 
   object_name         c3,
   bytes               c4,
   cpu_cost            c5,
   io_cost             c6,
   temp_space          c7
from
   dba_hist_snapshot
natural join
   dba_hist_sql_plan
order by
   c1, c2;



-- Now that we see the important table structures lets examine how we can get spectacular reports from this AWR data.

-- Viewing table and index access with AWR

-- One of the problems in Oracle9i was the single bit-flag that was used to monitor index usage. 
-- You could set the flag with the "alter index xxx monitoring usage" command, and see if the index was accessed 
-- by querying the v$object_usage view. 

-- The goal of any index access is to use the most selective index for a query, the one that produces the 
-- smallest number of rows. The Oracle data dictionary is usually quite good at this, but it is up to you to 
-- define the index. Missing function-based indexes are a common source of sub-optimal SQL execution because Oracle 
-- will not use an indexed column unless the WHERE clause matches the index column exactly.

col c1 heading 'Begin|Interval|time' format a20
col c2 heading 'SQL|ID' format a13
col c3 heading 'Object|Name' format a20

col c4 heading 'Search Columns' format 999,999
col c5 heading 'Cardinality' format 999,999
col c6 heading 'Disk|Reads|Delta' format 999,999
col c7 heading 'Rows|Processed' format 999,999

break on c1 skip 2
break on c2 skip 2

select
   begin_interval_time c1,
   sql_id c2, 
   object_name c3,
   search_columns c4,
   cardinality c5,
   disk_reads_delta c6,
   rows_processed_delta c7
from
   dba_hist_sql_plan
natural join
   dba_hist_snapshot
natural join
   dba_hist_sqlstat;

 
-- You can also use the dba_hist_sql_plan table to gather counts about the frequency of participation of 
-- objects inside queries.

col c1 heading 'Begin|Interval|time' format a20
col c2 heading 'SQL|ID'              format a13
col c3 heading 'Object|Name'         format a20
col c4 heading 'Object|Count'        format 999,999

break on c1 skip 2
break on c2 skip 2

select
   to_char(begin_interval_time,'yyyy-mm-dd HH24') c1, 
   sql_id c2, 
   object_name c3,
   count(*) c4
from
   dba_hist_sql_plan
natural join
   dba_hist_snapshot
group by
   to_char(begin_interval_time,'yyyy-mm-dd HH24'), 
   sql_id, 
  object_name ;

 
-- Here we can see the average SQL invocations for every database object, averaged by hour-of-the day or 
-- day-of-the-week. Understanding the SQL signature can be extremely useful for determining what objects to place 
-- in your KEEP pool, and to determining the most active tables and indexes in your database. 

col c1 heading 'Begin|Interval|time' format a20			
col c2 heading 'Object|Name' format a20
col c3 heading 'Search Columns' format 999,999
col c4 heading 'Disk|Reads|Delta' format 999,999
col c5 heading 'Rows|Processed' format 999,999
col c6 heading 'Access|Predicates' format a200
col c7 heading 'Filter|Predicates' format a200

break on c1 skip 2

select
   begin_interval_time c1,
   object_name c2,
   search_columns c3,
   disk_reads_delta c4,
   rows_processed_delta c5,
   access_predicates c6,
   filter_predicates c7
from
   dba_hist_sql_plan
natural join
   dba_hist_snapshot
natural join
   dba_hist_sqlstat;



-- The new access_predicates and filter_predicates columns are very useful because we no longer need to 
-- parse-out the WHERE clause of each SQL statement to see the access and filtering criteria for the SQL statements.

-- Counting object usage inside SQL

-- In Oracle10g we can easily see what indexes are used, when they are used and the context where they are used. 
-- Here is a simple AWR query to plot index usage:

col c1 heading 'Begin|Interval|time' format a20
col c2 heading 'Search Columns' format 999,999
col c2 heading 'Invocation|Count' format a20

break on c1 skip 2

select
   begin_interval_time c1,
   count(*) c3
from
   dba_hist_sqltext
natural join
   dba_hist_snapshot
where
   lower(sql_text) like lower('%cust_name_idx%')
;

-- This will produce an output like this, showing a summary count of all indexes used during the snapshot interval.

-- Conclusion

-- Oracle SQL tuning is constantly different. As the data changes, Oracle must be able to accommodate the 
-- changes with new execution plans. AWR now provides complete time-series SQL execution data and further research 
-- is sure to find exciting new ways to tune SQL as the data changes over time.

-- For more information on SQL tuning with Oracle10g AWR, see my book "Oracle Tuning: The Definitive Reference".  
-- You can save over 30% by getting it directly from the publisher.



-- Reader feedback

-- Oracle tuning guru Earl Shaffer adds this customization to the script above, a sophisticated script to see 
-- SQL delta change over time :

-- REM File: sqlstathist.sql

set echo off feed off lines 100 pages 9999
clear col
clear break
col beginttm      head 'Begin|Interval' format a14
col sqlid         head 'SQL|ID' format a13
col execsdlt      head 'Delta|Execs' format 99990
col bufgetwaitdlt head 'Delta|Buffer|Gets' format 9999990
col dskrdwaitdlt  head 'Delta|Disk|Reads' format 999990
col iowaitdlt     head 'Delta|IO Wait' format 9999990
col appwaitdlt    head 'Delta|Wait|App' format 9999990
col concurwaitdlt head 'Delta|Wait|Concur' format 99990
break on beginttm skip 1

spool sqlstathist.lis


select
   to_char(begin_interval_time,'mm-dd hh24:mi:ss') beginttm,
   sql_id sqlid, 
   executions_delta execsdlt,
   buffer_gets_delta bufgetwaitdlt,
   disk_reads_delta dskrdwaitdlt,
   iowait_delta iowaitdlt,
   apwait_delta appwaitdlt,
   ccwait_delta concurwaitdlt
from
   dba_hist_snapshot sn,
   dba_hist_sqlstat ss
where
   ss.snap_id = sn.snap_id and
   begin_interval_time > (sysdate - 4/24)
order by
   beginttm,
   ( executions_delta + buffer_gets_delta +
     disk_reads_delta + iowait_delta +
     apwait_delta + ccwait_delta ) desc
/


spool off
clear break
clear col
set echo on feed on lines 80 pages 60
 

-- An Oracle professional also offers this script to find SQL over time, by date:

select
s.sql_id,
sum(case
when begin_interval_time = to_date('14-feb-2009 1100','dd-mon-yyyy hh24mi') then s.executions_total
else 0
end) sum_after,
(sum(case
when begin_interval_time >= to_date('14-feb-2009 1100','dd-mon-yyyy hh24mi') then s.executions_total
else 0
end) -
sum(case
when begin_interval_time < to_date('14-feb-2009 1100','dd-mon-yyyy hh24mi') then s.executions_total
else 0
end)) difference
from 
   dba_hist_sqlstat s,
   dba_hist_snapshot sn
where 
   sn.begin_interval_time between to_date('05-nov-2008 0001','dd-mon-yyyy hh24mi') 
and 
   to_date('05-nov-2008 2359','dd-mon-yyyy hh24mi') 
and
   sn.snap_id=s.snap_id
group by 
   s.sql_id
order by 
   difference desc;

 

