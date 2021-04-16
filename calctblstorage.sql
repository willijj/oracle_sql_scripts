rem | This SQL select statement calculates the INITIAL storage byte
rem | value for a table, given inputs of projected estimated row count 
rem | and average size of a row for the table. BLOCK overhead,     
rem | and PCT_FREE, 90 bytes and 10%, respectively, are wired into
rem | the calculation.
rem -------------------------------------------------------------
rem | Steven Vasilakos   12/05/95
rem -------------------------------------------------------------




select round(((&1 * &2)/(8102 * .9)) * 8192) || ' BYTES' 
"INITIAL TABLE STORAGE" from dual;
