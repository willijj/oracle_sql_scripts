select 'alter '||object_type||' '||object_name||' compile;' 
from user_objects  
where status='INVALID'
/
