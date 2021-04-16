rem | This SQL select statement calculates the INITIAL storage byte
rem | value for an index, given inputs of projected estimated row count 
rem | and average size of a row for the index. Index overhead, storage
rem | overhead, BLOCK overhead, and PCT_FREE,11 bytes,1.1 factor,90 bytes 
rem | and 10%, respectively, are wired into the calculation.   
rem -------------------------------------------------------------
rem | Steven Vasilakos   12/05/95
rem -------------------------------------------------------------




select round(1.1 * (((&1 * (&2 + 11))/(8102 * .9)) * 8192)) || ' BYTES' 
"INITIAL INDEX STORAGE" from dual;
