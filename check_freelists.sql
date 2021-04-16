/* 
 * file: check_freelists.sql
 * what: check if freelist parameter is set appropiately
 *
 * from: Oracle Performance & Tuning Techniques -- author: Rich Niemiec
 */

Set TrimSpool	On
Set Line	132
Set Pages	57
Set NewPage	0
Set FeedBack	Off
Set Verify	Off
Set Term	Off
TTitle		Off
BTitle		Off
Column Pct Format 990.99 Heading "% Of      |Free List Waits"
Column Instance New_Value _Instance NoPrint
Column Today	New_Value _Date NoPrint
select Global_Name Instance, To_Char
       (SysDate, 'FxDay DD, YYYY HH:MI') Today
from Global_Name;

Ttitle On
TTitle Left 'Date Run: ' _Date Skip 1-
	Center 'Free list Contention' Skip 1 -
	Center 'If Percentage is Greater than 1%' Skip 1 -
	Center 'Consider increasing the number of free lists' Skip 1 -
	Center 'Instance Name: ' _Instance
select	((A.Count/(B.Value + C.Value)) * 100) Pct
from	V$WaitStat A, V$SysStat B, V$SysStat C
where	A.Class = 'free list'
and B.Statistic# = (select Statistic#
		      from V$StatName
		     where Name = 'db block gets')
and C.Statistic# = (select Statistic#
		      from V$StatName
		     where Name = 'consistent gets')
/
Column Total_Waits Format 999,999,999,990 Heading "Buffer Busy Waits"
Column DB_Gets	   Format 999,999,999,990 Heading "DB Block Gets"
Column Con_Get	   Format 999,999,999,990 Heading "Consistent Gets"
column Busy_Rate   Format 990.999	  Heading "Busy Rate"
TTitle Left 'Date Run: ' _Date Skip 1-
	Center 'Buffer Busy Waits Rate' Skip 1 -
	Center 'If >5% review V$WaitStat' Skip 1 -
	Center 'Instance Name: ' _Instance Skip 2
select Total_Waits, B.Value DB_Get, C.Value Con_Get,
	((A.Total_Waits / (B.Value + c.Value)) * 100) Busy
from V$System_Event A, V$SysStat B, V$SysStat C
where a.event = 'buffer busy waits'
and B.Statistic# = (select Statistic#
		      from v$StatName
		     where Name = 'db block gets')
and C.Statistic# = (select Statistic#
			from V$statname
		    where Name = 'consistent gets')
/
