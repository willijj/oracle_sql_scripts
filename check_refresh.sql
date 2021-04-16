col schema format a20
set pages 1000
select USER AS SCHEMA, 
ROUND(((MAX(last_refresh_date)-MIN(last_refresh_date))*1440)) AS ELAPSED,
to_char(MIN(last_refresh_date),'MM-DD-YY HH24:MI:SS') AS start_time,
to_char(MAX(last_refresh_date),'MM-DD-YY HH24:MI:SS') AS stop_time,
 refresh_num from irt_refresh_history 
where history_type='A' and refresh_method!='FORCE'
and refresh_asof>SYSDATE-2
GROUP BY user, refresh_num order by refresh_num
/

select mview_name, to_char(last_refresh_date, 'MM-DD HH24:MI'),staleness from irv_mviews_dur 
--where staleness <>'FRESH'
order by refresh_seq
/