declare                                                                                                                                                                                                                                                                                                         
vJob  number;                                                                                                                                                   
begin                                                                                                                                                                                                                                                                        
dbms_job.submit(job=>vJob,what=>'refresh_procs.REFRESH_WITH_STREAMS_DELAY(15, true);', next_date=>sysdate+20/1440,interval=>'sysdate+1/24');  
commit;
end;     
/

select job,what from user_jobs
/


prompt 'Enter the above job number to reschedule for 5 minutes from now'


exec DBMS_JOB.NEXT_DATE(&jobno,SYSDATE+5/256);
