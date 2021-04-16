#!/bin/bash
 #===================================================================================
 #
 # FILE: adr_purge.sh
 #
 # USAGE: use it
 #
 # DESCRIPTION:
 # OPTIONS:
 # REQUIREMENTS:
 # AUTHOR: Matt D
 # CREATED: June 12, 2012
 # VERSION: 2
 #
 #
 #
 #
 #
 #
 #===================================================================================
 
# Common funtions
 
function start_up()
{
 clear screen
 echo "#########################################################"
 echo "# This will clean up your Diagnotics Area for Oracle #"
 echo "#########################################################"
 
echo
 
echo "################################################"
 echo "# #"
 echo "# What would you like to do ? #"
 echo "# #"
 echo "# 1 == Clean up #"
 echo "# #"
 echo "# 2 == Do NOTHING #"
 echo "# #"
 echo "################################################"
 echo
 echo "Please enter in your choice:> "
 read whatwhat
}
 
function clean_it()
{
echo "Please enter in a number for trace data"
echo "older than <minuntes> to be purged"
read old_data
 
# Read the adrci
$ORACLE_HOME/bin/adrci exec="show homes"|grep -v : | while read file_line
do
 echo "################################################"
 echo "ADR Size Utilization BEFORE PURGE"
 echo "################################################"
 du -sh $ORACLE_BASE/${file_line}
 $ORACLE_HOME/bin/adrci exec="set home ${file_line};purge -age ${old_data} -type TRACE" #Trace file
 $ORACLE_HOME/bin/adrci exec="set home ${file_line};purge -age ${old_data} -type INCIDENT" #Incidents - added 10.14.2013
 $ORACLE_HOME/bin/adrci exec="set home ${file_line};purge -age ${old_data} -type CDUMP" #Core DUmps - added 10.14.2013
 $ORACLE_HOME/bin/adrci exec="set home ${file_line};purge -age ${old_data} -type HM" #Health Monitor Reports - added 10.14.2013
 $ORACLE_HOME/bin/adrci exec="set home ${file_line};purge -age ${old_data} -type ALERT" #Alert files - added 10.14.2013
 echo "################################################"
 echo "ADR Size Utilization AFTER PURGE"
 echo "################################################"
 du -sh $ORACLE_BASE/${file_line}
 
done
}
function do_nothing()
{
 echo "################################################"
 echo "You don't want to do nothing...lazy..."
 echo "So...you want to quit...yes? "
 echo "Enter yes or no"
 echo "################################################"
 read DOWHAT
 if [[ $DOWHAT = yes ]]; then
 echo "Yes"
 exit 1
 else
 echo "No"
 work_time
 fi
 
}
function oracle_base_set()
{
if [[ ! -d $ORACLE_BASE ]]
 then
 echo "Please set your ORACLE_BASE"
 echo "and re-run"
 # exit 1
fi
}
 
function oracle_home_set()
{
if [[ ! -d $ORACLE_HOME ]]
 then
 echo "Please set your ORACLE_HOME"
 echo "and re-run"
 # exit 1
fi
}
 
 
function work_time()
{
oracle_base_set
oracle_home_set
start_up
case $whatwhat in
 1)
 clean_it
 ;;
 2)
 do_nothing
 ;;
esac
}
 
# Go to work~
work_time
