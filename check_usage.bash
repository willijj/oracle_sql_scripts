#!/bin/bash

top -n1 | grep -i -C3 cpu\(s\) | tee "log.txt"

string1=$(grep -i cpu\(s\) log.txt)
string3=$(grep -i swap: log.txt)

#===============================================================================
# Get CPU percent_used
#===============================================================================

totalCpu=$(echo $string1 | sed 's/\s\s*/ /g' | cut -d'%' -f1 | cut -d' ' -f2)
echo
echo "LOOK HERE ..."
echo
echo "Percentage of used CPU    = "$totalCpu"%   :: escalate to App owner (for SQL tuning) if      > 90%"

#===============================================================================
# Get Memory percent_used
# -----------------------
# Calculation based on OEM process (MOS Doc ID 1908853.1 )
#
# formula used by Enterprise Manager 12.1.0.3 for Linux Memory Utilization (%), for example:
# Memory Utilization (%) = (100.0 * (activeMem) / realMem)
#  = 100 * 25046000/99060536
#  = 25.28
# EM Shows : 25.5
# Here, activeMem is Active Memory (Active), and realMem is Total Memory (MemTotal).
#
#===============================================================================

cat /proc/meminfo | grep MemTotal > "/tmp/log.txt"
cat /proc/meminfo | grep Active\: >> "/tmp/log.txt"

totalMem=`grep -i mem /tmp/log.txt | awk '{print $2}' `
usedMem=`grep -i act /tmp/log.txt | awk '{print $2}' `
pctUsedMem=`echo "scale=2;$usedMem/$totalMem*100" | bc`
echo "Percentage of used memory =" $pctUsedMem"%  :: escalate to DBA (DB bounce needed) if          > 95%"

#===============================================================================
# Get Swap percent_used
#===============================================================================

totalSwap1=$(echo $string3 | sed 's/\s\s*/ /g' | cut -d' ' -f2)
totalSwap2="${totalSwap1%?}"
c=$totalSwap2
usedSwap1=$(echo $string3 | sed 's/\s\s*/ /g' | cut -d' ' -f4)
usedSwap2="${usedSwap1%?}"
d=$usedSwap2
percentageUsedSwap2=$(echo "scale=4;$d/$c*100" | bc)
percentageUsedSwap="${percentageUsedSwap2%??}"
echo "Percentage of used swap   =" $percentageUsedSwap"%  :: escalate to SysAdmin (swap undersized) if      > 50%"
echo
echo

#===============================================================================
# List top-10 memory consuming PIDs
#===============================================================================

echo
echo "List ot top-10 memory consuming PIDs"
echo "------------------------------------"
echo
ps aux | sort +5 -6 -n -r | head -10
