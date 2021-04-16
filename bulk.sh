#!/usr/bin/env bash
 
# IMPORTANT !! ->  This script is very dangerous. It will connect to all servers and execute a task. !!!
# Handle with CARE !
 
# How to use the script:
# Your ldap account
# File with the list of servers to connect
# the name of the script to execute. It must be in the same folder.
#Ex. -> ./bulk.sh fpalomar serverlist.lst dg_status.sh | tee -a /tmp/Output.txt
#
# The script will prompt for your LDAP password.
# Note that in some datacenters there are actually two LDAP domains. To simplify, is recommended that you use the same password for both.
 
# It is strongly recommended to change the ldap password after you have used this script.
 
 
echo -n "Please type your LDAP password:"
read -s PASSWORD
echo
 
LDAP_USER=$1
INPUT=$2
SCRIPT_NAME=$3
 
while IFS= read -r line
do
 
   if ping -w 1 -c 2 $line | grep "from" 2>/dev/null 1>&2
   then
      ./t3.sh $LDAP_USER $PASSWORD $line $SCRIPT_NAME
   fi
 
done < "$INPUT"