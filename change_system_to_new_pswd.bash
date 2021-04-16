#!/bin/bash

# Walk through DBNAMEs in oratab
for dbname in `egrep -v "^(\#|\+|\$|\*)" /etc/oratab | egrep "^\w{3,9}" | cut -d ':' -f1 | uniq`; do

# Determine home for DBNAME
        strORACLE_HOME=`egrep -v "^(\#|\+|\$)" /etc/oratab | grep -i ${dbname} | cut -d ':' -f2`
        export ORACLE_HOME=$strORACLE_HOME
        export PATH=$ORACLE_HOME/bin:/home/oracle/rman:${strOriginalPATH}
        export ORACLE_SID="${dbname}"

echo "=================================================="
echo "Changing SYS/SYSTEM password to new password .... "
echo "=================================================="
echo " "

# change SYS and SYSTEM password in DB
        $ORACLE_HOME/bin/sqlplus -S /nolog << EOF
          conn / as sysdba;
          alter user sys identified by iwNeE_uawFpa3;
          alter user system identified by iwNeE_uawFpa3 account unlock;
          exit;
EOF

# rebuild oracle password file

        orapwd file=$ORACLE_HOME/dbs/orapw"${dbname}" password=iwNeE_uawFpa3 force=y

echo "====================================="
echo "Validating new password working .... "
echo "====================================="
echo " "

strtest=`$ORACLE_HOME/bin/sqlplus -S /nolog << EOF
conn system/iwNeE_uawFpa3;
exit;
EOF`

strlength=${#strtest}

echo "========"
echo "Status: "
echo "========"
echo " "

if [ ${strlength} -eq 0 ]; then
  echo "change to new password = successful ..." 
else
  echo "change to new password = failed -- contact DBA"
fi

echo " "
echo " "

done

