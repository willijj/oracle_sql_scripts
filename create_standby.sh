#!/bin/bash
# DG script compatible with GBUCS 1.0, 2.0, and 3.0

function banner_message ()
{
echo -e "
##############
#
# \E[1;35m$1\E[0;39m
#
###############
"
}


function error_level () {

  if [[ $1 -eq 0 ]];then
    echo -e "###############\n#\n# \E[1;35m$2 successfully completed.\E[0;39m\n#\n###############"
  elif [[ $3 -eq 0 ]];then
    echo -e "###############\n#\n# \E[0;31m$2 failed - please fix this after the upgrade completes.\E[0;39m\n#\n###############"
  elif [[ $3 -eq 1 ]];then
    echo -e "###############\n#\n# \E[0;31m$2 failed - please fix this in another screen.\E[0;39m\n#\n###############"
    proceed_yn
  elif [[ $3 -eq 2 ]];then
    echo -e "###############\n#\n# \E[0;31m$2 failed - this is not fixable so aborting.\E[0;39m\n#\n###############"
    exit 1
  fi

}


function proceed_yn () {

  yn=

  while [[ "${yn}" != "Y" ]] && [[ "${yn}" != "y" ]] && [[ "${yn}" != "N" ]] && [[ "${yn}" != "n" ]];do
    read -p "OK to proceed? [Y|N] " yn
  done

  if [[ "${yn}" = "N" ]] || [[ "${yn}" = "n" ]];then
    exit
  fi

}


function setup_user_equivalence ()
{
clear

banner_message "User Equivalence Configuration from Primary to Standby Servers"
echo -e "\E[0;31mNote: Please make sure that user equivalence of the nodes that belong to the same cluster is already working.\E[0;33m\n"
echo -e "\E[0;31mUser Equivalence from Primary to Standby Servers is not yet configured.  Starting User Equivalence Configuration .... \E[0;33m\n"

LDAP_USER="`who am i |awk '{print $1}'`"

echo -e "Note: Enter Password of LDAP Account \E[0;31m${LDAP_USER} \E[0;33m 4 times\n"


user_equivalence_success=false
fail_counter=0

if [[ ! -f /home/oracle/.ssh/authorized_keys ]]; then
  cd /home/oracle/.ssh/
  ssh-keygen -t rsa -N '' -f /home/oracle/.ssh/id_rsa
  cat /home/oracle/.ssh/id_rsa.pub > /home/oracle/.ssh/authorized_keys
fi


while [[ ${user_equivalence_success} == false  ]]; do
  scp -q /home/oracle/.ssh/authorized_keys ${LDAP_USER}@${shn}:/tmp/
  touch /tmp/sby_authorized_keys
  chmod 777 /tmp/sby_authorized_keys

/usr/bin/ssh -q -tt ${LDAP_USER}@${shn}  "sudo su - root -c \"
if [[ ! -f /home/oracle/.ssh/authorized_keys ]]; then
  cd /home/oracle/.ssh/
  sudo -S -u oracle ssh-keygen -t rsa -N '' -f /home/oracle/.ssh/id_rsa
  cat /home/oracle/.ssh/id_rsa.pub > /home/oracle/.ssh/authorized_keys
  chown oracle:oinstall /home/oracle/.ssh/authorized_keys
fi
chown oracle:oinstall /tmp/authorized_keys
cat /tmp/authorized_keys >> /home/oracle/.ssh/authorized_keys
rm /tmp/authorized_keys
cat /home/oracle/.ssh/authorized_keys  | ssh -q ${LDAP_USER}@${phn} 'cat > /tmp/sby_authorized_keys'
exit
\""

  if [[ $? -eq 0 ]]; then
    cat /tmp/sby_authorized_keys > /home/oracle/.ssh/authorized_keys
  fi

  if $( ssh -q -o PasswordAuthentication=no ${shn} exit  ); then
    user_equivalence_success=true
  else
    if [[ ${fail_counter} -lt 2 ]]; then
      echo -e "\n\E[0;31mYou entered too many incorrect passwords. Try configuring user equivalence again. \n\E[0;33m"
      ((fail_counter++))
    else
      echo -e "\n\E[0;31mYou entered an incorrect password of your LDAP account too many times. Try to configure user equivalence manually. exiting.. \n\E[0;39m"
      exit 1
    fi
  fi
done

rm /tmp/sby_authorized_keys

if ${prac}; then
  primary_nodes_wd=(doea0xm0t01.avp13536dt01.icprdiadclsvc1.oraclevcn.com doea0xm0t02.avp13536dt01.icprdiadclsvc1.oraclevcn.com)

  for ((i=0;i<${#primary_nodes_wd[@]};i++)); do
    primary_nodes[i]=$(echo ${primary_nodes_wd[i]} | cut -d '.' -f1)
    primary_nodes_vip[i]=`host ${primary_nodes[i]}-vip.${primary_domain}| head -n 1 | awk '{ print $NF; }'`
  done

  standby_nodes_wd=()
  sGRID_HOME=$(ssh ${ssh_ops} oracle@${shn} cat /u01/app/oraInventory/ContentsXML/inventory.xml | grep -vi 'removed' | awk '/HOME NAME/ && /grid/ {print $3}' | awk -F\\\" '{print $2}' | grep -v agent | sort | tail -1)

  if [[ -z ${standby_nodes_wd} ]]; then
    standby_nodes=($(ssh -q ${ssh_ops} oracle@${shn} ${sGRID_HOME}/bin/olsnodes | tr '\n' ' ' | awk '{print substr($0, 0, length($0)-1)}'))
    for ((i=0;i<${#standby_nodes[@]};i++)); do
      standby_nodes_wd[i]="${standby_nodes[i]}.${standby_domain}"
      standby_nodes_vip[i]=`host ${standby_nodes[i]}-vip.${standby_domain}| head -n 1 | awk '{ print $NF; }'`
    done
  else
    for ((i=0;i<${#standby_nodes_wd[@]};i++)); do
      standby_nodes[i]=$(echo ${standby_nodes_wd[i]} | cut -d '.' -f1)
      standby_nodes_vip[i]=`host ${standby_nodes[i]}-vip.${standby_domain}| head -n 1 | awk '{ print $NF; }'`
    done
  fi

else
  primary_nodes=(`echo ${phn}`)
  standby_nodes=(`echo ${shn}`)
fi

for i in ${primary_nodes_wd[@]}; do
  if [[ "${i}" != "${primary_nodes_wd[0]}" ]]; then
    if $( ssh -q -o PasswordAuthentication=no ${i} exit  ); then
      scp -q /home/oracle/.ssh/authorized_keys ${i}:/home/oracle/.ssh/authorized_keys
    else
      echo -e "\n\E[0;31mAll the nodes in the same cluster should already have user equivalence configured. Fix this manually. \n\E[0;39m"
      exit 1
    fi
  fi
done

for i in ${standby_nodes_wd[@]}; do
  if [[ "${i}" != "${standby_nodes_wd[0]}" ]]; then

ssh ${ssh_ops} oracle@${shn} <<-EOF
  scp -q /home/oracle/.ssh/authorized_keys ${i}:/home/oracle/.ssh/authorized_keys
EOF

  fi
done

echo -e "\n"
for i in ${standby_nodes_wd[@]};do
  /usr/bin/ssh-keyscan -H ${i} >> /home/oracle/.ssh/known_hosts
done

for i in ${primary_nodes_wd[@]};do
  scp -q /home/oracle/.ssh/known_hosts oracle@${i}:/home/oracle/.ssh/known_hosts
done

for j in ${standby_nodes_wd[@]};do
  scp -q /home/oracle/.ssh/known_hosts oracle@${j}:/home/oracle/.ssh/known_hosts
done

echo -e "\n"
echo -e "\E[0;32mSetup of User Equivalence from Primary to Standby is Successful\E[0;39m\n"


}

function check_ssh () {
	${SSH} oracle@${1} <<-EOF
		declare -A start_time=()
		declare -A curr_time=()

    if [[ -f /home/oracle/.ssh/id_rsa.pub ]]; then
      start_time[id_xsa_oracle]=\$(stat -c %Z /home/oracle/.ssh/id_rsa.pub)
  		curr_time[id_xsa_oracle]=\$(stat -c %Z /home/oracle/.ssh/id_rsa.pub)
    elif [[ -f /home/oracle/.ssh/id_dsa.pub ]]; then
      start_time[id_xsa_oracle]=\$(stat -c %Z /home/oracle/.ssh/id_dsa.pub)
      curr_time[id_xsa_oracle]=\$(stat -c %Z /home/oracle/.ssh/id_dsa.pub)
    fi

		start_time[auth_keys_oracle]=\$(stat -c %Z /home/oracle/.ssh/authorized_keys)
		curr_time[auth_keys_oracle]=\$(stat -c %Z /home/oracle/.ssh/authorized_keys)

    mkdir -p ${backup_dir}/ssh/${1}/oracle
		for sshfiles in authorized_keys id_rsa id_rsa.pub id_dsa id_dsa.pub;do
			if [[ -f /home/oracle/.ssh/\${sshfiles} ]]; then
			  cp /home/oracle/.ssh/\${sshfiles} ${backup_dir}/ssh/${1}/oracle
      fi
		done
    chown -R oracle:oinstall ${backup_dir}/ssh/${1}/oracle

		while [[ -f ${2} ]];do
      if [[ -f /home/oracle/.ssh/id_rsa.pub ]]; then
        curr_time[id_xsa_oracle]=\$(stat -c %Z /home/oracle/.ssh/id_rsa.pub 2>/dev/null || echo 99999999999)
      elif [[ -f /home/oracle/.ssh/id_dsa.pub ]]; then
        curr_time[id_xsa_oracle]=\$(stat -c %Z /home/oracle/.ssh/id_dsa.pub 2>/dev/null || echo 99999999999)
      fi

			curr_time[auth_keys_oracle]=\$(stat -c %Z /home/oracle/.ssh/authorized_keys 2>/dev/null || echo 99999999999)

			if [[ "\${curr_time[auth_keys_oracle]}" != "\${start_time[auth_keys_oracle]}" ]] || \
				 [[ "\${curr_time[id_xsa_oracle]}" != "\${start_time[id_xsa_oracle]}" ]];then
        for sshfiles in authorized_keys id_rsa id_rsa.pub id_dsa id_dsa.pub;do
          if [[ -f /home/oracle/.ssh/\${sshfiles} ]]; then
            cp ${backup_dir}/ssh/${1}/oracle/\${sshfiles} /home/oracle/.ssh/
            chown oracle:oinstall /home/oracle/.ssh/\${sshfiles}
          fi
				done

        if [[ -f /home/oracle/.ssh/id_rsa.pub ]]; then
				  start_time[id_xsa_oracle]=\$(stat -c %Z /home/oracle/.ssh/id_rsa.pub)
        elif [[ -f /home/oracle/.ssh/id_dsa.pub ]]; then
          start_time[id_xsa_oracle]=\$(stat -c %Z /home/oracle/.ssh/id_dsa.pub)
        fi
				start_time[auth_keys_oracle]=\$(stat -c %Z /home/oracle/.ssh/authorized_keys)
			fi
		done
		exit
	EOF
}

function modify_listener ()
{

if [[ -z `grep "SID_LIST_LISTENER=" ${backup_dir}/listener.ora` ]] && [[ ${current_host::${#current_host}-1} == ${phns::${#phns}-1} ]]; then
  if ${prac}; then
    if [[ ${env_type} -eq 3 ]]; then
      current_host_num=$((${current_host: -1}-1))
    else
      current_host_num=$(case \"${current_host: -1}\" in \"a\") echo 0;; \"b\") echo 1;; \"c\") echo 2;; \"d\") echo 3;; \"e\") echo 4;; \"f\") echo 5;; \"g\") echo 6;; \"h\") echo 7;;esac;)
    fi
  else
    current_host_num=0
  fi
  echo -e "\n${listener_start}${pri_listener_entry[${current_host_num}]}\n${listener_end}">>${backup_dir}/listener.ora
  return 1
fi

if [[ -z `grep "SID_LIST_LISTENER=" ${backup_dir}/listener.ora` ]] && [[ ${current_host::${#current_host}-1} == ${shns::${#shns}-1} ]]; then
  if ${srac}; then
    if [[ ${env_type} -eq 3 ]]; then
      current_host_num=$((${current_host: -1}-1))
    else
      current_host_num=$(case \"${current_host: -1}\" in \"a\") echo 0;; \"b\") echo 1;; \"c\") echo 2;; \"d\") echo 3;; \"e\") echo 4;; \"f\") echo 5;; \"g\") echo 6;; \"h\") echo 7;;esac;)
    fi
  else
    current_host_num=0
  fi
  echo -e "\n${listener_start}${sby_listener_entry[${current_host_num}]}\n${listener_end}">>${backup_dir}/listener.ora
  return 1
fi

counter=1
lpcounter=0
rpcounter=0
startnow=0
checknext=0
insliine=0
while read line; do
  if [[ "${line}" == *"SID_LIST_LISTENER"* ]]; then
    startnow=1
  fi
  if [[ "${line}" == *"SID_NAME=${db_name}"* ]]; then
    checknext=1
    sidpos=$(echo "$line" | grep -b -o SID_NAME | awk 'BEGIN {FS=":"}{print $1}')
    sidpos=$(echo "${line:$(( ${sidpos} + 9 + ${#db_sid} )):1}")
    if [[ "${sidpos}" == ")" ]]; then
      sidpos=0
    fi
    if [[ ${sidpos} -gt 0 ]]; then
      sidpos=$(( ${sidpos} - 1 ))
    fi
  fi
  if [[ "${line}" == *"GLOBAL_DBNAME=${db_name}"* ]]; then
    if [[ "${checknext}" == "1" ]]; then
      checknext=0
      if [[ "${line}" == *"${standby_db_unq}"* ]]; then
        sby_listener_confirm[${sidpos}]=$(( ${counter} - 2 ))
      elif [[ "${line}" == *"${primary_db_unq}"* ]]; then
        pri_listener_confirm[${sidpos}]=$(( ${counter} -2 ))
      fi
    fi
  fi
  if [[ ${startnow} ]]; then
    lpcounter=$(( $(grep -o "(" <<< "${line}" | wc -l) + ${lpcounter} ))
    rpcounter=$(( $(grep -o ")" <<< "${line}" | wc -l) + ${rpcounter} ))
  fi
  if [[ "${line// }" == ")" ]]; then
    if [[ ${rpcounter} == ${lpcounter} ]]; then
      insline=${counter}
    fi
  fi
  ((counter++))
done < "${backup_dir}/listener.ora"

checknext=0
counter=0

if [[ ${current_host::${#current_host}-1} == ${phns::${#phns}-1} ]]; then
  for i in ${primary_nodes[@]}; do
    if [[ "${pri_listener_confirm[${counter}]}" == "-1" ]] && [[ "${i}" == "${current_host}" ]]; then
      checknext=1
      listener_entry="${listener_entry}${pri_listener_entry[${counter}]}"
    fi
  ((counter++))
  done
fi

counter=0

if [[ ${current_host::${#current_host}-1} == ${shns::${#shns}-1} ]]; then
  for i in ${standby_nodes[@]}; do
    if [[ "${sby_listener_confirm[${counter}]}" == "-1" ]] && [[ "${i}" == "${current_host}" ]]; then
      checknext=1
      listener_entry="${listener_entry}${sby_listener_entry[${counter}]}"
    fi
    ((counter++))
  done
fi

if [[ "${checknext}" == "1" ]]; then
  listener_entry=$( echo "${listener_entry}" | cut -c 3- )
  sed -i "${insline} i\\${listener_entry}" "${backup_dir}/listener.ora"
fi
}


function modify_tns ()
{
if [[ -n ${pdbs[@]} ]]; then
  if [[ -z `grep -i "${pdbs[0]} =" ${backup_dir}/tnsnames.ora` ]] && [[ ${current_host::${#current_host}-1} == ${phns::${#phns}-1} ]]; then
    echo -e "${primary_pdbs}" >> ${backup_dir}/tnsnames.ora
  fi

  if [[ -z `grep -i "${pdbs[0]} =" ${backup_dir}/tnsnames.ora` ]] && [[ ${current_host::${#current_host}-1} == ${shns::${#shns}-1} ]]; then
    echo -e "${standby_pdbs}" >> ${backup_dir}/tnsnames.ora
  fi
fi

if [[ -z `grep -E "^\b${primary_tns_alias}\b" ${backup_dir}/tnsnames.ora` ]]; then
  echo -e "${primary_tns}" >> ${backup_dir}/tnsnames.ora
fi

if [[ -z `grep -E "^\b${standby_tns_alias}\b" ${backup_dir}/tnsnames.ora` ]]; then
  echo -e "${standby_tns}" >> ${backup_dir}/tnsnames.ora
fi
}


find_tns_line_number () {

cat -n "${backup_dir}/tnsnames.ora"| while read file
do
found=`echo $file |awk '{print $2}' |sed -r 's/[ |=]*//g'| grep -E "^\b${1}\b"  | wc -l`

if [[ ${found} -gt 0 ]]; then
 echo $file | awk '{print $1}'
fi
done
}

delete_tns_entry () {
tnscounter=0
tnscounter2=0
tnscounter3=0
if [ "$1" != "" ]; then
cat -n "${backup_dir}/tnsnames.ora"| while read line
do
tnscounter=`echo $tnscounter+1|bc`

breakout=true
tnsi=0
line_del_tnscounters=""

if [ "$tnscounter" -eq "$1" ]; then

  while ${breakout}; do
    tnscounter2=`echo $tnscounter+${tnsi}|bc`
    tnscounter3=`echo $tnscounter+${tnsi}+1|bc`
    current_line=`sed -n $tnscounter2'p' "${backup_dir}/tnsnames.ora"`

    end_char=$(sed -n $tnscounter2'p' ${backup_dir}/tnsnames.ora|awk '{print substr($0,length,1)}')

    if [   -z  "$current_line" ]; then
      line_del_tnscounters+=";${tnscounter2}d"
      sed -i '${line_del_tnscounters}' "${backup_dir}/tnsnames.ora"
      breakout=false
    elif [[ "$end_char" == ")" ]]; then

      beg_char=$(sed -n $tnscounter3'p' ${backup_dir}/tnsnames.ora| sed 's/ //g'|awk '{print substr($0,0,1)}')

      if [[  "$beg_char" != ")" ]] && [[ "$beg_char" != "("  ]]; then
        line_del_tnscounters+=";${tnscounter2}d"

        sed -i "${line_del_tnscounters}" ${backup_dir}/tnsnames.ora
        breakout=false
      fi
    fi

    if [[ ${tnsi} -eq 0 ]]; then
      line_del_tnscounters+="${tnscounter2}d"
    else
      line_del_tnscounters+=";${tnscounter2}d"
    fi

    ((tnsi++))
    done
  fi
  done
  sed -i '$!N; /^\(.*\)\n\1$/!P; D' ${backup_dir}/tnsnames.ora

fi
}


function test_port ()
{
temp_result=""
if [[ "$1" == "$phn" ]]; then
    temp_result=`nc -vz $2 $3 < /dev/null 2>&1`
else
    temp_result=`ssh ${ssh_ops} oracle@$1 "nc -vz $2 $3 < /dev/null 2>&1"`
fi


if [[ ${temp_result} == *"succeeded"* ]] || [[ ${temp_result} == *"Connected"* ]]; then
  echo -e "\E[0;32m$1 was able to connect to $2 on port $3\E[0;39m"
else
  echo -e "\E[0;31m$1 failed to connect to $2 on port $3.  Correct this issue and start again.\nExiting\E[0;39m"
  exit 1
fi
}


function node_check ()
{
if [[ ! -f /etc/oratab ]]; then
  echo -e '\n\E[0;31mOracle not installed locally\E[0;39m\n'
  # Exit if Oracle is not installed
  exit
fi


pGRID_HOME=/u01/app/18.0.0.0/grid
DB_HOME=/u01/app/oracle/product/12.1.0.2/dbhome_1
DB_BASE=/u01/app/oracle
db_version=12

phn=$(hostname -f)
phns=$(hostname -s)
primary_domain=$(hostname --domain)

env_type=3

crs_output=`echo $( ${pGRID_HOME}/bin/crsctl stat res -t) | awk '{print $1}'`
if [[ "${crs_output}" != "--------------------------------------------------------------------------------" ]]; then
  if [[ "${crs_output}" = "CRS-4535:" ]]; then
    echo -e "\n\E[0;31mCRS services are down, please correct this and restart the script\n"
  elif [[ "${crs_output}" = "CRS-4639:" ]]; then
    echo -e "\n\E[0;31mHAS is down, please correct this and restart the script\n"
  else
    echo -e "\n\E[0;31mUnable to detect Oracle processes running, please verify and restart the script"
  fi
  exit
fi

crs_output=""

${pGRID_HOME}/bin/olsnodes > /dev/null

if [[ $? -ne 0 ]];then
  pnodecnt=1
  prac=false
else
  pnodecnt=`${pGRID_HOME}/bin/olsnodes | wc -l`
  if [[ ${pnodecnt} -eq 0 ]];then
  pnodecnt=1
  prac=false
  else
        if [[ ${env_type} -eq 3 ]]; then
          pscancnt=`${pGRID_HOME}/bin/srvctl config scan|grep VIP:|wc -l`
          if [[ ${pscancnt} -le 1 ]]; then
            prac=false
          else
            prac=true
            primary_cluster=`${DB_HOME}/bin/srvctl config scan -all|grep -i "scan name"|awk '{print $3}'|sed 's/,//'`
          fi
        else
          primary_cluster=`${pGRID_HOME}/bin/olsnodes -c`
        fi
  fi
fi

home_list=(`cat /etc/oratab | grep -vE '^\#|^\*|^$' | awk -F: '{print $2}' | uniq | tr '\n' ' ' | sed 's/^ *//g' | sed 's/ *$//g'`)

db_list=(`${pGRID_HOME}/bin/crsctl stat res -t | grep ora. | grep .db | grep -vi ORCL|grep -v .svc | grep -v .vip | grep -v mgmtdb | awk -F. '{print $2}' | tr '\n' ' ' | sed 's/^ *//g' | sed 's/ *$//g' | tr '[:lower:]' '[:upper:]' | uniq`)

dgdc=0
counter=0
clear


standby_nodes_wd=()
if [[ -z ${standby_nodes_wd} ]]; then
  clear
  echo -e "\E[0;36m Input Parameters  \n---------------------"

  while [[ "${shn}" == "${shn/.}"  ]] ; do
    echo -e "\E[0;36m"
    echo -e "Note: Use output of \E[0;33mhostname -f\E[0;36m \n"
    read -p "Type in the Standby Server $(echo -e '\E[0;33mFQDN\E[0;36m') (Standalone) or Standby Node-A $(echo -e '\E[0;33mFQDN\E[0;36m') (RAC): " shn
    standby_domain=$(echo ${shn} | cut -d '.' -f2-10)
    shns=$(echo ${shn} | cut -d '.' -f1)
    if [[ "${shn}" == "${shn/.}" ]] ; then
    	echo -e "\n\E[0;31mFQDN is not specified.  Please Try Again and specify a valid FQDN\E[0;39m\n"
    fi
  done
else
  shn=${standby_nodes_wd[0]}
  shns=$(echo ${shn} | cut -d '.' -f1)
  standby_domain=$(echo ${shn} | cut -d '.' -f2-10)
fi

nc -vz ${shn} 22 < /dev/null 2>&1


if [[ $? -ne 0 ]];then
   echo -e "\n\E[0;31mPort 22 is closed. Have port 22 opened by Network Team.\E[0;39m\n"
   exit
fi

if $( ! ssh -q -o PasswordAuthentication=no ${shn} exit  ); then
   setup_user_equivalence
fi

if [[ ${env_type} -eq 3 ]]; then
  standby_domain=$(ssh ${ssh_ops} oracle@${shn} hostname --domain)
fi

ssh ${ssh_ops} oracle@${shn} [[ -f /etc/oratab ]] && checkorcl=1 || checkorcl=0

if [[ "${checkorcl}" = "0" ]]; then
  echo -e "\n\E[0;31mOracle not installed remotely on server ${shn}\E[0;39m\n"
  exit
fi

sGRID_HOME=$(ssh ${ssh_ops} oracle@${shn} cat /u01/app/oraInventory/ContentsXML/inventory.xml | grep -vi 'removed' | awk '/HOME NAME/ && /grid/ {print $3}' | awk -F\\\" '{print $2}' | grep -v agent | sort | tail -1)

crs_output=`echo $(ssh ${ssh_ops} oracle@${shn} "$sGRID_HOME/bin/crsctl stat res -t") | awk '{print $1}'`
if [[ "${crs_output}" != "--------------------------------------------------------------------------------" ]]; then

  if [[ "${crs_output}" = "CRS-4535:" ]]; then
    echo -e "\n\E[0;31mCRS services are down on ${shn}, please correct this and restart the script\n"
  elif [[ "${crs_output}" = "CRS-4639:" ]]; then
    echo -e "\n\E[0;31mHAS is down, please correct this and restart the script\n"
  else
    echo -e "\n\E[0;31mUnable to detect Oracle processes running, please verify and restart the script\n"
  fi
  exit
fi

ssh ${ssh_ops} oracle@${shn} <<-EOF
  ${sGRID_HOME}/bin/olsnodes > /dev/null

  if [[ \$? -ne 0 ]];then
    exit 120
  else
    nodecnt=\$(${sGRID_HOME}/bin/olsnodes | wc -l)
    if [[ \${nodecnt} -eq 0 ]];then
      exit 120
    else
      exit \${nodecnt}
    fi
  fi
EOF

snodecnt=$?

if [[ ${snodecnt} -ne 120 ]] && [[ ${snodecnt} -gt 0 ]]; then
    if [[ ${env_type} -eq 3 ]]; then
      sscancnt=$(ssh -q oracle@${shn} ${sGRID_HOME}/bin/srvctl config scan|grep VIP:|wc -l)
      if [[ ${sscancnt} -le 1 ]]; then
        srac=false
      else
        srac=true
        standby_cluster=$(ssh -q oracle@${shn} ${DB_HOME}/bin/srvctl config scan -all|grep -i "scan name"|awk '{print $3}'|sed 's/,//')
      fi
    else
      srac=true
      standby_cluster=$(ssh -q oracle@${shn} ${sGRID_HOME}/bin/olsnodes -c)
    fi
else
  srac=false
  snodecnt=1
fi

counter=0
if ${prac} ; then
  primary_nodes_wd=(doea0xm0t01.avp13536dt01.icprdiadclsvc1.oraclevcn.com doea0xm0t02.avp13536dt01.icprdiadclsvc1.oraclevcn.com)

  for ((i=0;i<${#primary_nodes_wd[@]};i++)); do
    primary_nodes[i]=$(echo ${primary_nodes_wd[i]} | cut -d '.' -f1)
  done

  first_node=`${pGRID_HOME}/bin/olsnodes | sort | head -1`
  first_node_wd=${primary_nodes_wd[0]}
else
  primary_nodes=(`echo ${phn}`)
  primary_nodes_wd=(`echo ${phn}`)
  first_node=${phn}
  first_node_wd=${phn}
fi
primary_vips=()
if ${srac} ; then
  standby_nodes_wd=()
  if [[ -z ${standby_nodes_wd} ]]; then
    standby_nodes=($(ssh ${ssh_ops} oracle@${shn} ${sGRID_HOME}/bin/olsnodes | tr '\n' ' ' | awk '{print substr($0, 0, length($0)-1)}'))
    for ((i=0;i<${#standby_nodes[@]};i++)); do
      standby_nodes_wd[i]="${standby_nodes[i]}.${standby_domain}"
    done
  else
    for ((i=0;i<${#standby_nodes_wd[@]};i++)); do
      standby_nodes[i]=$(echo ${standby_nodes_wd[i]} | cut -d '.' -f1)
    done
  fi

else
  standby_nodes=(`echo ${shn}`)
  standby_nodes_wd=(`echo ${shn}`)
fi
standby_vips=()


if [[ "${phn}" != "${first_node_wd}" ]]; then
  echo -e "\n\E[0;31mMust be on node 1 of cluster!\E[0;39m\n"
  exit
fi
if ${prac} ; then
  for i in ${primary_nodes[@]}; do
    tempip=`nslookup "${primary_nodes[${counter}]}-vip.${primary_domain}" | grep "Address: " | grep -v "Address:  " | cut -c 10-`
    if [[ "${tempip}" = "" ]]; then
      echo -e "\n\E[0;31mIP lookup for VIP ${primary_nodes[${counter}]}-vip Failed.  VIP needs to be entered into DNS!\E[0;39m\n"
      exit
    fi
    primary_vips[${counter}]=${tempip}
    ((counter++))
  done
else
  primary_vips[0]=`nslookup "${primary_nodes[0]}.${primary_domain}" | grep "Address: " | grep -v "Address:  " | cut -c 10-`
fi

counter=0

if ${srac} ; then
  for i in ${standby_nodes[@]}; do
    tempip=`nslookup "${standby_nodes[${counter}]}-vip.${standby_domain}" | grep "Address: " | grep -v "Address:  " | cut -c 10-`
    if [[ "${tempip}" = "" ]]; then
      echo -e "\n\E[0;31mIP lookup for VIP ${standby_nodes[${counter}]}-vip Failed.  VIP needs to be entered into DNS!\E[0;39m\n"
      exit
    fi
    standby_vips[${counter}]=${tempip}
    ((counter++))
  done
else
  standby_vips[0]=`nslookup "${standby_nodes[0]}.${standby_domain}" | grep "Address: " | grep -v "Address:  " | cut -c 10-`
fi

other_nodes=(`echo "${primary_nodes_wd[@]} ${standby_nodes_wd[@]}" | sed "s@${phn} @@"`)
all_nodes=(`echo "${primary_nodes_wd[@]} ${standby_nodes_wd[@]}"`)
banner_message "Testing ports 1521/22 from all nodes to all nodes"

for ((i=0; i<${#other_nodes[@]}; i++ )); do
  test_port "${primary_nodes_wd[0]}" "${other_nodes[${i}]}" "22"
  test_port "${primary_nodes_wd[0]}" "${other_nodes[${i}]}" "1521"
  test_port "${other_nodes[${i}]}" "${primary_nodes_wd[0]}" "22"
  test_port "${other_nodes[${i}]}" "${primary_nodes_wd[0]}" "1521"
  for ((j=0;j<${#other_nodes[@]};j++)); do
    if [[ ${i} != ${j} ]]; then
      test_port "${other_nodes[i]}" "${other_nodes[${j}]}" "22"
      test_port "${other_nodes[i]}" "${other_nodes[${j}]}" "1521"
    fi
  done
done

cpus=`grep -c ^processor /proc/cpuinfo`
if [[ ${cpus} -gt 8 ]]; then
  cpus=8
fi

banner_message "Checking for all available databases"

sb_list=$(ssh ${ssh_ops} oracle@${shn} "${sGRID_HOME}/bin/crsctl stat res -t | grep ora. | grep .db | grep -vi ORCL | grep -v .svc | grep -v .vip | grep -v mgmtdb | awk -F. '{print $2}' | tr '\n' ' ' | sed 's/^ *//g' | sed 's/ *$//g' | tr '[:lower:]' '[:upper:]' | sed 's/ORA.//g' | sed 's/.DB//g' | uniq")

if [[ ${env_type} -eq 3 ]]; then
  if [[ -z ${sb_list} ]]; then
    echo -e "\n\E[0;31mThere is no Dummy Database detected in the specified Standby Server. If you dropped the dummy database, please recreate the dummy database at least as a cluster resource with DB_NAME so the script can work.\n\E[0;39m"
    exit 1
  fi
fi

dummy=0
temp_list=""
counter=0
for i in ${db_list[@]}; do
{
  confirm=0
  if [[ ${env_type} -eq 3 ]]; then
    pr_dbname=$(${DB_HOME}/bin/srvctl config database -d ${i}|grep -i "Database Name:"|awk '{print $3}')

    for j in ${sb_list[@]}; do
    {
      sb_dbname=$(ssh ${ssh_ops} oracle@${shn} "${DB_HOME}/bin/srvctl config database -d ${j}|grep -i 'Database Name:'"|awk '{print $3}')
      sb_role=$(ssh ${ssh_ops} oracle@${shn} "${DB_HOME}/bin/srvctl config database -d ${j}|grep 'Database role'"|awk -F ': ' '{ print $2 }')
      if [[ "${pr_dbname}" == "${sb_dbname}" ]] || [[ ${sb_role} =~ "STANDBY" ]]; then
        if ${prac} && [[ ${sb_role} =~ "STANDBY" ]]; then
          confirm=1
        elif ${prac} && [[ ${sb_role} == "PRIMARY" ]]; then
          dummy=1
        elif ! ${prac} && [[ ${sb_role} =~ 'STANDBY' ]]; then
          confirm=1
        elif ! ${prac} && [[ ${sb_role} == 'PRIMARY' ]]; then
          dummy=1
        fi
      else
        dummy=1
      fi
    }
    done
  else
    for j in ${sb_list[@]}; do
    {
      if [[ "${db_list[${counter}]:0:${#db_list[${counter}]}}_DG" == "${j}" ]]; then
        confirm=1
      fi

      if [[ "${db_list[${counter}]:0:${#db_list[${counter}]}}" == "${j}" ]]; then
        dummy=1
      fi
    }
    done
  fi

  if [[ $confirm == 0 ]]; then
    temp_list="${temp_list} ${db_list[${counter}]}"
  fi
  ((counter++))
}
done

standby_rebuild=false

if [[ -z "${temp_list// }" ]]; then
  syn=""
  while [[ "${syn}" != "Y" ]] && [[ "${syn}" != "N" ]]; do
    echo -e "\E[0;33m"
    read -p "All databases on this server currently have a standby database. Do you want to rebuild a standby DB? (Y/N) " syn
    echo -e "\E[0;39m"

    syn=`echo "${syn}" | tr '[:lower:]' '[:upper:]'`
    if [[ "${syn}" != "Y" ]] && [[ "${syn}" != "N" ]]; then
      echo -e "\n\E[0;31mInvalid Input.\E[0;39m\n"
    elif [[ "${syn}" == "N" ]]; then
      exit 1
    elif [[ "${syn}" == "Y" ]]; then
      echo "Start Rebuilding db"
      standby_rebuild=true
    fi

  done

else
  db_list=(${temp_list})
fi

dummy_drop=false

if [[ ${dummy} -eq 1 ]]; then
  if [[ ${env_type} -eq 3 ]]; then
    syn=""
  	while [[ "${syn}" != "Y" ]] && [[ "${syn}" != "N" ]]; do
  		echo -e "\E[0;33m"
  		read -p "You have to drop the Dummy DB to be able to proceed with DG Config. Do you want to drop the Dummy DB? (Y/N) " syn
  		echo -e "\E[0;39m"

  		syn=`echo "${syn}" | tr '[:lower:]' '[:upper:]'`
  		if [[ "${syn}" != "Y" ]] && [[ "${syn}" != "N" ]]; then
  			echo -e "\n\E[0;31mInvalid Input.\E[0;39m\n"
  		elif [[ "${syn}" == "N" ]]; then
  			exit 1
  		elif [[ "${syn}" == "Y" ]]; then
  			echo "Start Dropping Dummy db"
  			dummy_drop=true
  		fi

  	done
  else
    echo -e "\n\E[0;31mDrop the Dummy Database in the Standby Server first then re-execute the script.\n\E[0;39m"
  fi
fi

}


get_lag () {

export ORACLE_SID=${db_psid}
export ORACLE_HOME=${DB_HOME}

candidate_for_rebuild=false

temp_standby=$(${DB_HOME}/bin/dgmgrl / <<EOF
  show configuration;
EOF
)

dgmgrl_stby=$(echo "${temp_standby}" | grep 'standby database'|awk '{print $1}'  | tr '[:upper:]' '[:lower:]')

rebuild_really_stby=false

for z in ${dgmgrl_stby[@]}; do
{
  if [[ ${z} == ${standby_db_unq} ]]; then
    rebuild_really_stby=true
  fi
}
done

if ${rebuild_really_stby}; then

lag=$(${DB_HOME}/bin/dgmgrl / <<EOF
  show database verbose ${standby_db_unq};
EOF
)
  apply_lag=$(echo "$lag"| grep 'Apply Lag:'| grep -E ': *[0-9] seconds')
  transport_lag=$(echo "$lag"| grep 'Transport Lag:'| grep -E ': *[0-9] seconds')
  reachable=$(echo "$lag"| grep -A1 'Database Status:'|grep -v 'Database Status:')

  if [[ -z ${apply_lag} || -z ${transport_lag} ]] || [[ ${reachable} != "SUCCESS" ]]; then
    candidate_for_rebuild=true
  else
    echo -e "\n\E[0;31mDatabase is not a candidate for Rebuild because Standby DB is synchronized with the primary.\n\E[0;39m"
    exit 1
  fi
else
  echo -e "\n\E[0;31mThe Database ${standby_db_unq} is currently not on a Standby Role.  Please switchover before you can proceed with the Rebuild.\n\E[0;39m"
  exit 1
fi

}


function get_input ()
{
confirm_all=""

while [[ "${confirm_all}" != "Y" ]]; do
  primary_db_unq=""
  yn=""
  while [[ "${yn}" != "Y" ]]; do
    clear

    if ${standby_rebuild}; then
      echo -e "\E[0;36mStandby Database Unique Name list\n------------"

      counter=0
      for i in ${sb_list[@]}; do
      {
        echo -e "\E[0;36m$((${counter}+1)) - ${i}"
        ((counter++))
      }
      done

      echo -e "\n\E[0;33m"
      sdbins=""

      while [[ ${sdbins} != ?(-)+([0-9]) ]] || (( ${sdbins} < 1 )) || (( ${sdbins} > ${#sb_list[@]} )) ; do
        read -p "`echo -e $'\n'`Enter the standby database you wish to rebuild: " sdbins
        echo -e "\E[0;39m"

        if [[ ${sdbins} != ?(-)+([0-9]) ]] ||  (( ${sdbins} < 1 )) || (( ${sdbins} > ${#sb_list[@]} )) ; then
          echo -e "\n\E[0;31mInvalid Choice.  Please Try Again\E[0;39m\n"
        fi
      done

      yn=""
      while [[ "${yn}" != "Y" ]] && [[ "${yn}" != "N" ]]; do
        echo -e "\E[0;33m"
        read -p "You selected \"${sb_list[$((${sdbins}-1))]}\".  Are you sure you want to DROP and REBUILD the Standby DB ${sb_list[$((${sdbins}-1))]}? (Y/N): " yn
        echo -e "\E[0;39m"
        yn=`echo "${yn}" | tr '[:lower:]' '[:upper:]'`
        if [[ "${yn}" != "Y" ]] && [[ "${yn}" != "N" ]]; then
          echo -e "\n\E[0;31mInvalid Input.\E[0;39m\n"
        fi
      done

      standby_db_unq=`echo "${sb_list[$((${sdbins}-1))]}" | tr '[:upper:]' '[:lower:]'`
      if [[ ${env_type} -eq 3 ]]; then
        db_name=$(ssh ${ssh_ops} oracle@${shn} "${DB_HOME}/bin/srvctl config database -d ${standby_db_unq}|grep -i 'Database Name:'"|awk '{print $3}')
  			primary_db_unq=$(sudo ${pGRID_HOME}/bin/crsctl stat res|grep ${db_name}|grep -E '\.db$'|awk -F '.' '{print $2}')
        if [[ -z ${primary_db_unq} ]]; then
          echo -e "\n\E[0;31mPrimary DB Unique Name is null.  Please Try correcting the DBNAME on standby cluster to match the DBNAME in primary cluster.\E[0;39m"
          echo -e "\E[0;31me.g. srvctl modify database -d ${standby_db_unq} -n <dbname>\E[0;39m\n"
          exit 1
        fi
      else
        primary_db_unq=`echo ${standby_db_unq::${#standby_db_unq}-3}`
        db_name=${primary_db_unq}
  			domain=`hostname -d`
      fi
      loginsuccess=0
      while [[ ${loginsuccess} -eq 0 ]];  do
        echo -e "\n\E[0;33m\n"
        read -p "Type the SYS password of \"$(echo ${db_name}| tr '[:lower:]' '[:upper:]')\": " WD
        export ORACLE_HOME=${DB_HOME}
        export PATH=${PATH}:${DB_HOME}/bin;

        echo -e "\E[0;31m"

        if [[ ${env_type} -eq 3 ]]; then

${DB_HOME}/bin/sqlplus -s /nolog <<!
whenever sqlerror exit 1;
conn sys/${WD}@${primary_db_unq} as sysdba
select * from dual;
exit
!
          else
${DB_HOME}/bin/sqlplus -s /nolog <<!
whenever sqlerror exit 1;
conn sys/${WD}@${db_name} as sysdba
select * from dual;
exit
!
        fi

        if [ $? -eq 0 ]; then
          loginsuccess=1
        fi
        echo -e "\E[0;39m"
      done
    elif ${dummy_drop}; then
      echo -e "\E[0;36mPrimary Database Unique Name list\n------------"

      counter=0
      for i in ${db_list[@]}; do
      {
        echo -e "\E[0;36m$((${counter}+1)) - ${i}"
        ((counter++))
      }
      done

      echo -e "\E[0;33m"
      dbins=""

      while [[ ${dbins} != ?(-)+([0-9]) ]] || (( ${dbins} < 1 )) || (( ${dbins} > ${#db_list[@]} )) ; do
        read -p "`echo -e $'\n'`Enter the database you wish to build a standby database for: " dbins
        echo -e "\E[0;39m"

        if [[ ${dbins} != ?(-)+([0-9]) ]] ||  (( ${dbins} < 1 )) || (( ${dbins} > ${#db_list[@]} )) ; then
          echo -e "\n\E[0;31mInvalid Choice.  Please Try Again\E[0;39m\n"
        fi
      done

      yn=""
      while [[ "${yn}" != "Y" ]] && [[ "${yn}" != "N" ]]; do
        echo -e "\E[0;33m"
        read -p "You selected \"${db_list[$((${dbins}-1))]}\".  Are you sure? (Y/N): " yn
        echo -e "\E[0;39m"
        yn=`echo "${yn}" | tr '[:lower:]' '[:upper:]'`
        if [[ "${yn}" != "Y" ]] && [[ "${yn}" != "N" ]]; then
          echo -e "\n\E[0;31mInvalid Input.\E[0;39m\n"
        fi
      done

      echo -e "\n\n\n\E[0;36mStandby Database Unique Name list\n------------"

      counter=0
      for i in ${sb_list[@]}; do
      {
        echo -e "\E[0;36m$((${counter}+1)) - ${i}"
        ((counter++))
      }
      done

      echo -e "\E[0;33m"
      sdbins=""

      while [[ ${sdbins} != ?(-)+([0-9]) ]] || (( ${sdbins} < 1 )) || (( ${sdbins} > ${#sb_list[@]} )) ; do
        read -p "`echo -e $'\n'`Enter the standby database you wish to Drop and Build as a Standby Database: " sdbins
        echo -e "\E[0;39m"

        if [[ ${sdbins} != ?(-)+([0-9]) ]] ||  (( ${sdbins} < 1 )) || (( ${sdbins} > ${#sb_list[@]} )) ; then
          echo -e "\n\E[0;31mInvalid Choice.  Please Try Again\E[0;39m\n"
        fi
      done

      yn=""
      while [[ "${yn}" != "Y" ]] && [[ "${yn}" != "N" ]]; do
        echo -e "\E[0;33m"
        read -p "You selected \"${sb_list[$((${sdbins}-1))]}\".  Are you REALLY SURE you want to DROP and Build this DB as the Standby DB: ${sb_list[$((${sdbins}-1))]}? (Y/N): " yn
        echo -e "\E[0;39m"
        yn=`echo "${yn}" | tr '[:lower:]' '[:upper:]'`
        if [[ "${yn}" != "Y" ]] && [[ "${yn}" != "N" ]]; then
          echo -e "\n\E[0;31mInvalid Input.\E[0;39m\n"
        fi
      done

  primary_db_unq=`echo "${db_list[$((${dbins}-1))]}" | tr '[:upper:]' '[:lower:]'`
  db_name=$(${DB_HOME}/bin/srvctl config database -d ${primary_db_unq}|grep -i "Database Name:"|awk '{print $3}')
  standby_db_unq=`echo "${sb_list[$((${sdbins}-1))]}" | tr '[:upper:]' '[:lower:]'`

      loginsuccess=0
      while [[ ${loginsuccess} -eq 0 ]];  do
        echo -e "\n\E[0;33m\n"
        read -p "Type the SYS password of \"$(echo ${db_name}| tr '[:lower:]' '[:upper:]')\": " WD
        export ORACLE_HOME=${DB_HOME}
        export PATH=${PATH}:${DB_HOME}/bin;

        echo -e "\E[0;31m"
${DB_HOME}/bin/sqlplus -s /nolog <<!
whenever sqlerror exit 1;
conn sys/${WD}@${primary_db_unq} as sysdba
select * from dual;
exit
!

        if [ $? -eq 0 ]; then
          loginsuccess=1
        fi

        echo -e "\E[0;39m"

      done

    else
      echo -e "\E[0;36mDatabase Unique Name list\n------------"

      counter=0
      for i in ${db_list[@]}; do
      {
        echo -e "\E[0;36m$((${counter}+1)) - ${i}"
        ((counter++))
      }
      done

      echo -e "\n\E[0;33m"
      dbins=""

      while [[ ${dbins} != ?(-)+([0-9]) ]] || (( ${dbins} < 1 )) || (( ${dbins} > ${#db_list[@]} )) ; do
        read -p "`echo -e $'\n'`Enter the database you wish to build a standby database for: " dbins
        echo -e "\E[0;39m"

        if [[ ${dbins} != ?(-)+([0-9]) ]] ||  (( ${dbins} < 1 )) || (( ${dbins} > ${#db_list[@]} )) ; then
          echo -e "\n\E[0;31mInvalid Choice.  Please Try Again\E[0;39m\n"
        fi
      done

      yn=""
      while [[ "${yn}" != "Y" ]] && [[ "${yn}" != "N" ]]; do
        echo -e "\n\n\E[0;33m"
        read -p "You selected \"${db_list[$((${dbins}-1))]}\".  Are you sure? (Y/N): " yn
        echo -e "\E[0;39m"
        yn=`echo "${yn}" | tr '[:lower:]' '[:upper:]'`
        if [[ "${yn}" != "Y" ]] && [[ "${yn}" != "N" ]]; then
          echo -e "\n\E[0;31mInvalid Input.\E[0;39m\n"
        fi
      done

      primary_db_unq=`echo "${db_list[$((${dbins}-1))]}" | tr '[:upper:]' '[:lower:]'`
      db_name=${primary_db_unq}
      standby_db_unq=${primary_db_unq}_dg
      domain=`hostname -d`

      loginsuccess=0

      while [[ ${loginsuccess} -eq 0 ]];  do
        echo -e "\n\E[0;33m\n"
        read -p "Type the SYS password of \"$(echo ${db_name}| tr '[:lower:]' '[:upper:]')\": " WD
        export ORACLE_HOME=${DB_HOME}
        export PATH=${PATH}:${DB_HOME}/bin;

        echo -e "\E[0;31m"
${DB_HOME}/bin/sqlplus -s /nolog <<!
whenever sqlerror exit 1;
conn sys/${WD}@${db_name} as sysdba
select * from dual;
exit
!

        if [ $? -eq 0 ]; then
          loginsuccess=1
        fi

        echo -e "\E[0;39m"

      done
    fi

  done

  clear
  echo -e "\E[0;36mDatabase Name:\E[0;97m ${db_name}"
  echo -e "\E[0:36mDatabase Version:\E[0;97m ${db_version}"
  echo -e "\E[0;36mPrimary DB Unique Name:\E[0;97m ${primary_db_unq}"
  echo -e "\E[0;36mStandby DB Unique Name:\E[0;97m ${standby_db_unq}"
  echo -e "\n\E[0;36mDataguard Broker Config Description:\E[0;97m ${primary_db_unq}\n\E[0;39m"

  echo -e "\E[0;36mPrimary Nodes:\E[0;97m $(echo ${primary_nodes_wd[@]} | tr ' ' ',')"
  echo -e "\E[0;36mStandby Nodes:\E[0;97m $(echo ${standby_nodes_wd[@]} | tr ' ' ',')"

  confirm_all=""
  while [[ "${confirm_all}" != "Y" ]] && [[ "${confirm_all}" != "N" ]]; do
    echo -e "\n\E[0;33m"
    read -p "Is the above information correct? (Y/N or press Q to Quit): " confirm_all
    echo -e "\E[0;39m"
    confirm_all=`echo "${confirm_all}" | tr '[:lower:]' '[:upper:]'`
    if [[ "${confirm_all}" = "Q" ]]; then
      exit
    fi
    if [[ "${confirm_all}" != "Y" ]] && [[ "${confirm_all}" != "N" ]]; then
      echo -e "\n\E[0;31mInvalid Input.\E[0;39m\n"
    fi
  done

done

rac_one=false
last_2c="`ps -ef|grep pmon|grep ${primary_db_unq}|awk '{print $8}'| awk '{print substr($0,length-1,2)}'`"

if ${prac} && [[ ${last_2c} == "_1" ]]; then
  rac_one=true
fi

primary_sids=()
standby_sids=()


if ${rac_one}; then
  primary_sids[0]="${primary_db_unq}_1"
  standby_sids[0]="${standby_db_unq}_1"
else
  for (( i=0; i<${pnodecnt}; i++ )); do
    primary_sids[${i}]="${primary_db_unq}${i}"
  done
  for (( i=0; i<${snodecnt}; i++ )); do
    standby_sids[${i}]="${standby_db_unq}${i}"
  done
fi

if [[ ${env_type} -eq 3 ]]; then
  wallet_dir="`grep -i 'directory=' ${DB_HOME}/network/admin/sqlnet.ora |grep -i tde|sed 's/[() ]//g'|sed 's/\$ORACLE_UNQNAME//g'|sed -r 's/.*[directory|DIRECTORY]=/DIRECTORY=/'|awk -F= '{print $2}'`"
else
  wallet_dir="`grep -i 'directory=' ${DB_HOME}/network/admin/sqlnet.ora |sed 's/[() ]//g'|sed 's/\$ORACLE_UNQNAME//g'|sed -r 's/.*[directory|DIRECTORY]=/DIRECTORY=/'|awk -F= '{print $2}'`"
fi
primary_tns_alias="${primary_db_unq}"
standby_tns_alias="${standby_db_unq}"

if [[ ${env_type} -eq 3 ]]; then
  backup_dir="/opt/oracle/dcs/commonstore/standby_${db_name}"
  restore_dir="/opt/oracle/dcs/commonstore/standby_${db_name}"
else
  backup_dir="/u03/standby_${db_name}"
  restore_dir="/u03/standby_${db_name}"
fi

mkdir -p "${backup_dir}"
chmod 777 ${backup_dir}
}

######################################################### START OF SCRIPT ######################################################

###############################################
###############################################
#
# Variable Initialization and User Input
#
###############################################
###############################################

clear

banner_message "Initializing Variables"

ssh_ops="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o TCPKeepAlive=yes -o ServerAliveInterval=50 -q"
node_check
get_input

ssh_ops="-o TCPKeepAlive=yes -o ServerAliveInterval=50 -q"
SSH="ssh -o TCPKeepAlive=yes -o ServerAliveInterval=50 -qtt -T"

db_sid="${db_name}"
dg_sid="${db_name}"


db_psid="${db_sid}"
dg_psid="${dg_sid}"

if ${prac} ; then
  if ${rac_one}; then
    db_psid="${db_psid}_1"
  else
    db_psid="${db_psid}1"
  fi

fi

if ${srac} ; then
  if ${rac_one}; then
    dg_psid="${dg_psid}_1"
  else
    dg_psid="${dg_psid}1"
  fi
fi

export ORACLE_SID=${db_psid}
export ORACLE_HOME=${DB_HOME}

if [[ ${db_version} -ge 12 ]];then

cdb=(`${DB_HOME}/bin/sqlplus -s / as sysdba <<-EOF
  set heading off
  set pages 0
  set feedb off
  set veri off
  set echo off
  select count(*)
  from cdb_pdbs;
  exit
EOF`)

else

cdb=0

fi


if [[ ${cdb} -gt 0 ]]; then

pdbs=($(${DB_HOME}/bin/sqlplus -s / as sysdba << EOF
    set heading off pages 0 feedback off
    set lines 200
    SET SERVEROUT ON SIZE 100000
    select pdb_name from cdb_pdbs where pdb_name not like 'PDB\$SEED';
EOF
  ))

else

pdbs=()

fi

ic_domain="$(${DB_HOME}/bin/srvctl config database -d ${primary_db_unq} |grep Services:|awk '{print $2}' |awk -F',' '{for(i=1;i<=NF;i++){if ($i ~ /icprod|icstage/){print $i}}}'|head -n 1| cut -d '.' -f2-10)"

if ${standby_rebuild}; then
  get_lag
fi

##################################
#
# Enable User Equivalence Daemon
#
##################################


user_eq_file=${backup_dir}/ssh_dg_gmarker.json
echo "{ \"version\" : \"DG Build In Progress\" }" > ${user_eq_file}

ssh ${ssh_ops} ${standby_nodes_wd[0]} mkdir -p ${backup_dir}
scp -q ${user_eq_file} ${standby_nodes_wd[0]}:${user_eq_file}

for n in ${all_nodes[@]};do
  check_ssh ${n} ${user_eq_file} &
done

##################################
#
# known_hosts sharing
#
##################################

banner_message "Share known_hosts file."
for i in ${standby_nodes_wd[@]};do
  /usr/bin/ssh-keyscan -H ${i} >> /home/oracle/.ssh/known_hosts
done


  for i in ${primary_nodes_wd[@]};do
    scp -q /home/oracle/.ssh/known_hosts oracle@${i}:/home/oracle/.ssh/known_hosts
  done
  for j in ${standby_nodes_wd[@]};do
    scp -q /home/oracle/.ssh/known_hosts oracle@${j}:/home/oracle/.ssh/known_hosts
  done

##################################
#
# Drop Standby Database
#
##################################

if ${standby_rebuild}; then

  banner_message "Dropping Standby Database ${standby_db_unq} for Standby Rebuild"

  export ORACLE_SID=${db_psid}
  export ORACLE_HOME=${DB_HOME}
${DB_HOME}/bin/dgmgrl / <<-EOF
  disable configuration;
  remove configuration
  exit
EOF


${DB_HOME}/bin/sqlplus -s / as sysdba <<-EOF
  ALTER SYSTEM SET DG_BROKER_START=FALSE scope=both sid='*';
  exit
EOF

drop_stby_results=($(${DB_HOME}/bin/sqlplus -s  / as sysdba << EOF
    set heading off pages 0 feedback off
    set lines 200
    SET SERVEROUT ON SIZE 100000
    select 'alter database drop standby logfile group ' || group# || ';\n' from v\$standby_log;
EOF
))

    drop_redotxt="`echo -e "${drop_stby_results[@]}"`"
    drop_redotxt="${drop_redotxt}\nexit"
    echo -e "${drop_redotxt}" > ${backup_dir}/drop_redo_gen.sql

  ${DB_HOME}/bin/sqlplus -s / as sysdba @${backup_dir}/drop_redo_gen.sql


  if [[ ${env_type} -eq 3 ]]; then
ssh ${ssh_ops} oracle@${shn} <<-EOF
  export sGRID_HOME=$(cat /etc/oratab | grep ASM| grep -vE '^\#|^\*|^$'|awk -F: '{print $2}')
  ${DB_HOME}/bin/srvctl stop database -d ${standby_db_unq} -f
  ${DB_HOME}/bin/srvctl remove database -d ${standby_db_unq} -f
  sudo ${sGRID_HOME}/bin/asmcmd rm -rf '+DATA/${standby_db_unq}'
  sudo ${sGRID_HOME}/bin/asmcmd rm -rf '+RECO/${standby_db_unq}'
EOF
  else
ssh ${ssh_ops} oracle@${shn} <<-EOF
  export sGRID_HOME=$(cat /etc/oratab | grep ASM| grep -vE '^\#|^\*|^$'|awk -F: '{print $2}')
  ${DB_HOME}/bin/srvctl stop database -d ${standby_db_unq} -f
  ${DB_HOME}/bin/srvctl remove database -d ${standby_db_unq} -f
  ${sGRID_HOME}/bin/asmcmd rm -rf '+DATA/${standby_db_unq}'
  rm -rf /u03/archive/current/${dg_sid}/*
  rm -rf /u03/oradata/flash_recovery_area/${dg_sid}/*
EOF
  fi

  if [[ $? -eq 0 ]];then
    echo -e "\E[0;32mDropping of Standby Database ${standby_db_unq} has been completed.\E[0;39m\n"
  else
    echo -e "\E[0;32mDropping of Standby Database ${standby_db_unq} was unsuccessful. Clean up the Standby DB manually. \E[0;39m\n"
  fi

elif ${dummy_drop}; then

  banner_message "Dropping Dummy DR Database ${standby_db_unq} for Standby Rebuild"

  export ORACLE_SID=${db_psid}
  export ORACLE_HOME=${DB_HOME}

drop_stby_results=($(${DB_HOME}/bin/sqlplus -s  / as sysdba << EOF
    set heading off pages 0 feedback off
    set lines 200
    SET SERVEROUT ON SIZE 100000
    select 'alter database drop standby logfile group ' || group# || ';\n' from v\$standby_log;
EOF
)
)

  drop_redotxt="`echo -e "${drop_stby_results[@]}"`"
  drop_redotxt="${drop_redotxt}\nexit"
  echo -e "${drop_redotxt}" > ${backup_dir}/drop_redo_gen.sql

  ${DB_HOME}/bin/sqlplus -s / as sysdba @${backup_dir}/drop_redo_gen.sql

ssh ${ssh_ops} oracle@${shn} <<-EOF
  export sGRID_HOME=$(cat /etc/oratab | grep ASM| grep -vE '^\#|^\*|^$'|awk -F: '{print $2}')
  ${DB_HOME}/bin/srvctl stop database -d ${standby_db_unq} -f
  ${DB_HOME}/bin/srvctl remove database -d ${standby_db_unq} -f
  sudo ${sGRID_HOME}/bin/asmcmd rm -rf '+DATA/${standby_db_unq}'
  sudo ${sGRID_HOME}/bin/asmcmd rm -rf '+RECO/${standby_db_unq}'
EOF

fi

###############################################
###############################################
#
# Editing TNSNAMES.ora files on all nodes
# GBUCS 2.0 does not like server names even fqdn.
# DG broker on GBUCS 2.0 only works on IP addresses
# to prevent error on Active Duplicate MOS 246126.1
#
###############################################
###############################################

banner_message "Editing TNSNAMES files on each node"


db_domain=$(${DB_HOME}/bin/sqlplus -s  / as sysdba << EOF
    set heading off pages 0 feedback off
    set lines 200
    SET SERVEROUT ON SIZE 100000
    select value from v\$parameter where name like 'db_domain';
EOF
)

current_host=${phns}

if [[ ${env_type} -eq 3 ]]; then
  primary_tns="\n${primary_db_unq} =\n   (DESCRIPTION =\n     (ADDRESS_LIST =\n"
else
  primary_tns="\n${primary_db_unq} =\n   (DESCRIPTION =\n     (ENABLE=BROKEN)\n     (ADDRESS_LIST =\n"
fi

if [[ ${primary_domain} == ${standby_domain} ]] && [[ ${env_type} -ne 3 ]]; then
  primary_tns="${primary_tns}     (ADDRESS = (PROTOCOL = TCP)(HOST = ${primary_nodes[0]})(PORT = 1521))\n"
  for pdb in ${pdbs[@]}; do
    primary_pdbs="${primary_pdbs}\n${pdb,,} =\n   (DESCRIPTION =\n     (ADDRESS_LIST =\n       (ADDRESS = (PROTOCOL = TCP)(HOST = ${primary_cluster})(PORT = 1521))\n"
    if [[ -z ${db_domain} ]] ; then
      primary_pdbs="${primary_pdbs}       (LOAD_BALANCE = yes)\n     )\n     (CONNECT_DATA =\n       (UR=A)\n       (SERVER = DEDICATED)\n       (SERVICE_NAME = ${pdb,,})\n     )\n   )\n"
    else
      primary_pdbs="${primary_pdbs}       (LOAD_BALANCE = yes)\n     )\n     (CONNECT_DATA =\n       (UR=A)\n       (SERVER = DEDICATED)\n       (SERVICE_NAME = ${pdb,,}.${primary_domain})\n     )\n   )\n"
    fi
  done
else
  if [[ ${env_type} -eq 3 ]]; then
    primary_tns="${primary_tns}       (ADDRESS = (PROTOCOL = TCP)(HOST = ${primary_nodes_wd[0]})(PORT = 1521))\n"
    for pdb in ${pdbs[@]}; do
      primary_pdbs="${primary_pdbs}\n${pdb,,} =\n   (DESCRIPTION =\n     (ADDRESS_LIST =\n       (ADDRESS = (PROTOCOL = TCP)(HOST = ${primary_cluster})(PORT = 1521))\n"
      if [[ -z ${ic_domain} ]] ; then
        primary_pdbs="${primary_pdbs}       (LOAD_BALANCE = yes)\n     )\n     (CONNECT_DATA =\n       (UR=A)\n       (SERVER = DEDICATED)\n       (SERVICE_NAME = ${pdb,,})\n     )\n   )\n"
      else
        primary_pdbs="${primary_pdbs}       (LOAD_BALANCE = yes)\n     )\n     (CONNECT_DATA =\n       (UR=A)\n       (SERVER = DEDICATED)\n       (SERVICE_NAME = ${pdb,,}.${ic_domain})\n     )\n   )\n"
      fi
    done
  else
    primary_tns="${primary_tns}       (ADDRESS = (PROTOCOL = TCP)(HOST = ${primary_vips[0]})(PORT = 1521))\n"
    for pdb in ${pdbs[@]}; do
      primary_pdbs="${primary_pdbs}\n${pdb,,} =\n   (DESCRIPTION =\n     (ADDRESS_LIST =\n       (ADDRESS = (PROTOCOL = TCP)(HOST = ${primary_cluster})(PORT = 1521))\n"
      if [[ -z ${db_domain} ]] ; then
        primary_pdbs="${primary_pdbs}       (LOAD_BALANCE = yes)\n     )\n     (CONNECT_DATA =\n       (UR=A)\n       (SERVER = DEDICATED)\n       (SERVICE_NAME = ${pdb,,})\n     )\n   )\n"
      else
        primary_pdbs="${primary_pdbs}       (LOAD_BALANCE = yes)\n     )\n     (CONNECT_DATA =\n       (UR=A)\n       (SERVER = DEDICATED)\n       (SERVICE_NAME = ${pdb,,}.${primary_domain})\n     )\n   )\n"
      fi
    done
  fi
fi

if [[ -z ${db_domain} ]] ; then
  primary_tns="${primary_tns}       (LOAD_BALANCE = yes)\n     )\n     (CONNECT_DATA =\n       (UR=A)\n       (SERVER = DEDICATED)\n       (SERVICE_NAME = ${primary_db_unq})\n     )\n   )\n"
else
  primary_tns="${primary_tns}       (LOAD_BALANCE = yes)\n     )\n     (CONNECT_DATA =\n       (UR=A)\n       (SERVER = DEDICATED)\n       (SERVICE_NAME = ${primary_db_unq}.${primary_domain})\n     )\n   )\n"
fi

if [[ ${env_type} -eq 3 ]]; then
  standby_tns="\n${standby_db_unq} =\n   (DESCRIPTION =\n     (ADDRESS_LIST =\n"
else
  standby_tns="\n${standby_db_unq} =\n   (DESCRIPTION =\n     (ENABLE=BROKEN)\n     (ADDRESS_LIST =\n"
fi

if [[ ${primary_domain} == ${standby_domain} ]] && [[ ${env_type} -ne 3 ]]; then
  standby_tns="${standby_tns}     (ADDRESS = (PROTOCOL = TCP)(HOST = ${standby_nodes[0]})(PORT = 1521))\n"
  for pdb in ${pdbs[@]}; do
    standby_pdbs="${standby_pdbs}\n${pdb,,} =\n   (DESCRIPTION =\n     (ADDRESS_LIST =\n       (ADDRESS = (PROTOCOL = TCP)(HOST = ${standby_cluster})(PORT = 1521))\n"
    if [[ -z ${db_domain} ]] ; then
      standby_pdbs="${standby_pdbs}       (LOAD_BALANCE = yes)\n     )\n     (CONNECT_DATA =\n       (UR=A)\n       (SERVER = DEDICATED)\n       (SERVICE_NAME = ${pdb,,})\n     )\n   )\n"
    else
      standby_pdbs="${standby_pdbs}       (LOAD_BALANCE = yes)\n     )\n     (CONNECT_DATA =\n       (UR=A)\n       (SERVER = DEDICATED)\n       (SERVICE_NAME = ${pdb,,}.${standby_domain})\n     )\n   )\n"
    fi
  done
else
  if [[ ${env_type} -eq 3 ]]; then
    standby_tns="${standby_tns}       (ADDRESS = (PROTOCOL = TCP)(HOST = ${standby_nodes_wd[0]})(PORT = 1521))\n"
    for pdb in ${pdbs[@]}; do
      standby_pdbs="${standby_pdbs}\n${pdb,,} =\n   (DESCRIPTION =\n     (ADDRESS_LIST =\n       (ADDRESS = (PROTOCOL = TCP)(HOST = ${standby_cluster})(PORT = 1521))\n"
      if [[ -z ${ic_domain} ]] ; then
        standby_pdbs="${standby_pdbs}       (LOAD_BALANCE = yes)\n     )\n     (CONNECT_DATA =\n       (UR=A)\n       (SERVER = DEDICATED)\n       (SERVICE_NAME = ${pdb,,})\n     )\n   )\n"
      else
        standby_pdbs="${standby_pdbs}       (LOAD_BALANCE = yes)\n     )\n     (CONNECT_DATA =\n       (UR=A)\n       (SERVER = DEDICATED)\n       (SERVICE_NAME = ${pdb,,}.${ic_domain})\n     )\n   )\n"
      fi
    done
  else
    standby_tns="${standby_tns}       (ADDRESS = (PROTOCOL = TCP)(HOST = ${standby_vips[0]})(PORT = 1521))\n"
    for pdb in ${pdbs[@]}; do
      standby_pdbs="${standby_pdbs}\n${pdb,,} =\n   (DESCRIPTION =\n     (ADDRESS_LIST =\n       (ADDRESS = (PROTOCOL = TCP)(HOST = ${standby_cluster})(PORT = 1521))\n"
      if [[ -z ${db_domain} ]] ; then
        standby_pdbs="${standby_pdbs}       (LOAD_BALANCE = yes)\n     )\n     (CONNECT_DATA =\n       (UR=A)\n       (SERVER = DEDICATED)\n       (SERVICE_NAME = ${pdb,,})\n     )\n   )\n"
      else
        standby_pdbs="${standby_pdbs}       (LOAD_BALANCE = yes)\n     )\n     (CONNECT_DATA =\n       (UR=A)\n       (SERVER = DEDICATED)\n       (SERVICE_NAME = ${pdb,,}.${standby_domain})\n     )\n   )\n"
      fi
    done
  fi
fi

if [[ -z ${db_domain} ]] ; then
  standby_tns="${standby_tns}       (LOAD_BALANCE = yes)\n     )\n     (CONNECT_DATA =\n       (UR=A)\n       (SERVER = DEDICATED)\n       (SERVICE_NAME = ${standby_db_unq})\n     )\n   )\n\n"
else
  standby_tns="${standby_tns}       (LOAD_BALANCE = yes)\n     )\n     (CONNECT_DATA =\n       (UR=A)\n       (SERVER = DEDICATED)\n       (SERVICE_NAME = ${standby_db_unq}.${standby_domain})\n     )\n   )\n\n"
fi

cp "${DB_HOME}/network/admin/tnsnames.ora" "${DB_HOME}/network/admin/tnsnames.ora.bak"

if [[ -f "${DB_HOME}/network/admin/tnsnames.ora" ]]; then
  cp "${DB_HOME}/network/admin/tnsnames.ora" ${backup_dir}/tnsnames.ora
else
  touch ${backup_dir}/tnsnames.ora
fi

####### Delete Primary and Standby TNS Alias
entry_list[0]=${primary_db_unq}
entry_list[1]=${standby_db_unq}
entry_list[2]="`echo ${primary_db_unq} | tr '[:lower:]' '[:upper:]'`"
entry_list[3]="`echo ${standby_db_unq} | tr '[:lower:]' '[:upper:]'`"

y=4
for ((z=0;z<${#pdbs[@]};z++)); do
  entry_list[((${z}+${y}))]=${pdbs[${z}]}
  ((y++))
  entry_list[((${z}+${y}))]="`echo ${pdbs[${z}]} | tr '[:upper:]' '[:lower:]'`"
done

temp_list=()

for  ((x=0;x<${#entry_list[@]};x++)); do
  temp_list=$(find_tns_line_number `echo ${entry_list[${x}]}`)
  while [[ ! -z ${temp_list[0]} ]]; do
    delete_tns_entry ${temp_list[0]}
    temp_list=$(find_tns_line_number `echo ${entry_list[${x}]}`)
  done
done
######

modify_tns

cp ${backup_dir}/tnsnames.ora "${DB_HOME}/network/admin/tnsnames.ora"
rm -f ${backup_dir}/tnsnames.ora

counter=0
for i in ${other_nodes[@]}; do
  current_host=$(echo ${i} | cut -d '.' -f1)
  scp -q "${other_nodes[${counter}]}:${DB_HOME}/network/admin/tnsnames.ora" ${backup_dir}/tnsnames.ora

  if [[ ! -f ${backup_dir}/tnsnames.ora ]]; then
    touch ${backup_dir}/tnsnames.ora
  fi

  temp_list=()

  for  ((x=0;x<${#entry_list[@]};x++)); do
    temp_list=$(find_tns_line_number `echo ${entry_list[${x}]}`)
    while [[ ! -z ${temp_list[0]} ]]; do
      delete_tns_entry ${temp_list[0]}
      temp_list=$(find_tns_line_number `echo ${entry_list[${x}]}`)
    done
  done


  modify_tns


  scp -q ${backup_dir}/tnsnames.ora "${other_nodes[${counter}]}:${DB_HOME}/network/admin/tnsnames.ora"

  rm -f ${backup_dir}/tnsnames.ora
  ((counter++))
done

###############################################
###############################################
#
#  Listener.ora Modification
#
###############################################
###############################################

banner_message "Editing listener files on each node"
pri_listener_confirm=()
sby_listener_confirm=()
pri_listener_entry=()
sby_listener_entry=()
current_host=${phns}

counter=0
for i in ${primary_nodes_wd[@]}; do
  pri_listener_confirm[${counter}]=-1
  ((counter++))
done

counter=0
for i in ${standby_nodes_wd[@]}; do
  sby_listener_confirm[${counter}]=-1
  ((counter++))
done

counter=1
listener_start="SID_LIST_LISTENER=\n  (SID_LIST="
listener_entry=""
listener_end="  )"

db_domain=$(${DB_HOME}/bin/sqlplus -s  / as sysdba << EOF
    set heading off pages 0 feedback off
    set lines 200
    SET SERVEROUT ON SIZE 100000
    select value from v\$parameter where name like 'db_domain';
EOF
)


if [[ -z ${db_domain} ]] ; then

  if ${prac} ; then
    for i in ${primary_nodes_wd[@]}; do
      if ${rac_one}; then
        pri_listener_entry[$((${counter}-1))]="\n    (SID_DESC=\n      (GLOBAL_DBNAME=${primary_db_unq})\n      (ORACLE_HOME=${DB_HOME})\n      (SID_NAME=${db_sid}_${counter})\n    )\n    (SID_DESC=\n      (GLOBAL_DBNAME=${primary_db_unq}_DGMGRL)\n      (ORACLE_HOME=${DB_HOME})\n      (SID_NAME=${db_sid}_${counter})\n    )\n    (SID_DESC=\n      (GLOBAL_DBNAME=${primary_db_unq}_DGB)\n      (ORACLE_HOME=${DB_HOME})\n      (SID_NAME=${db_sid}_${counter})\n    )"
      else
        pri_listener_entry[$((${counter}-1))]="\n    (SID_DESC=\n      (GLOBAL_DBNAME=${primary_db_unq})\n      (ORACLE_HOME=${DB_HOME})\n      (SID_NAME=${db_sid}${counter})\n    )\n    (SID_DESC=\n      (GLOBAL_DBNAME=${primary_db_unq}_DGMGRL)\n      (ORACLE_HOME=${DB_HOME})\n      (SID_NAME=${db_sid}${counter})\n    )\n    (SID_DESC=\n      (GLOBAL_DBNAME=${primary_db_unq}_DGB)\n      (ORACLE_HOME=${DB_HOME})\n      (SID_NAME=${db_sid}${counter})\n    )"
      fi
      ((counter++))
    done
  else
    pri_listener_entry[$((${counter}-1))]="\n    (SID_DESC=\n      (GLOBAL_DBNAME=${primary_db_unq})\n      (ORACLE_HOME=${DB_HOME})\n      (SID_NAME=${db_sid})\n    )\n    (SID_DESC=\n      (GLOBAL_DBNAME=${primary_db_unq}_DGMGRL)\n      (ORACLE_HOME=${DB_HOME})\n      (SID_NAME=${db_sid})\n    )\n    (SID_DESC=\n      (GLOBAL_DBNAME=${primary_db_unq}_DGB)\n      (ORACLE_HOME=${DB_HOME})\n      (SID_NAME=${db_sid})\n    )"
  fi

  counter=1
  if ${srac} ; then
    for i in ${standby_nodes_wd[@]}; do
      if ${rac_one}; then
        sby_listener_entry[$((${counter}-1))]="\n    (SID_DESC=\n      (GLOBAL_DBNAME=${standby_db_unq})\n      (ORACLE_HOME=${DB_HOME})\n      (SID_NAME=${dg_sid}_${counter})\n    )\n    (SID_DESC=\n      (GLOBAL_DBNAME=${standby_db_unq}_DGMGRL)\n      (ORACLE_HOME=${DB_HOME})\n      (SID_NAME=${dg_sid}_${counter})\n    )\n    (SID_DESC=\n      (GLOBAL_DBNAME=${standby_db_unq}_DGB)\n      (ORACLE_HOME=${DB_HOME})\n      (SID_NAME=${dg_sid}_${counter})\n    )"
      else
        sby_listener_entry[$((${counter}-1))]="\n    (SID_DESC=\n      (GLOBAL_DBNAME=${standby_db_unq})\n      (ORACLE_HOME=${DB_HOME})\n      (SID_NAME=${dg_sid}${counter})\n    )\n    (SID_DESC=\n      (GLOBAL_DBNAME=${standby_db_unq}_DGMGRL)\n      (ORACLE_HOME=${DB_HOME})\n      (SID_NAME=${dg_sid}${counter})\n    )\n    (SID_DESC=\n      (GLOBAL_DBNAME=${standby_db_unq}_DGB)\n      (ORACLE_HOME=${DB_HOME})\n      (SID_NAME=${dg_sid}${counter})\n    )"
      fi
      ((counter++))
    done
  else
    sby_listener_entry[$((${counter}-1))]="\n    (SID_DESC=\n      (GLOBAL_DBNAME=${standby_db_unq})\n      (ORACLE_HOME=${DB_HOME})\n      (SID_NAME=${dg_sid})\n    )\n    (SID_DESC=\n      (GLOBAL_DBNAME=${standby_db_unq}_DGMGRL)\n      (ORACLE_HOME=${DB_HOME})\n      (SID_NAME=${dg_sid})\n    )\n    (SID_DESC=\n      (GLOBAL_DBNAME=${standby_db_unq}_DGB)\n      (ORACLE_HOME=${DB_HOME})\n      (SID_NAME=${dg_sid})\n    )"
  fi

else

  if ${prac} ; then
    for i in ${primary_nodes_wd[@]}; do
      if ${rac_one}; then
        if [[ ${env_type} -eq 3 ]]; then
          pri_listener_entry[$((${counter}-1))]="\n    (SID_DESC=\n      (SDU=65535)\n      (GLOBAL_DBNAME=${primary_db_unq}.${primary_domain})\n      (ORACLE_HOME=${DB_HOME})\n      (SID_NAME=${db_sid}_${counter})\n      (ENVS=\"TNS_ADMIN=${DB_HOME}/network/admin,ORACLE_UNQNAME=${primary_db_unq}\")\n    )\n    (SID_DESC=\n      (SDU=65535)\n      (GLOBAL_DBNAME=${primary_db_unq}_DGMGRL.${primary_domain})\n      (ORACLE_HOME=${DB_HOME})\n      (SID_NAME=${db_sid}_${counter})\n      (ENVS=\"TNS_ADMIN=${DB_HOME}/network/admin,ORACLE_UNQNAME=${primary_db_unq}\")\n    )\n    (SID_DESC=\n      (SDU=65535)\n      (GLOBAL_DBNAME=${primary_db_unq}_DGB.${primary_domain})\n      (ORACLE_HOME=${DB_HOME})\n      (SID_NAME=${db_sid}_${counter})\n      (ENVS=\"TNS_ADMIN=${DB_HOME}/network/admin,ORACLE_UNQNAME=${primary_db_unq}\")\n    )"
        else
          pri_listener_entry[$((${counter}-1))]="\n    (SID_DESC=\n      (GLOBAL_DBNAME=${primary_db_unq}.${primary_domain})\n      (ORACLE_HOME=${DB_HOME})\n      (SID_NAME=${db_sid}_${counter})\n    )\n    (SID_DESC=\n      (GLOBAL_DBNAME=${primary_db_unq}_DGMGRL.${primary_domain})\n      (ORACLE_HOME=${DB_HOME})\n      (SID_NAME=${db_sid}_${counter})\n    )\n    (SID_DESC=\n      (GLOBAL_DBNAME=${primary_db_unq}_DGB.${primary_domain})\n      (ORACLE_HOME=${DB_HOME})\n      (SID_NAME=${db_sid}_${counter})\n    )"
        fi
      else
        if [[ ${env_type} -eq 3 ]]; then
          pri_listener_entry[$((${counter}-1))]="\n    (SID_DESC=\n      (SDU=65535)\n      (GLOBAL_DBNAME=${primary_db_unq}.${primary_domain})\n      (ORACLE_HOME=${DB_HOME})\n      (SID_NAME=${db_sid}${counter})\n      (ENVS=\"TNS_ADMIN=${DB_HOME}/network/admin,ORACLE_UNQNAME=${primary_db_unq}\")\n    )\n    (SID_DESC=\n      (SDU=65535)\n      (GLOBAL_DBNAME=${primary_db_unq}_DGMGRL.${primary_domain})\n      (ORACLE_HOME=${DB_HOME})\n      (SID_NAME=${db_sid}${counter})\n      (ENVS=\"TNS_ADMIN=${DB_HOME}/network/admin,ORACLE_UNQNAME=${primary_db_unq}\")\n    )\n    (SID_DESC=\n      (SDU=65535)\n      (GLOBAL_DBNAME=${primary_db_unq}_DGB.${primary_domain})\n      (ORACLE_HOME=${DB_HOME})\n      (SID_NAME=${db_sid}${counter})\n      (ENVS=\"TNS_ADMIN=${DB_HOME}/network/admin,ORACLE_UNQNAME=${primary_db_unq}\")\n    )"
        else
          pri_listener_entry[$((${counter}-1))]="\n    (SID_DESC=\n      (GLOBAL_DBNAME=${primary_db_unq}.${primary_domain})\n      (ORACLE_HOME=${DB_HOME})\n      (SID_NAME=${db_sid}${counter})\n    )\n    (SID_DESC=\n      (GLOBAL_DBNAME=${primary_db_unq}_DGMGRL.${primary_domain})\n      (ORACLE_HOME=${DB_HOME})\n      (SID_NAME=${db_sid}${counter})\n    )\n    (SID_DESC=\n      (GLOBAL_DBNAME=${primary_db_unq}_DGB.${primary_domain})\n      (ORACLE_HOME=${DB_HOME})\n      (SID_NAME=${db_sid}${counter})\n    )"
        fi
      fi
      ((counter++))
    done
  else
    if [[ ${env_type} -eq 3 ]]; then
      pri_listener_entry[$((${counter}-1))]="\n    (SID_DESC=\n      (SDU=65535)\n      (GLOBAL_DBNAME=${primary_db_unq}.${primary_domain})\n      (ORACLE_HOME=${DB_HOME})\n      (SID_NAME=${db_sid})\n      (ENVS=\"TNS_ADMIN=${DB_HOME}/network/admin,ORACLE_UNQNAME=${primary_db_unq}\")\n    )\n    (SID_DESC=\n      (SDU=65535)\n      (GLOBAL_DBNAME=${primary_db_unq}_DGMGRL.${primary_domain})\n      (ORACLE_HOME=${DB_HOME})\n      (SID_NAME=${db_sid})\n      (ENVS=\"TNS_ADMIN=${DB_HOME}/network/admin,ORACLE_UNQNAME=${primary_db_unq}\")\n    )\n    (SID_DESC=\n      (SDU=65535)\n      (GLOBAL_DBNAME=${primary_db_unq}_DGB.${primary_domain})\n      (ORACLE_HOME=${DB_HOME})\n      (SID_NAME=${db_sid})\n      (ENVS=\"TNS_ADMIN=${DB_HOME}/network/admin,ORACLE_UNQNAME=${primary_db_unq}\")\n    )"
    else
      pri_listener_entry[$((${counter}-1))]="\n    (SID_DESC=\n      (GLOBAL_DBNAME=${primary_db_unq}.${primary_domain})\n      (ORACLE_HOME=${DB_HOME})\n      (SID_NAME=${db_sid})\n    )\n    (SID_DESC=\n      (GLOBAL_DBNAME=${primary_db_unq}_DGMGRL.${primary_domain})\n      (ORACLE_HOME=${DB_HOME})\n      (SID_NAME=${db_sid})\n    )\n    (SID_DESC=\n      (GLOBAL_DBNAME=${primary_db_unq}_DGB.${primary_domain})\n      (ORACLE_HOME=${DB_HOME})\n      (SID_NAME=${db_sid})\n    )"
    fi
  fi

  counter=1
  if ${srac} ; then
    for i in ${standby_nodes_wd[@]}; do
      if ${rac_one}; then
        if [[ ${env_type} -eq 3 ]]; then
          sby_listener_entry[$((${counter}-1))]="\n    (SID_DESC=\n      (SDU=65535)\n      (GLOBAL_DBNAME=${standby_db_unq}.${standby_domain})\n      (ORACLE_HOME=${DB_HOME})\n      (SID_NAME=${dg_sid}_${counter})\n      (ENVS=\"TNS_ADMIN=${DB_HOME}/network/admin,ORACLE_UNQNAME=${standby_db_unq}\")\n    )\n    (SID_DESC=\n      (SDU=65535)\n      (GLOBAL_DBNAME=${standby_db_unq}_DGMGRL.${standby_domain})\n      (ORACLE_HOME=${DB_HOME})\n      (SID_NAME=${dg_sid}_${counter})\n      (ENVS=\"TNS_ADMIN=${DB_HOME}/network/admin,ORACLE_UNQNAME=${standby_db_unq}\")\n    )\n    (SID_DESC=\n      (SDU=65535)\n      (GLOBAL_DBNAME=${standby_db_unq}_DGB.${standby_domain})\n      (ORACLE_HOME=${DB_HOME})\n      (SID_NAME=${dg_sid}_${counter})\n      (ENVS=\"TNS_ADMIN=${DB_HOME}/network/admin,ORACLE_UNQNAME=${standby_db_unq}\")\n    )"
        else
          sby_listener_entry[$((${counter}-1))]="\n    (SID_DESC=\n      (GLOBAL_DBNAME=${standby_db_unq}.${standby_domain})\n      (ORACLE_HOME=${DB_HOME})\n      (SID_NAME=${dg_sid}_${counter})\n    )\n    (SID_DESC=\n      (GLOBAL_DBNAME=${standby_db_unq}_DGMGRL.${standby_domain})\n      (ORACLE_HOME=${DB_HOME})\n      (SID_NAME=${dg_sid}_${counter})\n    )\n    (SID_DESC=\n      (GLOBAL_DBNAME=${standby_db_unq}_DGB.${standby_domain})\n      (ORACLE_HOME=${DB_HOME})\n      (SID_NAME=${dg_sid}_${counter})\n    )"
        fi
      else
        if [[ ${env_type} -eq 3 ]]; then
          sby_listener_entry[$((${counter}-1))]="\n    (SID_DESC=\n      (SDU=65535)\n      (GLOBAL_DBNAME=${standby_db_unq}.${standby_domain})\n      (ORACLE_HOME=${DB_HOME})\n      (SID_NAME=${dg_sid}${counter})\n      (ENVS=\"TNS_ADMIN=${DB_HOME}/network/admin,ORACLE_UNQNAME=${standby_db_unq}\")\n    )\n    (SID_DESC=\n      (SDU=65535)\n      (GLOBAL_DBNAME=${standby_db_unq}_DGMGRL.${standby_domain})\n      (ORACLE_HOME=${DB_HOME})\n      (SID_NAME=${dg_sid}${counter})\n      (ENVS=\"TNS_ADMIN=${DB_HOME}/network/admin,ORACLE_UNQNAME=${standby_db_unq}\")\n    )\n    (SID_DESC=\n      (SDU=65535)\n      (GLOBAL_DBNAME=${standby_db_unq}_DGB.${standby_domain})\n      (ORACLE_HOME=${DB_HOME})\n      (SID_NAME=${dg_sid}${counter})\n      (ENVS=\"TNS_ADMIN=${DB_HOME}/network/admin,ORACLE_UNQNAME=${standby_db_unq}\")\n    )"
        else
          sby_listener_entry[$((${counter}-1))]="\n    (SID_DESC=\n      (GLOBAL_DBNAME=${standby_db_unq}.${standby_domain})\n      (ORACLE_HOME=${DB_HOME})\n      (SID_NAME=${dg_sid}${counter})\n    )\n    (SID_DESC=\n      (GLOBAL_DBNAME=${standby_db_unq}_DGMGRL.${standby_domain})\n      (ORACLE_HOME=${DB_HOME})\n      (SID_NAME=${dg_sid}${counter})\n    )\n    (SID_DESC=\n      (GLOBAL_DBNAME=${standby_db_unq}_DGB.${standby_domain})\n      (ORACLE_HOME=${DB_HOME})\n      (SID_NAME=${dg_sid}${counter})\n    )"
        fi
      fi

      ((counter++))
    done
  else
    if [[ ${env_type} -eq 3 ]]; then
      sby_listener_entry[$((${counter}-1))]="\n    (SID_DESC=\n      (SDU=65535)\n      (GLOBAL_DBNAME=${standby_db_unq}.${standby_domain})\n      (ORACLE_HOME=${DB_HOME})\n      (SID_NAME=${dg_sid})\n      (ENVS=\"TNS_ADMIN=${DB_HOME}/network/admin,ORACLE_UNQNAME=${standby_db_unq}\")\n    )\n    (SID_DESC=\n      (SDU=65535)\n      (GLOBAL_DBNAME=${standby_db_unq}_DGMGRL.${standby_domain})\n      (ORACLE_HOME=${DB_HOME})\n      (SID_NAME=${dg_sid})\n      (ENVS=\"TNS_ADMIN=${DB_HOME}/network/admin,ORACLE_UNQNAME=${standby_db_unq}\")\n    )\n    (SID_DESC=\n      (SDU=65535)\n      (GLOBAL_DBNAME=${standby_db_unq}_DGB.${standby_domain})\n      (ORACLE_HOME=${DB_HOME})\n      (SID_NAME=${dg_sid})\n      (ENVS=\"TNS_ADMIN=${DB_HOME}/network/admin,ORACLE_UNQNAME=${standby_db_unq}\")\n    )"
    else
      sby_listener_entry[$((${counter}-1))]="\n    (SID_DESC=\n      (GLOBAL_DBNAME=${standby_db_unq}.${standby_domain})\n      (ORACLE_HOME=${DB_HOME})\n      (SID_NAME=${dg_sid})\n    )\n    (SID_DESC=\n      (GLOBAL_DBNAME=${standby_db_unq}_DGMGRL.${standby_domain})\n      (ORACLE_HOME=${DB_HOME})\n      (SID_NAME=${dg_sid})\n    )\n    (SID_DESC=\n      (GLOBAL_DBNAME=${standby_db_unq}_DGB.${standby_domain})\n      (ORACLE_HOME=${DB_HOME})\n      (SID_NAME=${dg_sid})\n    )"
    fi
  fi
fi

if [[ ${env_type} -eq 3 ]]; then
  sudo cp "${pGRID_HOME}/network/admin/listener.ora" ${backup_dir}/listener.ora
  if [[ $? -ne 0 ]]; then
  echo -e "\n\E[0;31mThere is something wrong with the listener. Fix it then rerun the script.\n\E[0;39m"
  exit 1
  fi
  sudo chown oracle:oinstall "${backup_dir}/listener.ora"
  modify_listener
  sudo cp -f ${backup_dir}/listener.ora "${pGRID_HOME}/network/admin/listener.ora"
  rm -f ${backup_dir}/listener.ora
  sudo chown oracle:oinstall ${pGRID_HOME}/network/admin/listener.ora
else
  cp "${pGRID_HOME}/network/admin/listener.ora" ${backup_dir}/listener.ora
  if [[ $? -ne 0 ]]; then
  	echo -e "\n\E[0;31mThere is something wrong with the listener. Fix it then rerun the script.\n\E[0;39m"
  	exit 1
  fi
  chown oracle:oinstall "${backup_dir}/listener.ora"
  modify_listener
  cp -f ${backup_dir}/listener.ora "${pGRID_HOME}/network/admin/listener.ora"
  rm -f ${backup_dir}/listener.ora
  chown oracle:oinstall ${pGRID_HOME}/network/admin/listener.ora
fi

ORACLE_HOME=${DB_HOME}
${DB_HOME}/bin/srvctl stop listener
${DB_HOME}/bin/srvctl start listener

for k in ${other_nodes[@]}; do
  current_host=$(echo ${k} | cut -d '.' -f1)
  counter=0
  for j in ${primary_nodes_wd[@]}; do
    pri_listener_confirm[${counter}]=-1
    ((counter++))
  done

  counter=0
  for j in ${standby_nodes_wd[@]}; do
    sby_listener_confirm[${counter}]=-1
    ((counter++))
  done

  listener_entry=""

  current_k=$(echo ${k} | cut -d '.' -f1)

  if [[ ${current_k::${#current_k}-1} == ${phns::${#phns}-1} ]]; then
    aGRID_HOME=${pGRID_HOME}
  elif [[ ${current_k::${#current_k}-1} == ${shns::${#shns}-1} ]]; then
    aGRID_HOME=${sGRID_HOME}
  fi

  if [[ ${env_type} -eq 3 ]]; then
ssh ${ssh_ops} oracle@${k} <<-EOF
  sudo cp -f ${aGRID_HOME}/network/admin/listener.ora /home/oracle/listener.ora
  sudo chown oracle:oinstall /home/oracle/listener.ora
  exit
EOF
  else
ssh ${ssh_ops} oracle@${k} <<-EOF
  cp -f ${aGRID_HOME}/network/admin/listener.ora /home/oracle/listener.ora
  chown oracle:oinstall /home/oracle/listener.ora
  exit
EOF
  fi

  if [[ $? -ne 0 ]]; then
    echo -e "\n\E[0;31mThere is something wrong with the listener. Fix it then rerun the script.\n\E[0;39m"
    exit 1
  fi

  scp -q "oracle@${k}:/home/oracle/listener.ora" ${backup_dir}/listener.ora

  modify_listener
  scp -q ${backup_dir}/listener.ora "oracle@${k}:/home/oracle/listener.ora"

  if [[ ${env_type} -eq 3 ]]; then
ssh ${ssh_ops} oracle@${k} <<-EOF
  sudo cp -f /home/oracle/listener.ora ${aGRID_HOME}/network/admin/listener.ora
  sudo chown oracle:oinstall ${aGRID_HOME}/network/admin/listener.ora
  rm -f /home/oracle/listener.ora
  ${DB_HOME}/bin/srvctl stop listener
  ${DB_HOME}/bin/srvctl start listener
  exit
EOF
  else
ssh ${ssh_ops} oracle@${k} <<-EOF
  chown oracle:oinstall /home/oracle/listener.ora
  cp -f /home/oracle/listener.ora ${aGRID_HOME}/network/admin/listener.ora
  rm -f /home/oracle/listener.ora
  ${DB_HOME}/bin/srvctl stop listener
  ${DB_HOME}/bin/srvctl start listener
  exit
EOF
  fi

  rm -f ${backup_dir}/listener.ora

done

###############################################
###############################################
#
# Generating Directories
#
###############################################
###############################################

banner_message "Generating local and remote directories for script file transfer and standby database file storage"

if [[ ${env_type} -eq 3 ]]; then
  export ORACLE_SID=$(cat /etc/oratab|grep ASM|grep -vE '^\#|^\*|^$'| awk -F: '{print $1}')
  export ORACLE_HOME=${pGRID_HOME}
  sudo ${pGRID_HOME}/bin/asmcmd mkdir +DATA/${primary_db_unq}/broker >/dev/null 2>&1

ssh ${ssh_ops} oracle@${standby_nodes_wd[0]} <<-EOF
  mkdir -p "${restore_dir}"
  chmod 777 ${restore_dir}
  mkdir -p /home/oracle/rman
  export ORACLE_SID=$(cat /etc/oratab|grep ASM|grep -vE '^\#|^\*|^$'| awk -F: '{print $1}')
  export ORACLE_HOME=$(cat /etc/oratab|grep ASM|grep -vE '^\#|^\*|^$'| awk -F: '{print $2}')
  sudo ${sGRID_HOME}/bin/asmcmd mkdir +DATA/${standby_db_unq} >/dev/null 2>&1
  sudo ${sGRID_HOME}/bin/asmcmd mkdir +DATA/${standby_db_unq}/CONTROLFILE >/dev/null 2>&1
  sudo ${sGRID_HOME}/bin/asmcmd mkdir +DATA/${standby_db_unq}/broker >/dev/null 2>&1
  exit
EOF

  ssh ${ssh_ops} oracle@${standby_nodes_wd} /bin/ls -ld ${wallet_dir}/${standby_db_unq} >/dev/null 2>&1
  if [[ $? -gt 0 ]]; then
ssh ${ssh_ops} oracle@${standby_nodes_wd[0]} <<-EOF
  mkdir -p ${wallet_dir}/${standby_db_unq}
  exit
EOF
  fi

else
  mkdir -p /u03/archive/current/${db_sid}
  mkdir -p /u03/oradata/flash_recovery_area/${db_sid}

ssh ${ssh_ops} oracle@${standby_nodes_wd[0]} <<-EOF
  mkdir -p "${restore_dir}"
  mkdir -p /u03/archive/current/${dg_sid}
  mkdir -p /u03/oradata/flash_recovery_area/${dg_sid}
  mkdir -p /u03/${db_name}/control/
  mkdir -p /home/oracle/rman
  export ORACLE_SID=$(cat /etc/oratab|grep ASM|grep -vE '^\#|^\*|^$'| awk -F: '{print $1}')
  export ORACLE_HOME=$(cat /etc/oratab|grep ASM|grep -vE '^\#|^\*|^$'| awk -F: '{print $2}')
  ${sGRID_HOME}/bin/asmcmd mkdir +DATA/${standby_db_unq}
  ${sGRID_HOME}/bin/asmcmd mkdir +DATA/${standby_db_unq}/CONTROLFILE
  exit
EOF


  if [[ -n ${wallet_dir} ]]; then
ssh ${ssh_ops} oracle@${standby_nodes_wd[0]} <<-EOF
  mkdir -p ${wallet_dir}
  exit
EOF
  fi
fi

###############################################
###############################################
#
# Modifying Primary Database
#
###############################################
###############################################

banner_message "Modifying primary database parameters for standby preparation"
export ORACLE_SID=${db_psid}
export ORACLE_HOME=${DB_HOME}

echo "ORACLE_SID = ${db_psid}"

if [[ ${env_type} -eq 3 ]]; then

${DB_HOME}/bin/sqlplus -s / as sysdba <<-EOF
  alter database force logging;
  alter system set fal_server='${standby_tns_alias}' sid='*' scope=both;
  alter system set log_archive_config='dg_config=(${primary_db_unq},${standby_db_unq})' sid='*' scope=both;
  alter system set log_archive_dest_1='location=USE_DB_RECOVERY_FILE_DEST valid_for=(all_logfiles,all_roles) db_unique_name=${primary_db_unq}'  sid='*' scope=both;
  alter system set log_archive_dest_state_1='enable' sid='*' scope=both;
  alter system set log_archive_dest_state_2='enable' sid='*' scope=both;
  alter system set standby_file_management='auto' sid='*' scope=both;
  alter system set log_file_name_convert='${standby_db_unq}','${primary_db_unq}' sid='*' scope=spfile;
  alter system archive log current;
  alter system archive log current;
  create pfile='${backup_dir}/standby_init.ora' from spfile;
  exit
EOF

else

${DB_HOME}/bin/sqlplus -s / as sysdba <<-EOF
  alter database force logging;
  alter system set fal_server='${standby_tns_alias}' sid='*' scope=both;
  alter system set log_archive_config='dg_config=(${primary_db_unq},${standby_db_unq})' sid='*' scope=both;
  alter system set log_archive_dest_1='location=/u03/archive/current/${db_sid} valid_for=(online_logfile,primary_role) db_unique_name=${primary_db_unq}'  sid='*' scope=both;
  alter system set log_archive_dest_2='service=${standby_tns_alias} lgwr async valid_for=(online_logfiles,primary_role) db_unique_name=${standby_db_unq}' sid='*' scope=both;
  alter system set log_archive_dest_3='location="/u03/oradata/flash_recovery_area/${db_sid}",  valid_for=(standby_logfile,standby_role)' sid='*' scope=both;
  alter system set log_archive_dest_state_1='enable' sid='*' scope=both;
  alter system set log_archive_dest_state_2='enable' sid='*' scope=both;
  alter system set log_archive_dest_state_3='enable' sid='*' scope=both;
  alter system set standby_file_management='auto' sid='*' scope=both;
  alter system set log_file_name_convert='${standby_db_unq}','${primary_db_unq}' sid='*' scope=spfile;
  alter system set "_ktb_debug_flags"=8 scope=both sid='*';
  alter system archive log current;
  alter system archive log current;
  create pfile='${backup_dir}/standby_init.ora' from spfile;
  exit
EOF

fi

echo -e "alter system set log_archive_dest_2='SERVICE=${standby_tns_alias} NOAFFIRM delay=0 async valid_for=(online_logfiles,primary_role) db_unique_name=${standby_db_unq}' scope=both sid='*';\nexit;" > ${backup_dir}/primary_logdest2.sql
echo -e "alter system set log_archive_dest_2='SERVICE=${primary_tns_alias} NOAFFIRM delay=0 async valid_for=(online_logfiles,primary_role) db_unique_name=${primary_db_unq}' scope=both sid='*';\nexit;" > ${backup_dir}/standby_logdest2.sql
echo -e "alter system set log_archive_dest_2='' scope=both sid='*';\nexit;" > ${backup_dir}/empty_logdest2.sql

###############################################
###############################################
#
# File Editing
#
###############################################
###############################################
db_upper="`echo ${db_sid} | tr '[:lower:]' '[:upper:]'`"
banner_message "Generating files/scripts necessary to build standby database"
sed -i "s/dg_config=(${primary_db_unq},${standby_db_unq})/dg_config=(${standby_db_unq},${primary_db_unq})/g" ${backup_dir}/standby_init.ora
sed -r -i -e "s/DATA\/(${db_upper}|${primary_db_unq})\/(CONTROLFILE|controlfile)\/current\.[0-9]*.[0-9]*/DATA\/${standby_db_unq}\/CONTROLFILE\/control01.ctl/" -e "s/DATA\/(${db_upper}|${primary_db_unq})\/(CONTROLFILE|controlfile)\/current\.[0-9]*.[0-9]*/DATA\/${standby_db_unq}\/CONTROLFILE\/control02.ctl/" ${backup_dir}/standby_init.ora
if [[ ${env_type} -eq 3 ]]; then
  sed -i "s/log_archive_dest_1='location=USE_DB_RECOVERY_FILE_DEST valid_for=(all_logfiles,all_roles) db_unique_name=${primary_db_unq}'/log_archive_dest_1='location=USE_DB_RECOVERY_FILE_DEST valid_for=(all_logfiles,all_roles) db_unique_name=${standby_db_unq}'/g" ${backup_dir}/standby_init.ora
else
  sed -i "s/log_archive_dest_1='location=\/u03\/archive\/current\/${db_sid} valid_for=(online_logfile,primary_role) db_unique_name=${primary_db_unq}'/log_archive_dest_1='location=\/u03\/archive\/current\/${db_sid} valid_for=(online_logfile,primary_role) db_unique_name=${standby_db_unq}'/g" ${backup_dir}/standby_init.ora
fi
sed -i "s/log_archive_dest_2='service=${standby_tns_alias} lgwr async valid_for=(online_logfiles,primary_role) db_unique_name=${standby_db_unq}'/log_archive_dest_2='service=${primary_tns_alias} lgwr async valid_for=(online_logfiles,primary_role) db_unique_name=${primary_db_unq}'/g" ${backup_dir}/standby_init.ora
sed -i "s/fal_server='${standby_tns_alias}'/fal_server='${primary_tns_alias}'/g" ${backup_dir}/standby_init.ora
sed -i "s/db_unique_name='${primary_db_unq}'/db_unique_name='${standby_db_unq}'/g" ${backup_dir}/standby_init.ora
sed -i -e "\|*.db_unique_name='${standby_db_unq}'|h; \${x;s|*.db_unique_name='${standby_db_unq}'||;{g;t};a\\" -e "*.db_unique_name='${standby_db_unq}'" -e "}" ${backup_dir}/standby_init.ora
sed -i "s/${primary_cluster}.${primary_domain}/${standby_cluster}.${standby_domain}/g" ${backup_dir}/standby_init.ora
sed -i "s/${primary_cluster}/${standby_cluster}/g" ${backup_dir}/standby_init.ora
sed -i "s/log_file_name_convert='${standby_db_unq}','${primary_db_unq}'/log_file_name_convert='${primary_db_unq}','${standby_db_unq}'/g" ${backup_dir}/standby_init.ora

if [[ ${primary_domain} != ${standby_domain} ]]; then
  sed -i "s/db_domain='${primary_domain}'/db_domain='${standby_domain}'/g" ${backup_dir}/standby_init.ora
fi

if ${prac} ; then
  if ! ${srac} ; then
    sed -i "s/^*.cluster_database=TRUE/*.cluster_database=FALSE/g" ${backup_dir}/standby_init.ora
    sed -i "s/^${dg_sid}1.undo_tablespace/*.undo_tablespace/g" ${backup_dir}/standby_init.ora
    sed -i "s/^${db_name}/#${db_name}/g" ${backup_dir}/standby_init.ora
    sed -i "/*.remote_listener/d" ${backup_dir}/standby_init.ora
    sed -i "/*.cluster_database_instances/d" ${backup_dir}/standby_init.ora
  fi
else
  if ${srac} ; then
    clcount=0
    while read line; do
      if [[ "${line}" == *"*.cluster_database="* ]]; then
        ((clcount++))
      fi
      if [[ "${line}" == *"*.cluster_database_instances="* ]]; then
        ((instcount++))
      fi
    done < "${backup_dir}/standby_init.ora"
    if [[ ${clcount} -gt 0 ]]; then
      sed -i "s/^*.cluster_database=FALSE/*.cluster_database=TRUE/g" ${backup_dir}/standby_init.ora
    else
      echo -e "*.cluster_database=TRUE" >> ${backup_dir}/standby_init.ora
    fi
    sed -i "s/^*.cluster_database_instances=/#*.cluster_database_instance=/g" ${backup_dir}/standby_init.ora
    echo -e "*.cluster_database_instances=8" >> ${backup_dir}/standby_init.ora
  fi
fi


if [[ ${env_type} -eq 3 ]]; then
  SAE="U2FsdGVkX18Q45dzif5uua3fdslMDQFyhoZfMISBqc7z2KyoPXiwB3XVoqvGXTUT"
  WE=$( echo $SAE | openssl enc -aes-128-cbc -a -d -salt -pass pass:wtf )

  echo -e "set encryption on identified by ${WE} only; \nrun {    "> ${backup_dir}/duplicate_db.rman

  for (( i=1; i<=$((${cpus} / 2)); i++ )); do
  	echo -e "allocate channel c${i} device type disk;" >> ${backup_dir}/duplicate_db.rman
    echo -e "allocate auxiliary channel ac${i} device type disk;" >> ${backup_dir}/duplicate_db.rman
  done

  echo -e "BACKUP VALIDATE CHECK LOGICAL DATABASE; \nDUPLICATE TARGET DATABASE FOR STANDBY FROM ACTIVE DATABASE DORECOVER NOFILENAMECHECK;" >> ${backup_dir}/duplicate_db.rman

  for (( i=1; i<=$((${cpus} / 2)); i++ )); do
  	echo -e "release channel c${i};" >> ${backup_dir}/duplicate_db.rman
    echo -e "release channel ac${i};" >> ${backup_dir}/duplicate_db.rman
  done

  echo -e "}" >> ${backup_dir}/duplicate_db.rman
else
  echo -e "BACKUP VALIDATE CHECK LOGICAL DATABASE; \nDUPLICATE TARGET DATABASE FOR STANDBY FROM ACTIVE DATABASE DORECOVER NOFILENAMECHECK;\nexit;" > ${backup_dir}/duplicate_db.rman
fi

results=($(${DB_HOME}/bin/sqlplus -s  / as sysdba << EOF
  set heading off pages 0 feedback off
  SET SERVEROUT ON SIZE 100000
  select
  (select (select count(*) from (select 1 from v\$logfile where type='ONLINE' group by group#))/(select max(thread#) from v\$log) from dual) || ' ' ||
  (select max(thread#) from v\$log) || ' ' ||
  (select max(group#) from v\$logfile) || ' ' ||
  (select bytes/1024/1024 from v\$log where rownum < 2)
  from dual;
EOF
)
)

maxthread=${results[1]}
maxgroup=${results[2]}
members=${results[0]}
filesize=${results[3]}
redotxt=""
((maxgroup++))
((members++))

for (( i=1; i<=${maxthread}; i++ )); do
  redotxt="${redotxt}\n\nALTER DATABASE ADD STANDBY LOGFILE THREAD ${i}\n"
  for (( j=1; j<=${members}; j++ )); do
    if [[ ${j} -gt 1 ]]; then
      redotxt="${redotxt},\n"
    fi
    if [[ ${env_type} -eq 3 ]]; then
      redotxt="${redotxt}GROUP ${maxgroup} ('+RECO') SIZE ${filesize}M"
    else
      redotxt="${redotxt}GROUP ${maxgroup} ('+DATA','+DATA') SIZE ${filesize}M"
    fi
    ((maxgroup++))
  done
  redotxt="${redotxt};\n"
done

redotxt="${redotxt}exit"
echo -e "${redotxt}" > ${backup_dir}/redo_gen.sql
echo -e "\nalter database recover managed standby database cancel;\nrecover managed standby database using current logfile disconnect from session;\nexit" > ${backup_dir}/recover.sql
echo -e "alter system checkpoint global;\nalter system archive log current;\nalter system archive log current;\nalter system archive log current;\nalter system checkpoint global;\nexit" > ${backup_dir}/archive_current.sql

###############################################
###############################################
#
# Creating standby redo logs on primary
#
###############################################
###############################################

banner_message "Adding Standby Redo Logs to Primary DB"

drop_stby_results=($(${DB_HOME}/bin/sqlplus -s  / as sysdba << EOF
    set heading off pages 0 feedback off
    set lines 200
    SET SERVEROUT ON SIZE 100000
    select 'alter database drop standby logfile group ' || group# || ';\n' from v\$standby_log;
EOF
)
)

if [[ -z ${drop_stby_results} ]]; then
  ${DB_HOME}/bin/sqlplus -s / as sysdba @${backup_dir}/redo_gen.sql
else
  drop_redotxt="`echo -e "${drop_stby_results[@]}"`"
  drop_redotxt="${drop_redotxt}\nexit"
  echo -e "${drop_redotxt}" > ${backup_dir}/drop_redo_gen.sql
  ${DB_HOME}/bin/sqlplus -s / as sysdba @${backup_dir}/drop_redo_gen.sql
  ${DB_HOME}/bin/sqlplus -s / as sysdba @${backup_dir}/redo_gen.sql
fi

###############################################
###############################################
#
# Creating more init files
#
###############################################
###############################################


banner_message "Generating SPFILE/SRVCTRL CONFIG/BROKER CONFIG FILES"
echo -e "SPFILE='+DATA/${standby_db_unq}/spfile${dg_sid}.ora'" > ${backup_dir}/initfile.ora
if [[ ${env_type} -eq 3 ]]; then
  echo -e "create SPFILE='+DATA/${standby_db_unq}/spfile${standby_db_unq}.ora' from pfile='${restore_dir}/standby_init.ora';\nexit" > ${backup_dir}/create_spfile.sql
  echo -e "${DB_HOME}/bin/srvctl add database -d ${standby_db_unq} -n ${dg_sid} -o ${DB_HOME} -p '+DATA/${standby_db_unq}/spfile${standby_db_unq}.ora' -r physical_standby" > ${backup_dir}/srvctl_add.sh
  echo -e "\n" >> ${backup_dir}/srvctl_add.sh
  echo -e "${DB_HOME}/bin/srvctl setenv database -d ${standby_db_unq} -T \"ORACLE_UNQNAME=${standby_db_unq}\"" >> ${backup_dir}/srvctl_add.sh
else
  echo -e "create SPFILE='+DATA/${standby_db_unq}/spfile${dg_sid}.ora' from pfile='${restore_dir}/standby_init.ora';\nexit" > ${backup_dir}/create_spfile.sql
  echo -e "${DB_HOME}/bin/srvctl add database -d ${standby_db_unq} -o ${DB_HOME} -p '+DATA/${standby_db_unq}/spfile${dg_sid}.ora' -r physical_standby" > ${backup_dir}/srvctl_add.sh
  echo -e "\n" >> ${backup_dir}/srvctl_add.sh
  echo -e "${DB_HOME}/bin/srvctl setenv database -d ${standby_db_unq} -T \"ORACLE_UNQNAME=${primary_db_unq}\"" >> ${backup_dir}/srvctl_add.sh
fi

if [[ ${db_version} -eq 11 ]] && ! ${srac};then
  echo -e " -n ${dg_sid} -i ${dg_sid}\n" >> ${backup_dir}/srvctl_add.sh
else
  echo -e "\n" >> ${backup_dir}/srvctl_add.sh
fi

if ${srac} ; then
  counter=0
  preferred_inst=''
  for i in ${standby_nodes[@]}; do
    if ${rac_one}; then
      echo -e "${DB_HOME}/bin/srvctl add instance -d ${standby_db_unq} -i ${dg_sid}_$((${counter}+1)) -n ${standby_nodes[${counter}]}\n" >> ${backup_dir}/srvctl_add.sh
      if [[ ${counter} -gt 0 ]] && [[ ${counter} -lt ${#standby_nodes[@]} ]]; then
        preferred_inst="${preferred_inst},"
      fi
      preferred_inst="${preferred_inst}${dg_sid}_$((${counter}+1))"
    else
      echo -e "${DB_HOME}/bin/srvctl add instance -d ${standby_db_unq} -i ${dg_sid}$((${counter}+1)) -n ${standby_nodes[${counter}]}\n" >> ${backup_dir}/srvctl_add.sh
      if [[ ${counter} -gt 0 ]] && [[ ${counter} -lt ${#standby_nodes[@]} ]]; then
        preferred_inst="${preferred_inst},"
      fi
      preferred_inst="${preferred_inst}${dg_sid}$((${counter}+1))"
    fi
    ((counter++))
  done

  echo -e "${DB_HOME}/bin/srvctl start instance -d ${standby_db_unq} -i ${dg_psid} -o nomount \n" >> ${backup_dir}/srvctl_add.sh
  echo -e "${DB_HOME}/bin/srvctl status database -d ${standby_db_unq} -v" >> ${backup_dir}/srvctl_add.sh

else
  if [[ ${env_type} -eq 3 ]]; then
    echo -e "${DB_HOME}/bin/srvctl add instance -d ${standby_db_unq} -i ${dg_sid} -n ${standby_nodes[0]}\n" >> ${backup_dir}/srvctl_add.sh
  else
    echo -e "${DB_HOME}/bin/srvctl modify database -d ${standby_db_unq} -n ${db_name} -i ${db_name}\n" >> ${backup_dir}/srvctl_add.sh
  fi

  echo -e "${DB_HOME}/bin/srvctl start database -d ${standby_db_unq} -o nomount \n" >> ${backup_dir}/srvctl_add.sh
  echo -e "${DB_HOME}/bin/srvctl status database -d ${standby_db_unq} -v" >> ${backup_dir}/srvctl_add.sh
fi

if [[ ${env_type} -eq 3 ]]; then
  if [[ ! -z {ic_domain} ]]; then
    service_domain=".${ic_domain}"
  fi
  if ${rac_one} || ${srac}; then
    echo -e "${DB_HOME}/bin/srvctl add service -d ${standby_db_unq} -s ${standby_db_unq}${service_domain} -l PRIMARY -y AUTOMATIC -r ${preferred_inst}"  >> ${backup_dir}/srvctl_add.sh
    for i in ${pdbs[@]}; do
      echo -e "${DB_HOME}/bin/srvctl add service -d ${standby_db_unq} -s ${i,,}${service_domain} -l PRIMARY -y AUTOMATIC -r ${preferred_inst} -pdb ${i,,}"  >> ${backup_dir}/srvctl_add.sh
    done
  else
    echo -e "${DB_HOME}/bin/srvctl add service -d ${standby_db_unq} -s ${standby_db_unq}${service_domain} -l PRIMARY -y AUTOMATIC -r ${db_name}"  >> ${backup_dir}/srvctl_add.sh
    for i in ${pdbs[@]}; do
      echo -e "${DB_HOME}/bin/srvctl add service -d ${standby_db_unq} -s ${i,,}${service_domain} -l PRIMARY -y AUTOMATIC -r ${db_name} -pdb ${i,,}"  >> ${backup_dir}/srvctl_add.sh
    done
  fi

  echo -e "ALTER SYSTEM SET DG_BROKER_START=false SCOPE=BOTH SID='*';\nALTER SYSTEM SET DG_BROKER_CONFIG_FILE1 = '+DATA/${primary_db_unq}/broker/dr1${db_name}.dat' SCOPE=BOTH SID='*';\nALTER SYSTEM SET DG_BROKER_CONFIG_FILE2 = '+DATA/${primary_db_unq}/broker/dr2${db_name}.dat' SCOPE=BOTH SID='*';\nALTER SYSTEM SET DG_BROKER_START=true SCOPE=BOTH SID='*';\nexit" > ${backup_dir}/pdb_dg.sql
  echo -e "ALTER SYSTEM SET DG_BROKER_START=false SCOPE=BOTH SID='*';\nALTER SYSTEM SET DG_BROKER_CONFIG_FILE1 = '+DATA/${standby_db_unq}/broker/dr1${db_name}.dat' SCOPE=BOTH SID='*';\nALTER SYSTEM SET DG_BROKER_CONFIG_FILE2 = '+DATA/${standby_db_unq}/broker/dr2${db_name}.dat' SCOPE=BOTH SID='*';\nALTER SYSTEM SET DG_BROKER_START=true SCOPE=BOTH SID='*';\nexit" > ${backup_dir}/sdb_dg.sql
  echo -e "CONFIGURE SNAPSHOT CONTROLFILE NAME TO '+RECO/${standby_db_unq}/controlfile/snapcf_${standby_db_unq}.f';\nCONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY;" > ${backup_dir}/sby_config.rman
  echo -e "CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY;" > ${backup_dir}/pri_config.rman
else

  if [[ ! -z {standby_domain} ]]; then
    service_domain=".${standby_domain}"
  fi

  if ${rac_one} || ${srac}; then
    for i in ${pdbs[@]}; do
      echo -e "${DB_HOME}/bin/srvctl add service -d ${standby_db_unq} -s ${i,,}${service_domain} -l PRIMARY -y AUTOMATIC -r ${preferred_inst} -pdb ${i,,}"  >> ${backup_dir}/srvctl_add.sh
    done
  else
    for i in ${pdbs[@]}; do
      echo -e "${DB_HOME}/bin/srvctl add service -d ${standby_db_unq} -s ${i,,}${service_domain} -l PRIMARY -y AUTOMATIC -r ${db_name} -pdb ${i,,}"  >> ${backup_dir}/srvctl_add.sh
    done
  fi

  echo -e "ALTER SYSTEM SET DG_BROKER_START=false SCOPE=BOTH SID='*';\nALTER SYSTEM SET DG_BROKER_CONFIG_FILE1 = '+DATA/${primary_db_unq}/dr1${db_name}.dat' SCOPE=BOTH SID='*';\nALTER SYSTEM SET DG_BROKER_CONFIG_FILE2 = '+DATA/${primary_db_unq}/dr2${db_name}.dat' SCOPE=BOTH SID='*';\nALTER SYSTEM SET DG_BROKER_START=true SCOPE=BOTH SID='*';\nexit" > ${backup_dir}/pdb_dg.sql
  echo -e "ALTER SYSTEM SET DG_BROKER_START=false SCOPE=BOTH SID='*';\nALTER SYSTEM SET DG_BROKER_CONFIG_FILE1 = '+DATA/${standby_db_unq}/dr1${db_name}.dat' SCOPE=BOTH SID='*';\nALTER SYSTEM SET DG_BROKER_CONFIG_FILE2 = '+DATA/${standby_db_unq}/dr2${db_name}.dat' SCOPE=BOTH SID='*';\nALTER SYSTEM SET DG_BROKER_START=true SCOPE=BOTH SID='*';\nexit" > ${backup_dir}/sdb_dg.sql
  echo -e "CONFIGURE SNAPSHOT CONTROLFILE NAME TO '/u03/${db_name}/control/control_snapcf_${db_name}.dbf';\nCONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY;" >> ${backup_dir}/sby_config.rman
  echo -e "CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY;" >> ${backup_dir}/pri_config.rman
fi

###############################################
###############################################
#
# Wallet Transfer
#
###############################################
###############################################


banner_message "Transferring TDE Wallets to all standby nodes"


if [[ -n ${wallet_dir} ]]; then

  counter=0
  for i in ${standby_nodes_wd[@]}; do
    scp -q ${DB_HOME}/network/admin/sqlnet.ora ${i}:${DB_HOME}/network/admin/sqlnet.ora

    if [[ -n `grep ORACLE_UNQNAME ${DB_HOME}/network/admin/sqlnet.ora` ]]; then
      if [[ ${env_type} -eq 3 ]]; then
ssh ${ssh_ops} oracle@$i <<-EOF
  sed -r -i 's/ORACLE_UNQNAME=.*/ORACLE_UNQNAME=${standby_db_unq}/' /home/oracle/.bashrc
  sed -r -i 's/ORACLE_SID=.*/ORACLE_SID=${dg_psid}/' /home/oracle/.bashrc
EOF
      else
ssh ${ssh_ops} oracle@$i <<-EOF
  sed -r -i 's/ORACLE_UNQNAME=.*/ORACLE_UNQNAME=${dg_sid}/' /home/oracle/.bashrc
  sed -r -i 's/ORACLE_SID=.*/ORACLE_SID=${dg_psid}/' /home/oracle/.bashrc
EOF
      fi
    fi
  done

  if [[ ${env_type} -eq 3 ]]; then
    scp -r -q ${wallet_dir}/${primary_db_unq}/* ${shn}:${wallet_dir}/${standby_db_unq}/
  else
    scp -r -q ${wallet_dir}/* ${shn}:${wallet_dir}/
  fi

fi

###############################################
###############################################
#
# Copy Files to Standby Node 1
#
###############################################
###############################################

banner_message "Transferring files/scripts to standby server"
scp -q ${backup_dir}/* ${shn}:${restore_dir}/


###############################################
###############################################
#
# Running srvctl to add to crs
#
###############################################
###############################################

banner_message "Starting standby recovery and adding info to CRS"

if [[ ${env_type} -eq 3 ]]; then

ssh ${ssh_ops} oracle@${standby_nodes_wd[0]} <<-EOF
  export ORACLE_SID=${dg_psid}
  export ORACLE_HOME=${DB_HOME}
  export ORACLE_UNQNAME=${standby_db_unq}
  ${DB_HOME}/bin/sqlplus '/as sysdba' @${backup_dir}/create_spfile.sql
  chmod 755 ${restore_dir}/srvctl_add.sh
  ${restore_dir}/srvctl_add.sh
EOF

else

ssh ${ssh_ops} oracle@${standby_nodes_wd[0]} <<-EOF
  export ORACLE_SID=${dg_psid}
  export ORACLE_HOME=${DB_HOME}
  export ORACLE_UNQNAME=${dg_sid}
  ${DB_HOME}/bin/sqlplus '/as sysdba' @${backup_dir}/create_spfile.sql
  chmod 755 ${restore_dir}/srvctl_add.sh
  ${restore_dir}/srvctl_add.sh
EOF

fi

sleep 20

###############################################
###############################################
#
# Copying of Password file
#
###############################################
###############################################

banner_message "Copy Password file "

export ORACLE_SID=$(cat /etc/oratab|grep ASM|grep -vE '^\#|^\*|^$'| awk -F: '{print $1}')
export ORACLE_HOME=${pGRID_HOME}

if [[ "${db_version}" == "12" ]]; then
  if [[ ${env_type} -eq 3 ]]; then
    export ORACLE_HOME=${DB_HOME}
    ppwfile="$(${DB_HOME}/bin/srvctl config database -d ${primary_db_unq} |grep -i password|awk '{print $3}')"
  else
    export ORACLE_HOME=${pGRID_HOME}
    ppwfile="$(echo `${pGRID_HOME}/bin/asmcmd pwget --dbuniquename ${primary_db_unq}`)"
  fi
else
  ppwfile=""
fi

if [[ -z ${ppwfile} ]]  || [[ ${ppwfile} == "Password file location has not been set for DB instance" ]]; then

  if [[ ! -f ${DB_HOME}/dbs/orapw${db_psid} ]]; then
    export ORACLE_SID=${db_psid}
    export ORACLE_HOME=${DB_HOME}
    cd ${DB_HOME}/dbs/
    ${DB_HOME}/bin/orapwd file=orapw${db_psid} password=${WD}
    echo "Password File has been created"
  fi

  counter=0
  temp_sid="${db_sid}"
  for i in ${primary_nodes_wd[@]}; do

    if ${prac} ; then
      if ${rac_one}; then
        temp_sid="${db_sid}_$((${counter}+1))"
      else
        temp_sid="${db_sid}$((${counter}+1))"
      fi
    fi
    if [[ ${i} != primary_nodes_wd[0] ]]; then
      scp -q "${DB_HOME}/dbs/orapw${db_psid}" ${i}:"${DB_HOME}/dbs/orapw${temp_sid}"
    fi
    ((counter++))
  done

  counter=0
  temp_sid="${dg_sid}"
  for i in ${standby_nodes_wd[@]}; do
    if ${srac} ; then
      if ${rac_one}; then
        temp_sid="${dg_sid}_$((${counter}+1))"
      else
        temp_sid="${dg_sid}$((${counter}+1))"
      fi
    fi
    scp -q "${DB_HOME}/dbs/orapw${db_psid}" ${standby_nodes_wd[${counter}]}:"${DB_HOME}/dbs/orapw${temp_sid}"
    ((counter++))
  done
else
  if [[ ${env_type} -eq 3 ]]; then
    sudo ${pGRID_HOME}/bin/asmcmd cp ${ppwfile} ${backup_dir}/pwd${standby_db_unq}
    scp -q ${backup_dir}/pwd${standby_db_unq} oracle@${shn}:${backup_dir}/

ssh ${ssh_ops} oracle@${shn} <<-EOF
  export sGRID_HOME=$(cat /etc/oratab | grep ASM| grep -vE '^\#|^\*|^$'|awk -F: '{print $2}')
  sudo ${sGRID_HOME}/bin/asmcmd cp ${backup_dir}/pwd${standby_db_unq} '+DATA/${standby_db_unq}/pwd${standby_db_unq}'
  ${DB_HOME}/bin/srvctl modify database -d ${standby_db_unq} -pwfile '+DATA/${standby_db_unq}/pwd${standby_db_unq}'
EOF

  else
    ${pGRID_HOME}/bin/asmcmd pwcopy ${ppwfile} ${backup_dir}/orapw${db_sid}
    scp -q ${backup_dir}/orapw${db_sid} oracle@${shn}:${backup_dir}/

ssh ${ssh_ops} oracle@${shn} <<-EOF
  export ORACLE_SID=$(cat /etc/oratab | grep ASM| grep -vE '^\#|^\*|^$'|awk -F: '{print $1}')
  export ORACLE_HOME=$(cat /etc/oratab | grep ASM| grep -vE '^\#|^\*|^$'|awk -F: '{print $2}')
  ${sGRID_HOME}/bin/asmcmd pwcopy --dbuniquename ${standby_db_unq} ${backup_dir}/orapw${db_name} '+DATA/${standby_db_unq}/orapw${db_name}'
  ${DB_HOME}/bin/srvctl modify database -d ${standby_db_unq} -pwfile '+DATA/${standby_db_unq}/orapw${db_name}'
EOF
  fi

fi

if [[ ${env_type} -ne 3 ]]; then

  ################################################
  ################################################
  ##
  ## Edit sqlnet.ora before duplicate Doc ID 2073604.1
  ##
  ################################################
  ################################################

  if [[ -f "${pGRID_HOME}/network/admin/sqlnet.ora" ]]; then
    cp "${pGRID_HOME}/network/admin/sqlnet.ora" "${pGRID_HOME}/network/admin/sqlnet.ora.`date '+%F'`"
    cp "${pGRID_HOME}/network/admin/sqlnet.ora" ${backup_dir}/sqlnet.ora
  else
    touch ${backup_dir}/sqlnet.ora
  fi

  sed -i -e "\|DISABLE_OOB=on|h; \${x;s|DISABLE_OOB=on||;{g;t};a\\" -e "DISABLE_OOB=on" -e "}" ${backup_dir}/sqlnet.ora

  cp ${backup_dir}/sqlnet.ora "${pGRID_HOME}/network/admin/sqlnet.ora"
  rm -f ${backup_dir}/sqlnet.ora

  if ssh ${ssh_ops} ${shn} "test -e ${sGRID_HOME}/network/admin/sqlnet.ora"; then
    scp -q ${shn}:"${sGRID_HOME}/network/admin/sqlnet.ora" ${backup_dir}/sqlnet.ora
    ssh ${ssh_ops} ${shn} cp "${sGRID_HOME}/network/admin/sqlnet.ora" "${sGRID_HOME}/network/admin/sqlnet.ora.`date '+%F'`"
  else
    touch ${backup_dir}/sqlnet.ora
  fi

  sed -i -e "\|DISABLE_OOB=on|h; \${x;s|DISABLE_OOB=on||;{g;t};a\\" -e "DISABLE_OOB=on" -e "}" ${backup_dir}/sqlnet.ora

  scp -q ${backup_dir}/sqlnet.ora ${shn}:"${sGRID_HOME}/network/admin/sqlnet.ora"
  rm -f ${backup_dir}/sqlnet.ora
fi

################################################
################################################
##
## Duplicate Standby from Active Database
##
################################################
################################################

banner_message "Duplicate Standby"



export ORACLE_SID=${db_psid}
export ORACLE_HOME=${DB_HOME}


${DB_HOME}/bin/sqlplus '/as sysdba' @${backup_dir}/archive_current.sql
${DB_HOME}/bin/rman target sys/${WD}@${primary_tns_alias} auxiliary sys/${WD}@${standby_tns_alias} cmdfile=${backup_dir}/duplicate_db.rman log=${backup_dir}/duplicate_db.log

error_level $? "Active Duplicate of Standby ${dg_psid}" 1

if [[ ${env_type} -eq 3 ]]; then
  echo -e "\n\n"
else

ssh ${ssh_ops} oracle@${shn} <<-EOF
  cd /home/oracle/rman
  /usr/bin/wget -nv -nd -np -r -l1 -A"standby_cleanup.sh" -N http://depot:8080/export/scripts/DBA/archlogs
  tr -d '\015' < standby_cleanup.sh  > standby_cleanup.bash && mv standby_cleanup.bash standby_cleanup.sh
  chmod +x standby_cleanup.sh
  echo '0 12 * * * /home/oracle/rman/standby_cleanup.sh' > crontab.tmp && crontab crontab.tmp
  exit
EOF

################################################
################################################
##
## Delete entry from sqlnet.ora after duplicate Doc ID 2073604.1
##
################################################
################################################

if [[ -f "${pGRID_HOME}/network/admin/sqlnet.ora" ]]; then
  cp "${pGRID_HOME}/network/admin/sqlnet.ora" "${pGRID_HOME}/network/admin/sqlnet.ora.`date '+%F'`"
  cp "${pGRID_HOME}/network/admin/sqlnet.ora" ${backup_dir}/sqlnet.ora
else
  touch ${backup_dir}/sqlnet.ora
fi

sed -i '/DISABLE_OOB=on/d' ${backup_dir}/sqlnet.ora

cp ${backup_dir}/sqlnet.ora "${pGRID_HOME}/network/admin/sqlnet.ora"
rm -f ${backup_dir}/sqlnet.ora

if ssh ${ssh_ops} ${shn} "test -e ${sGRID_HOME}/network/admin/sqlnet.ora"; then
  scp -q ${shn}:"${sGRID_HOME}/network/admin/sqlnet.ora" ${backup_dir}/sqlnet.ora
  ssh ${ssh_ops} ${shn} cp "${sGRID_HOME}/network/admin/sqlnet.ora" "${sGRID_HOME}/network/admin/sqlnet.ora.`date '+%F'`"
else
  touch ${backup_dir}/sqlnet.ora
fi

sed -i '/DISABLE_OOB=on/d' ${backup_dir}/sqlnet.ora

scp -q ${backup_dir}/sqlnet.ora ${shn}:"${sGRID_HOME}/network/admin/sqlnet.ora"
rm -f ${backup_dir}/sqlnet.ora

fi

###############################################
###############################################
#
# Mounting standby database on all nodes
#
###############################################
###############################################

banner_message "Mounting all standby instances"
counter=0
for i in ${standby_nodes_wd[@]}; do
  temp_sid="${dg_sid}"
  if ${srac} ; then
    if ${rac_one}; then
      temp_sid="${dg_sid}_$((${counter}+1))"
    else
      temp_sid="${dg_sid}$((${counter}+1))"
    fi
  fi
  scp -q ${backup_dir}/initfile.ora ${standby_nodes_wd[${counter}]}:${DB_HOME}/dbs/init${temp_sid}.ora
  ((counter++))
done

ssh ${ssh_ops} oracle@${shn} <<-EOF
  export ORACLE_SID=${dg_psid}
  export ORACLE_HOME=${DB_HOME}
  ${DB_HOME}/bin/srvctl stop database -d ${standby_db_unq}
  ${DB_HOME}/bin/srvctl start database -d ${standby_db_unq}

  if [[ $? -eq 0 ]]; then
    exit
  else
    exit 1
  fi
EOF

###############################################
###############################################
#
# Enabling broker locally/remotely
#
###############################################
###############################################

export ORACLE_SID=${db_psid}
export ORACLE_HOME=${DB_HOME}



banner_message "Enabling dataguard broker on primary and standby databases"
${DB_HOME}/bin/sqlplus -s / as sysdba @${backup_dir}/pdb_dg.sql

ssh ${ssh_ops} oracle@${shn} <<-EOF
  export ORACLE_SID=${dg_psid}
  export ORACLE_HOME=${DB_HOME}
  ${DB_HOME}/bin/sqlplus / as sysdba @${restore_dir}/sdb_dg.sql
  exit
EOF



echo -e "\n\E[0;35mWaiting 1  minute for broker to catch up\E[0;39m"
sleep 60

banner_message "Emptying log_archive_dest_2 on both databases for broker config"

if [[ "${db_version}" == "12" ]]; then
  ${DB_HOME}/bin/sqlplus -s / as sysdba @${backup_dir}/empty_logdest2.sql
fi


ssh ${ssh_ops} oracle@${shn} <<-EOF
  export ORACLE_SID=${dg_psid}
  export ORACLE_HOME=${DB_HOME}

  if [[ "${db_version}" == "12" ]]; then
    ${DB_HOME}/bin/sqlplus -s / as sysdba @${restore_dir}/empty_logdest2.sql
  fi

  ${DB_HOME}/bin/sqlplus -s / as sysdba @${restore_dir}/recover.sql

${DB_HOME}/bin/sqlplus -s / as sysdba <<-SQLF
  alter database open read only;
  exit;
SQLF

  exit
EOF

###############################################
###############################################
#
# Editing TNSNAMES.ora files on all nodes
#
###############################################
###############################################

if [[ ${primary_domain} == ${standby_domain} ]] && [[ ${env_type} -ne 3 ]]; then

  ###############################################
  ###############################################
  #
  # Modify Scan name for the last occurrence of Primary and Standby TNS
  #
  ###############################################
  ###############################################

  if ${prac}; then
    for i in ${primary_nodes[@]}; do
ssh ${ssh_ops} oracle@${i} <<-EOF
  echo "` tac ${DB_HOME}/network/admin/tnsnames.ora  |sed -e "0,/${primary_nodes[0]}/{s/${primary_nodes[0]}/${primary_cluster}/}" -e "0,/${standby_nodes[0]}/{s/${standby_nodes[0]}/${standby_cluster}/}"|tac `" > ${DB_HOME}/network/admin/tnsnames.ora
EOF
    done
  fi

  if ${srac}; then
    for i in ${standby_nodes[@]}; do
ssh ${ssh_ops} oracle@${i} <<-EOF
  echo "` tac ${DB_HOME}/network/admin/tnsnames.ora  |sed -e "0,/${primary_nodes[0]}/{s/${primary_nodes[0]}/${primary_cluster}/}" -e "0,/${standby_nodes[0]}/{s/${standby_nodes[0]}/${standby_cluster}/}"|tac `" > ${DB_HOME}/network/admin/tnsnames.ora
EOF
    done
  fi

else

  ###############################################
  ###############################################
  #
  # Modify Scan name for the last occurrence of Primary and Standby TNS
  #
  ###############################################
  ###############################################

  if [[ ${env_type} -eq 3 ]]; then
    if ${prac}; then
    	for i in ${primary_nodes_wd[@]}; do
ssh ${ssh_ops} oracle@${i} <<-EOF
  echo "` tac ${DB_HOME}/network/admin/tnsnames.ora  |sed -e "0,/${primary_nodes_wd[0]}/{s/${primary_nodes_wd[0]}/${primary_cluster}/}" -e "0,/${standby_nodes_wd[0]}/{s/${standby_nodes_wd[0]}/${standby_cluster}/}"|tac `" > ${DB_HOME}/network/admin/tnsnames.ora
EOF
    	done
    fi

    if ${srac}; then
    	for i in ${standby_nodes_wd[@]}; do
ssh ${ssh_ops} oracle@${i} <<-EOF
  echo "` tac ${DB_HOME}/network/admin/tnsnames.ora  |sed -e "0,/${primary_nodes_wd[0]}/{s/${primary_nodes_wd[0]}/${primary_cluster}/}" -e "0,/${standby_nodes_wd[0]}/{s/${standby_nodes_wd[0]}/${standby_cluster}/}"|tac `" > ${DB_HOME}/network/admin/tnsnames.ora
EOF
    	done
    fi

  else
    ###############################################
    ###############################################
    #
    # Modify all VIPS to replace the first node VIP of Primary and Standby TNS
    # to reduce chances of stopped MRP 246126.1
    #
    ###############################################
    ###############################################

    banner_message "Modify all VIPS to replace the first node VIP of Primary and Standby TNS"

    primary_tns="\n${primary_db_unq} =\n   (DESCRIPTION =\n     (ADDRESS_LIST =\n"

    if ${prac} ; then
      counter=0
      for i in ${primary_vips[@]}; do
        primary_tns="${primary_tns}       (ADDRESS = (PROTOCOL = TCP)(HOST = ${primary_vips[${counter}]})(PORT = 1521))\n"
        ((counter++))
      done
    else
      primary_tns="${primary_tns}       (ADDRESS = (PROTOCOL = TCP)(HOST = ${primary_vips[0]})(PORT = 1521))\n"
    fi

    if [[ -z ${db_domain} ]] ; then
      primary_tns="${primary_tns}       (LOAD_BALANCE = yes)\n     )\n     (CONNECT_DATA =\n       (SERVER = DEDICATED)\n       (SERVICE_NAME = ${primary_db_unq})\n     )\n   )\n"
    else
      primary_tns="${primary_tns}       (LOAD_BALANCE = yes)\n     )\n     (CONNECT_DATA =\n       (SERVER = DEDICATED)\n       (SERVICE_NAME = ${primary_db_unq}.${primary_domain})\n     )\n   )\n"
    fi

    standby_tns="\n${standby_db_unq} =\n   (DESCRIPTION =\n     (ADDRESS_LIST =\n"


    if ${srac} ; then
      counter=0
      for i in ${standby_vips[@]}; do
        standby_tns="${standby_tns}       (ADDRESS = (PROTOCOL = TCP)(HOST = ${standby_vips[${counter}]})(PORT = 1521))\n"
        ((counter++))
      done
    else
      standby_tns="${standby_tns}       (ADDRESS = (PROTOCOL = TCP)(HOST = ${standby_vips[0]})(PORT = 1521))\n"
    fi

    if [[ -z ${db_domain} ]] ; then
      standby_tns="${standby_tns}       (LOAD_BALANCE = yes)\n     )\n     (CONNECT_DATA =\n       (SERVER = DEDICATED)\n       (SERVICE_NAME = ${standby_db_unq})\n     )\n   )\n\n"
    else
      standby_tns="${standby_tns}       (LOAD_BALANCE = yes)\n     )\n     (CONNECT_DATA =\n       (SERVER = DEDICATED)\n       (SERVICE_NAME = ${standby_db_unq}.${standby_domain})\n     )\n   )\n\n"
    fi

    cp "${DB_HOME}/network/admin/tnsnames.ora" "${DB_HOME}/network/admin/tnsnames.ora.bak"

    if [[ -f "${DB_HOME}/network/admin/tnsnames.ora" ]]; then
      cp "${DB_HOME}/network/admin/tnsnames.ora" ${backup_dir}/tnsnames.ora
    else
      touch ${backup_dir}/tnsnames.ora
    fi

    ####### Delete Primary and Standby TNS Alias
    entry_list[0]=${primary_db_unq}
    entry_list[1]=${standby_db_unq}
    entry_list[2]="`echo ${primary_db_unq} | tr '[:lower:]' '[:upper:]'`"
    entry_list[3]="`echo ${standby_db_unq} | tr '[:lower:]' '[:upper:]'`"

    temp_list=()

    for  ((x=0;x<4;x++)); do
      temp_list=$(find_tns_line_number `echo ${entry_list[${x}]}`)
      while [[ ! -z ${temp_list[0]} ]]; do
        delete_tns_entry ${temp_list[0]}
        temp_list=$(find_tns_line_number `echo ${entry_list[${x}]}`)
      done
    done
    ######

    modify_tns

    cp ${backup_dir}/tnsnames.ora "${DB_HOME}/network/admin/tnsnames.ora"
    rm -f ${backup_dir}/tnsnames.ora

    counter=0
    for i in ${other_nodes[@]}; do
      scp -q "${other_nodes[${counter}]}:${DB_HOME}/network/admin/tnsnames.ora" ${backup_dir}/tnsnames.ora

      if [[ ! -f ${backup_dir}/tnsnames.ora ]]; then
        touch ${backup_dir}/tnsnames.ora
      fi

      temp_list=()

      for  ((x=0;x<4;x++)); do
        temp_list=$(find_tns_line_number `echo ${entry_list[${x}]}`)
        while [[ ! -z ${temp_list[0]} ]]; do
          delete_tns_entry ${temp_list[0]}
          temp_list=$(find_tns_line_number `echo ${entry_list[${x}]}`)
        done
      done


      modify_tns


      scp -q ${backup_dir}/tnsnames.ora "${other_nodes[${counter}]}:${DB_HOME}/network/admin/tnsnames.ora"

      rm -f ${backup_dir}/tnsnames.ora
      ((counter++))
    done
  fi
fi

###############################################
###############################################
#
# Broker Config
#
###############################################
###############################################


banner_message "Configuring dataguard broker"
export ORACLE_SID=${db_psid}
export ORACLE_HOME=${DB_HOME}
${DB_HOME}/bin/dgmgrl / <<-EOF
  create configuration ${primary_db_unq} as primary database is ${primary_db_unq} connect identifier is ${primary_tns_alias};
  add database ${standby_db_unq} as connect identifier is ${standby_tns_alias} maintained as physical;
  enable configuration;
  exit
EOF


echo -e "create configuration ${primary_db_unq} as primary database is ${primary_db_unq} connect identifier is ${primary_tns_alias};"
echo -e "add database ${standby_db_unq} as connect identifier is ${standby_tns_alias} maintained as physical;"
echo -e "enable configuration"


banner_message "Opening read only and restarting recovery"
ssh ${ssh_ops} oracle@${shn} <<-EOF
  export ORACLE_SID=${dg_psid}
  export ORACLE_HOME=${DB_HOME}
${DB_HOME}/bin/dgmgrl / <<-EOD
  edit database ${standby_db_unq} set state='APPLY-OFF';
  exit
EOD
${DB_HOME}/bin/sqlplus -s / as sysdba <<-SQLF
  alter database open read only;
  exit;
SQLF

${DB_HOME}/bin/dgmgrl / <<-EOD
  edit database ${standby_db_unq} set state='APPLY-ON';
  exit
EOD

  exit
EOF

banner_message "Resetting log_archive_dest_2 to normal"
${DB_HOME}/bin/sqlplus -s / as sysdba @${backup_dir}/primary_logdest2.sql
ssh ${ssh_ops} oracle@${shn} <<-EOF
  export ORACLE_SID=${dg_psid}
  export ORACLE_HOME=${DB_HOME}
  ${DB_HOME}/bin/sqlplus -s / as sysdba @${restore_dir}/standby_logdest2.sql
  exit
EOF



###############################################
###############################################
#
# Running RMAN config for standby
#
###############################################
###############################################

banner_message "RMAN Config for local and standby"
rm -f "${backup_dir}/${db_name}_*"
${DB_HOME}/bin/rman target / @${backup_dir}/pri_config.rman


ssh ${ssh_ops} oracle@${shn} <<-EOF
  export ORACLE_SID=${dg_psid}
  export ORACLE_HOME=${DB_HOME}
  rm -f "${restore_dir}/${db_name}_*"
  ${DB_HOME}/bin/rman target / @${restore_dir}/sby_config.rman
  exit
EOF

###############################################
###############################################
#
# File Cleanup and Disable User Equivalence Daemon
#
###############################################
###############################################

banner_message "Cleaning up remaining files"
rm -rf ${backup_dir}
ssh ${ssh_ops} ${standby_nodes_wd[0]} rm -rf ${restore_dir}

###############################################
###############################################
#
# Download the Archivelog Clean Up script on the Standby DB Server (First node if RAC)
#
###############################################
###############################################

banner_message "Configure Archivelog Cleanup Script as a Cronjob"

ssh ${ssh_ops} oracle@${shn} <<-EOF
mkdir -p ~/rman/crontab_backup
cd ~/rman
/usr/bin/wget -nv -nd -np -r -l1 -A"standby_cleanup.sh" -N http://depot:8080/export/scripts/DBA/archlogs
tr -d '\015' < standby_cleanup.sh  > standby_cleanup.bash && mv standby_cleanup.bash standby_cleanup.sh
chmod +x standby_cleanup.sh
crontab -l > ~/rman/crontab_backup/crontab.`date '+%F'`
echo '0 12 * * * /home/oracle/rman/standby_cleanup.sh' > ~/rman/crontab_backup/crontab.tmp
echo '0 5 * * 6 find /home/oracle/rman/rman_deletearc*.log -mtime +14 -exec rm {} \;' >> ~/rman/crontab_backup/crontab.tmp && crontab ~/rman/crontab_backup/crontab.tmp
rm ~/rman/crontab_backup/crontab.tmp
EOF

###############################################
###############################################
#
# Display Final Broker Config for validation
#
###############################################
###############################################

export ORACLE_SID=${db_psid}
export ORACLE_HOME=${DB_HOME}

banner_message "Displaying final broker config"
${DB_HOME}/bin/dgmgrl / <<-EOF
  edit database ${standby_db_unq} set state='APPLY-ON';
EOF

echo -e "\n\E[0;35mWaiting 1  minute for broker to catch up\E[0;39m"
sleep 60

${DB_HOME}/bin/dgmgrl / <<-EOF
  show configuration;
EOF

if [[ $? -eq 0 ]]; then
  echo -e "\n\n\E[0;32mDataguard Build Script is done.\E[0;39m  "
else
  echo -e "\n\n\E[0;32mValidate Manually if the Primary and Standby is synchronized."
fi

if [[ ${env_type} -eq 3 ]]; then

  ###############################################
  ###############################################
  #
  # Replace Old Dummy DB Name in Standby with the new DB Name same as in Primary
  #
  ###############################################
  ###############################################

  if ${srac} ; then
    counter=1
    for i in ${standby_nodes_wd[@]}; do
      ssh ${ssh_ops} oracle@${i} sudo sed -i "s/${sb_dbname}[0-9]:/${pr_dbname}${counter}:/g" /etc/oratab
      ((counter++))
    done
  else
    ssh ${ssh_ops} oracle@${i} sudo sed -i "s/${sb_dbname}:/${pr_dbname}:/g" /etc/oratab
  fi

elif [[ ${env_type} -eq 2 ]]; then

###############################################
###############################################
#
# Generate Information for Admindb
#
###############################################
###############################################

ssh ${ssh_ops} oracle@${shn} <<-EOF

cd /home/oracle/oracle_install
/usr/bin/wget -nv -nd -np -r -l1 -A"get_dbserver_admindb.sh" -N http://depot:8080/export/scripts/DBA/2.0

if [[ -f /home/oracle/oracle_install/get_dbserver_admindb.sh ]]; then
  chown oracle:oinstall /home/oracle/oracle_install/get_dbserver_admindb.sh
  chmod 755 /home/oracle/oracle_install/get_dbserver_admindb.sh
  /home/oracle/oracle_install/get_dbserver_admindb.sh
  scp -q /home/oracle/oracle_install/gen_${standby_nodes[0]}_admindb.sql ${phn}:/home/oracle/oracle_install/gen_${standby_nodes[0]}_admindb.sql
  echo -e "Admin DB Script: \E[0;32m/home/oracle/oracle_install/gen_${standby_nodes[0]}_admindb.sql \E[0;39m"
else
  echo -e "\n\E[0;31mThere was an error copying the get_dbserver_admindb.sh script from DEPOT.  Copy the script manually to the server\n\E[0;39m"
fi
EOF

elif [[ ${env_type} -eq 1 ]]; then

###############################################
###############################################
#
# Enter the following commands for Promoting Target to EM
#
###############################################
###############################################


echo -e "\n\E[0;35mIn 1 minute, the commands for promoting targets to EM will appear"
echo -e "You can copy and paste the following commands over to the server \E[1;33mMMVOCIOOMSP001F\E[0;39m"

sleep 60


ssh ${ssh_ops} oracle@${shn} <<-EOF
cd /home/oracle/
wget onboard_target_em.sh http://depot:8080/export/scripts/DBA/oem/onboard_target_em.sh

if [[ -f /home/oracle/onboard_target_em.sh ]]; then
  chown oracle:oinstall /home/oracle/onboard_target_em.sh
  chmod 755 /home/oracle/onboard_target_em.sh
  /home/oracle/onboard_target_em.sh
else
  echo -e "\n\E[0;31mThere was an error copying the onboard_target_em.sh script from DEPOT.  Copy the script manually to the server\n\E[0;39m"
fi
EOF

fi
