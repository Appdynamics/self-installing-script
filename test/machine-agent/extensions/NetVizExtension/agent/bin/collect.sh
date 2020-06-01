#!/bin/sh

# Setup PATH environment variable to have paths required by our scripts.
PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:

SCRIPT="$0"

# SCRIPT may be an arbitrarily deep series of symlinks.
# Loop until we have the concrete path.
while [ -h "$SCRIPT" ] ; do
	ls=`ls -ld "$SCRIPT"`
	# Drop everything prior to ->
	link=`expr "$ls" : '.*-> \(.*\)$'`
	if expr "$link" : '/.*' > /dev/null; then
		SCRIPT="$link"
	else
		SCRIPT=`dirname "$SCRIPT"`/"$link"
	fi
done

# determine npm root directory
NPM_ROOT_DIR="`dirname "$SCRIPT"`/.."

# make NPM_ROOT_DIR absolute
NPM_ROOT_DIR="`cd "$NPM_ROOT_DIR"; pwd`"
NPM_LOG_DIR="${NPM_ROOT_DIR}/logs"
NPM_BIN_DIR="${NPM_ROOT_DIR}/bin"
NPM_CONF_DIR="${NPM_ROOT_DIR}/conf"
NPM_HOME_DIR="${NPM_ROOT_DIR}/home/"

NPM_AGENT_FILE="$NPM_BIN_DIR/appd-netagent"

# Destination folder where to store all the collected logs
DEST="`pwd`"
DEST_NAME=""
DEST_DIR=""

# Option Flags
COLLECT_METRICS=1
COLLECT_NETCTL=1
CREATE_ZIP=0

# Time for collecting
TIME_TO_SLEEP=100
DO_SLEEP=0


HOSTNAME=$(hostname)
TIME=$(date +%s)
LOG_SUFFIX="$TIME"

# Netctl log file
NETCTL_LOG_NAME="netctl.log.$LOG_SUFFIX"
NETCTL_LOG_PATH="$NPM_LOG_DIR/$NETCTL_LOG_NAME"
NETCTL_PATH="$NPM_BIN_DIR/netctl"
NETCTL_DUMP_COUNT=10
NETCTL_DUMP_TMO=10

# System info log file
SYSTEM_LOG_NAME="system.info.$LOG_SUFFIX"
SYSTEM_LOG_PATH="$NPM_LOG_DIR/$SYSTEM_LOG_NAME"

PID_NETAGENT="`pidof appd-netagent`"

NETAGENT_OWNER="`ls -ld $NPM_AGENT_FILE | awk '{print $3}' `"
PROCESS_OWNER_CMD="ps aux | grep appd-netagent | grep -v grep | awk '{if(\$2 == $PID_NETAGENT) {print \$1;}}'"
PROCESS_OWNER=""
SCRIPT_EXECUTER="`id -u -n`"


IS_ROOT="`id -u`"

MASK_IP=1

OPTSTRING='hp:t:mzni'
usage () {
	echo "This script is used for collecting debug data for netagent."
	echo "Usage: $0 [-h] [-p path] [-m] [-t time] [-z] [-n]"
	echo "-h		print command line options"
	echo "-p		path for storing the collected data"
	echo "-m		skip metric collection"
	echo "-n		skip netctl counters collection"
	echo "-t		time (in secs) for collecting metric data."
	echo "  		defaults to 100 secs "
	echo "-z		create a zip file for collected data. by"
	echo "  		default creates a tar file"
	echo "-i		doesn't mask the ip address in system info."
	echo "  		default masks the ip address"
}

# Creates the dir where to move all the debug info
_create_dest_dir() {
	mkdir $DEST_DIR
	if [ $? -eq 0 ]; then
		echo "Starting log collection in dir: ${DEST_DIR}"
	else
		echo "The dest directory can't be created. Exiting"
		exit 1
	fi
}

# Trigger start or stop of metric dumping in metric log file.
# Sudo/root privilege is required
_trigger_metrics_log() {
	echo "Signalling metric dump $1 in netagent"
	kill -USR1 $PID_NETAGENT
	if [ $? -ne 0 ]; then
		echo "Issues collecting the metrics. Check permissions."
		exit 1
	fi
	DO_SLEEP=1
}

_dump_nectl_logs_helper() {
	echo "Dumping netctl logs count $1"
	echo "-----------[$1]-----------" >> $NETCTL_LOG_PATH
	echo "Time `date +%s`" >> $NETCTL_LOG_PATH

	$NETCTL_PATH -a core >> $NETCTL_LOG_PATH
	$NETCTL_PATH -a adns >> $NETCTL_LOG_PATH
	$NETCTL_PATH -a ipcache >> $NETCTL_LOG_PATH
	$NETCTL_PATH -a host >> $NETCTL_LOG_PATH
	$NETCTL_PATH -a webserver >> $NETCTL_LOG_PATH
	$NETCTL_PATH -a net.fg.stats >> $NETCTL_LOG_PATH
	$NETCTL_PATH -a net.flow >> $NETCTL_LOG_PATH

	echo "------------------------" >> $NETCTL_LOG_PATH
}

_mask_ip() {
	if [ $MASK_IP -eq 1 ]; then
		sed -r 's/[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/xx.xx.xx.xx/g' $1
	else
		echo $1
	fi
}

_dump_system_info() {
	echo "Dumping system info"

	echo "----------[uname]---------" >> $SYSTEM_LOG_PATH
	uname -a >> $SYSTEM_LOG_PATH
	echo "--------------------------" >> $SYSTEM_LOG_PATH

	echo "Identifying resource"
	find /etc/ -maxdepth 1  -name "*-release" 2>/dev/null | while read line; do
		echo "----------[$line]---------" >> $SYSTEM_LOG_PATH
		cat $line >> $SYSTEM_LOG_PATH
		echo "--------------------------" >> $SYSTEM_LOG_PATH
	done

	echo "----------[stat]---------" >> $SYSTEM_LOG_PATH
	stat $NPM_ROOT_DIR >> $SYSTEM_LOG_PATH
	echo "--------------------------" >> $SYSTEM_LOG_PATH

	echo "--------[ifconfig]--------" >> $SYSTEM_LOG_PATH
	ifconfig | _mask_ip >> $SYSTEM_LOG_PATH
	echo "--------------------------" >> $SYSTEM_LOG_PATH

	echo "---------[netstat]--------" >> $SYSTEM_LOG_PATH
	netstat -a | _mask_ip >> $SYSTEM_LOG_PATH
	echo "--------------------------" >> $SYSTEM_LOG_PATH

	echo "---------[resolv.conf]--------" >> $SYSTEM_LOG_PATH
	cat /etc/resolv.conf >> $SYSTEM_LOG_PATH
	echo "--------------------------" >> $SYSTEM_LOG_PATH

	echo "-------------[ls]---------" >> $SYSTEM_LOG_PATH
	ls -ltRh $NPM_ROOT_DIR >> $SYSTEM_LOG_PATH
	echo "--------------------------" >> $SYSTEM_LOG_PATH

	echo "-----------[ps aux]-------" >> $SYSTEM_LOG_PATH
	ps aux | grep appd-net | grep -v grep  >> $SYSTEM_LOG_PATH
	echo "--------------------------" >> $SYSTEM_LOG_PATH

	echo "-----------[/proc/meminfo]-------" >> $SYSTEM_LOG_PATH
	cat /proc/meminfo >> $SYSTEM_LOG_PATH
	echo "--------------------------" >> $SYSTEM_LOG_PATH

	pid_stat_file="/proc/$PID_NETAGENT/stat"
	echo "-----------[$pid_stat_file]-------" >> $SYSTEM_LOG_PATH
	if [ "$PID_NETAGENT" = "" ]; then
		echo "Network Agent not running" >> $SYSTEM_LOG_PATH
	else
		cat $pid_stat_file >> $SYSTEM_LOG_PATH
	fi
	echo "--------------------------" >> $SYSTEM_LOG_PATH

}

_sleep() {
	echo "Sleeping for $1"
	sleep $1
	echo "Waking up from sleep"
}

_collect_logs() {
	echo "Collecting netagent logs"
	cp -r $NPM_LOG_DIR $DEST_DIR
}

_collect_conf() {
	echo "Collecting netagent conf"
	cp -r $NPM_CONF_DIR $DEST_DIR
}

_collect_home() {
	echo "Collecting netagent home"
	cp -r $NPM_HOME_DIR $DEST_DIR
}

_create_tar() {
	TAR_FILE="${DEST_NAME}.tar"
	echo "Compressing the collected files into tar ${TAR_FILE}"
	echo "Loc of tar ${DEST}/${TAR_FILE}"
	cd $DEST && tar -cvf $TAR_FILE $DEST_NAME 1>/dev/null
}

_create_zip() {
	ZIP_FILE="${DEST_NAME}.zip"
	echo "Compressing the collected files into a zip"
	echo "Loc of zip ${DEST}/${ZIP_FILE}"
	cd $DEST && zip -r $ZIP_FILE $DEST_NAME 1>/dev/null
}

# Add check for netagent running
_validate_options() {
	if [ $COLLECT_METRICS -eq 1 ] || [ $COLLECT_NETCTL -eq 1 ]; then
		if [ "$PID_NETAGENT" = "" ]; then
			echo "No process found. Metric/Netctl collection" \
			    "will not happen."
			COLLECT_METRICS=0
			COLLECT_NETCTL=0
		fi
	fi

	if [ $COLLECT_METRICS -eq 1 ]; then
		if [ "$IS_ROOT" = "0" ] || [ "$PROCESS_OWNER" = "$SCRIPT_EXECUTER" ]; then
			return
		fi
		echo "For metric logging, user running the script" \
		    "should be root or same as the owner of" \
		    "appd-netagent."
		COLLECT_METRICS=0
	fi
}

_run_tasks() {
	if [ "$PID_NETAGENT" != "" ]; then
		PROCESS_OWNER=`eval $PROCESS_OWNER_CMD`
	fi

	_validate_options

	_create_dest_dir

	if [ $COLLECT_METRICS -eq 1 ]; then
		echo "Collecting metric dump in netagent"
		_trigger_metrics_log "start"
	fi

	_dump_system_info

	if [ $COLLECT_NETCTL -eq 1 ]; then
		count=0
		while [ $count -le $NETCTL_DUMP_COUNT ]
		do
			_dump_nectl_logs_helper $count
			count=`expr $count + 1`
			_sleep $NETCTL_DUMP_TMO
			TIME_TO_SLEEP=`expr $TIME_TO_SLEEP - $NETCTL_DUMP_TMO`
		done
	fi

	if [ $DO_SLEEP -eq 1 ] && [ $TIME_TO_SLEEP -gt 0 ]; then
		_sleep $TIME_TO_SLEEP
	fi

	if [ $COLLECT_METRICS -eq 1 ]; then
		_trigger_metrics_log "stop"
	fi

	_collect_logs
	_collect_conf
	_collect_home

	if [ $CREATE_ZIP -eq 1 ]; then
		_create_zip
	else
		_create_tar
	fi

	echo "Removing temp files and dir created while collecting."
	rm -f $SYSTEM_LOG_PATH
	rm -f $NETCTL_LOG_PATH
	rm -rf $DEST_DIR
}

while getopts "$OPTSTRING" OPTION $ARGV; do
	case "$OPTION" in
		p)
			DEST=$OPTARG
			;;
		h)
			usage
			exit 0
			;;
		m)
			COLLECT_METRICS=0
			;;
		n)
			COLLECT_NETCTL=0
			;;
		t)
			TIME_TO_SLEEP=$OPTARG
			NETCTL_DUMP_COUNT=`expr $TIME_TO_SLEEP / $NETCTL_DUMP_TMO`
			;;
		z)
			CREATE_ZIP=1
			;;
		i)
			MASK_IP=0
			;;
		*)
			exit 1
			;;
	esac
done

DEST="`cd "$DEST"; pwd`"
DEST_NAME="collect-${HOSTNAME}-${TIME}"
DEST_DIR="${DEST}/${DEST_NAME}/"

_run_tasks