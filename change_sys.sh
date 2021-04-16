#!/bin/bash

user=$(whoami)

if [[ "${user}" != "oracle" ]]; then
	echo -e "
Invalid user. Must be the ORACLE user.

"
	exit
fi

###############################
# Variables and Functions
###############################

declare -A primary_nodes=()
declare -A standby_nodes=()
declare -A primary_inst=()
declare -A standby_node_count=()
declare -A standby_oracle_homes=()
declare -A standby_dbuns=()
declare -A standby_instances=()


function variable_declaration () {

	inv_loc=$(awk -F= '/inventory_loc/ { print $NF }' /etc/oraInst.loc)
	grid_home=/u01/app/18.0.0.0/grid
	db_home=/u01/app/oracle/product/12.1.0.2/dbhome_1
	hn=$(hostname -s)
	nodes_primary=(doea0xm0t01.avp13536dt01.icprdiadclsvc1.oraclevcn.com doea0xm0t02.avp13536dt01.icprdiadclsvc1.oraclevcn.com)
	ssh_ops="-qtt -T"
	standby=false

	if [[ $? -ne 0 ]];then
		primary_nodes[1]=${hn}
	else
		counter=0
		for n in ${nodes_primary[@]};do
			((counter++))
			primary_nodes[${counter}]=${n}
		done
	fi

}


function error () {
	echo "
Invalid input. Must be one of the following:

 -i ORACLE_SID of local instance
OR
 -a to change the SYS password for all databases.

Followed by:

 -t to set a temporary SYS password.
 -p <PASSWORD> to manually set a SYS password.

Usage:

 ./change_sys.sh -i <ORACLE_SID> -t
 ./change_sys.sh -a -p <PASSWORD>
"
	exit
}


function get_standby (){
	export ORACLE_SID=${1}

	fal_server=(`${ORACLE_HOME}/bin/sqlplus -s / as sysdba <<-EOF
		set heading off pages 0 feedb off veri off echo off
		select replace(upper(value),' ','')
		from v\\$parameter
		where name='fal_server';
		exit
	EOF`)

	fal_server_list=($(echo ${fal_server} | sed 's/,/ /g'))

	if [[ ! -z ${fal_server} ]];then
		standby=true

		for f in ${fal_server_list[@]};do
			stby_nodes=(  )

			counter=0
			for n in ${stby_nodes[@]};do
				((counter++))
				standby_nodes[${f}${counter}]=${n}
			done

			standby_node_count[${f}]=${counter}

			stby_dbun=(`${ORACLE_HOME}/bin/sqlplus -s / as sysdba <<-EOF
				set heading off pages 0 feedb off veri off echo off
				select replace(replace(upper(value),' ','#'),'"','')
				from v\\$parameter
				where upper(value) like '%${f}%'
				and name not in ('fal_server','log_archive_config');
				exit
			EOF`)

			standby_dbuns[${f}]=$(echo ${stby_dbun} | awk -F# '{FS="[()]+";for(i=1;i<=NF;i++) if($i ~ /(DB_UNIQUE_NAME)/) print $i}' | awk -F= '{ print $NF }' )


			standby_oracle_homes[${f}]=$(ssh ${ssh_ops} oracle@${standby_nodes[${f}1]} "cat \$(awk -F= '/inventory/ { print \$2 }' /etc/oraInst.loc)/ContentsXML/inventory.xml | awk '/HOME NAME/ && /db/ {print \$3}' | awk -F\\\" '{print \$2}' | grep -v agent | sort | tail -1")

			stby_inst=(`ssh ${ssh_ops} oracle@${standby_nodes[${f}1]} <<-EOF
				${standby_oracle_homes[${f}]}/bin/srvctl config database -d ${standby_dbuns[${f}]} | grep "Database instance" | sed 's/,/  /g' | sed 's/^.*://'
				exit
			EOF`)

			for i in $(seq 1 ${counter});do
				for s in ${stby_inst[@]};do
					inst=$(ssh ${ssh_ops} oracle@${standby_nodes[${f}${i}]} "ls -l ${standby_oracle_homes[${f}]}/dbs/orapw${s} 2>/dev/null | wc -l")
					if [[ ${inst} -gt 0 ]];then
						standby_instances[${f}${i}]=${s}
					fi
				done
			done
		done
	fi
}


function pwd_change () {

	export ORACLE_SID=${1}

	temp_pass=$(cat /dev/urandom | tr -dc 'a-zA-Z' | fold -w 1 | head -n 1)$(cat /dev/urandom | tr -dc '0-9' | fold -w 1 | head -n 1)$(cat /dev/urandom | tr -dc '#$&@*?' | fold -w 1 | head -n 1)$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 9 | head -n 1)

	dbun=(`${db_home}/bin/sqlplus -s / as sysdba <<-EOF
		set heading off pages 0 feedb off veri off echo off
		select value
		from v\\$parameter
		where name='db_unique_name';
		exit
	EOF`)

	get_standby ${ORACLE_SID}

	db_role=$(${db_home}/bin/srvctl config database -d ${dbun} | awk -F: '/role/ {print $2}' | sed 's/ //g')

	if ${monthly} && [[ ${db_role} == "PHYSICAL_STANDBY" ]];then
		exit
	fi

	users=( SYS )

	if ${monthly};then
		users+=" SYSTEM"
	fi

	for u in ${users[@]};do
		if [[ "${change}" == "prompt" ]];then
			${db_home}/bin/sqlplus -s / as sysdba <<-EOF
				alter user ${u} identified by "${new_pw}";
			EOF
		elif [[ "${change}" == "temp" ]];then
			${db_home}/bin/sqlplus -s / as sysdba <<-EOF
				alter user ${u} identified by "${temp_pass}";
			EOF

			echo "SYS password has been set to ${temp_pass}"
			echo ""
		fi
	done

	if ${standby};then
		for f in ${fal_server_list[@]};do
			inst_standby=(`ssh -q oracle@${standby_nodes[${f}1]} ${standby_oracle_homes[${f}]}/bin/srvctl config database -d ${standby_dbuns[${f}]} | awk -F: '/Database instance/ { print $NF }' | sed 's/,/ /g'`)
			for s in ${inst_standby[@]};do
				for n in $(seq 1 ${standby_node_count[${f}]});do
					inst=$(ssh -q ${standby_nodes[${f}${n}]} ls -l ${standby_oracle_homes[${f}]}/dbs/orapw${s} 2>/dev/null | wc -l )
					if [[ ${inst} -gt 0 ]];then
						standby_inst[${n}]=${s}
					fi
				done
			done

			for n in $(seq 1 ${standby_node_count[${f}]});do
				echo "Copying password file ${db_home}/dbs/orapw${ORACLE_SID} to ${standby_oracle_homes[${f}]}/dbs/orapw${standby_instances[${f}${n}]} on ${standby_nodes[${f}${n}]}"
				scp -q ${db_home}/dbs/orapw${ORACLE_SID} oracle@${standby_nodes[${f}${n}]}:${standby_oracle_homes[${f}]}/dbs/orapw${standby_instances[${f}${n}]}
			done
		done
	fi

	inst_primary=(`${db_home}/bin/srvctl config database -d ${dbun} | awk -F: '/Database instance/ { print $NF }' | sed 's/,/ /g'`)
	for i in ${inst_primary[@]};do
		for n in ${primary_nodes[@]};do
			if [[ ${n} != ${hn} ]];then
				inst=$(ssh -q ${n} ls -l ${db_home}/dbs/init${i}.ora 2>/dev/null | wc -l )
				if [[ ${inst} -gt 0 ]];then
					primary_inst[${n}]=${i}
				fi
			else
				primary_inst[${n}]=${ORACLE_SID}
			fi
		done
	done

}


###############################
# Script Start
###############################

monthly=false

if [[ "$1" != "-i" ]] && [[ "$1" != "-a" ]];then
	error
elif [[ "$1" == "-i" ]] && [[ $# -ge 3 ]];then
	while [[ $# -gt 0 ]];do
		case $1 in
			-i)
					instance_name=$2
					all=false
					valid_instance=$(ps aux | grep pmon | grep ${instance_name} | egrep -v "grep|prw|ASM|MGMT" | wc -l)

					if [[ ${valid_instance} -eq 0 ]];then
						error
					fi

					shift
					;;
			-p)
					if [[ -z $2 ]];then
						error
					else
						new_pw=$2
						change="prompt"
						shift
					fi
					;;
			-t)
					change="temp"
					;;
			-m)
					monthly=true
					;;
			*)
					error
					;;
		esac
		shift
	done
elif [[ "$1" == "-a" ]] && [[ $# -ge 2 ]];then
	all=true
	shift
	while [[ $# -gt 0 ]];do
		case $1 in
			-p)
					if [[ -z $2 ]];then
						error
					else
						new_pw=$2
						change="prompt"
						shift
					fi
					;;
			-t)
					change="temp"
					;;
			-m)
					monthly=true
					;;
			*)
					error
					;;
		esac
		shift
	done
else
	error
fi

variable_declaration

if ${all};then
	inst=(`ps aux | grep pmon | egrep -v "grep|prw|ASM|MGMT" | awk '{ print $NF }' | awk -F_ '{ print $NF }'`)
	for instance_name in ${inst[@]};do
		pwd_change ${instance_name}
	done
else
	pwd_change ${instance_name}
fi
