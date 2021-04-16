rem 
rem file:before_after.sql
rem location: /users/willij/oracle
rem
rem This SQL*Plus script evaluates a target tablespace to determine
rem the potential benefit of coalescing the neighboring free space
rem extents.  If the "New FSFI" value is beneith your threshold,
rem then the tablespace must be defragmented.
rem
set verify off pagesize 60
ttitle center 'Before-After Changes Report for '&&1 skip 2
break on starting_file_id skip 1
column new_length format 99999999
column num_fragments format 99999999
column current_top format 99999999

spool before_after.listing;

SELECT
   starting_file_id,              /*starting file ID for extent*/
   starting_block_id,             /*starting block ID for extent*/
   sum(blocks) new_length,        /*comb. length for extents*/
   count(blocks) num_fragments,   /* number of frags combined*/
   max(blocks) current_top        /* largest extent of the set*/
from contig_space
where tablespace_name = upper('&&1') 
group by
   starting_file_id,
   starting_block_id
rem having count(*) > 1
order by 1,2
/

ttitle center 'Old FSFI rating for '&&1 skip 1
column fsfi format 999.999

select
      sqrt(max(blocks)/sum(blocks))*
      (100/sqrt(sqrt(count(blocks)))) fsfi
from sys.dba_free_space
where tablespace_name = upper('&&1') 
/

ttitle center 'New FSFI rating for '&&1 skip 1
column new_fsfi format 999.999
select
      sqrt((max(sum_blocks))/sum(sum_blocks))*
      (100/sqrt(sqrt(count(sum_blocks)))) new_fsfi
from new_look
where tablespace_name = upper('&&1')
/
spool off
undefine 1
