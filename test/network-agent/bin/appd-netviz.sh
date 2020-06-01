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

AGENT_BINNAME=appd-netagent
AGENT_BIN=${NPM_ROOT_DIR}/bin/${AGENT_BINNAME}
DAEMON_NAME=appd-netmon
DAEMON=${NPM_ROOT_DIR}/bin/${DAEMON_NAME}
DAEMON_OPTS="-r ${NPM_ROOT_DIR}/"
PKG_NAME=appd-netviz
DESC="AppDynamics Network Monitoring"
RUN_DIR=${NPM_ROOT_DIR}/run
LOG_DIR=${NPM_ROOT_DIR}/logs
PID_FILE=${RUN_DIR}/${DAEMON_NAME}.pid
NETCTL_FILE=${RUN_DIR}/appd-netctl.sock
NETLIB_FILE=${RUN_DIR}/appd-netlib.sock
NETMON_LOG=${LOG_DIR}/appd-netmon.log.0
NETAGENT_LOG=${LOG_DIR}/appd-netagent.log.0
LOG_FILE=${LOG_DIR}/install.log
npm_pid=$(/bin/ps -ef | grep "$DAEMON_NAME" | grep -v grep | awk '{ print $2 }')

# Error Exit codes
SUCCESS=0
AGENT_ALREADY_RUNNING=1
AGENT_NOT_RUNNING=2
AGENT_FAILED_TO_START=3
AGENT_FAILED_TO_STOP=4
AGENT_NO_PERMISSION=5
UNDEFINED_ARG=10

# Log the provided message to the log file
# Log format - Script name: Time: Level: Message
log() {
	echo "${0##*/}: $(date): $1" >> $LOG_FILE
}

# Echo message to user and log the message to the log file.
echo_and_log() {
	echo "$1"
	log "$1"
}

# Check if any of $pid (could be plural) are running
checkpid() {
	local i
	for i in $* ; do
		[ -d "/proc/$i" ] && return 0
	done

	return 1
}

__pids_pidof() {
	pidof -c -o $$ -o $PPID -o %PPID -x "$1" || \
		pidof -c -o $$ -o $PPID -o %PPID -x "${1##*/}"
}

# Checks whether appd-netagent has permissions
# Returns 1 if appd-netagent has permissions
# Returns 0 if appd-netagent doesn't have permissions
has_permissions() {
	# Check if the file has setuid set.
	if [ -u $AGENT_BIN ] ; then
		echo_and_log "INFO: running with setuid set for the agent"
		return 1
	fi

	# Check if the root is executing.
	if [ "$(id -u)" -eq "0" ]; then
		echo_and_log "WARN: running as root"
		return 1
	fi

	# Make sure capabilities are set in the binary
	capabilities="$(getcap -v $AGENT_BIN)"

	echo "$capabilities" | grep -ie 'cap_net_raw\|cap_net_admin\|cap_net_bind_service' > /dev/null
	if [ $? -ne 0 ]; then
		echo_and_log "ERROR: capabilities for capture are not set for the agent"
		return 0
	fi

	echo_and_log "INFO: running with capabilities set for the agent"
	return 1
}

# Checks whether npm is running or not.
# Returns 1 if npm is running.
# Returns 0 if npm is not running.
is_npm_running() {
	local pid

	# Check using pid file.
	if [ -f ${PID_FILE} ]; then
		pid=$(cat ${PID_FILE})
		if checkpid $pid 2>&1; then
			return 1
		fi
	fi

	# Check using __pids_pidof
	pid="$npm_pid"
	if [ -n "$pid" ]; then
		return 1
	fi

	return 0
}

get_npm_pid() {
	local pid

	# Check using pid file.
	if [ -f ${PID_FILE} ]; then
		pid=$(cat ${PID_FILE})
		if checkpid $pid 2>&1; then
			echo $pid
			return
		fi
	fi

	# Check using __pids_pidof
	pid="$npm_pid"
	if [ -n $pid ]; then
		echo $pid
		return
	fi
}

cleanup()
{
	rm -f ${NETCTL_FILE} ${NETLIB_FILE} >/dev/null 2>&1
}

#
# Function that starts the daemon/service
#
do_start()
{
	# Don't start if npm doesn't have permissions
	has_permissions
	if [ $? -eq 0 ]; then
		echo_and_log "ERROR: Netviz agent does not have required permissions. Run install.sh script as root or sudo"
		exit $AGENT_NO_PERMISSION
	fi

	# Don't start if npm is already running
	is_npm_running
	if [ $? -eq 1 ]; then
		echo_and_log "INFO: ${DESC} ${PKG_NAME} already running"
		exit $AGENT_ALREADY_RUNNING
	fi

	cleanup

	echo_and_log "INFO: Starting ${DESC} ${PKG_NAME}..."
	/bin/bash -c "$DAEMON $DAEMON_OPTS"
	if [ "$?" -eq 0 ]; then
		sleep 5
		is_npm_running
		if [ $? -eq 1 ]; then
			echo_and_log "INFO: ${PKG_NAME} running.. ${pid}"
		else
			echo_and_log "ERROR: Failed to start ${DESC} ${PKG_NAME}. Check ${NETMON_LOG} and ${NETAGENT_LOG} for more details"
			exit $AGENT_FAILED_TO_START
		fi
	else
		echo_and_log "ERROR: Failed to start ${DESC} ${PKG_NAME}. Check ${NETMON_LOG} and ${NETAGENT_LOG} for more details"
		exit $AGENT_FAILED_TO_START
	fi
}

#
# Function that stops the daemon/service
#
do_stop()
{
	# Don't start if npm is already running
	is_npm_running
	if [ $? -eq 0 ]; then
		echo_and_log "INFO: ${DESC} ${PKG_NAME} is not running"
		exit $AGENT_NOT_RUNNING
	fi

	if [ -f ${PID_FILE} ]; then
		pid=$(cat ${PID_FILE})
	else
		pid="$npm_pid"
	fi

	echo_and_log "INFO: Stopping ${DESC} ${PKG_NAME}..."

	if checkpid $pid 2>&1; then
		# TERM first, then KILL if not dead
		kill -TERM $pid >/dev/null 2>&1
		sleep 1
		if checkpid $pid ; then
			try=0
			while [ $try -lt 5 ] ; do
				checkpid $pid || break
				sleep 1
				try=$(($try+1))
			done
			if checkpid $pid ; then
				kill -KILL $pid >/dev/null 2>&1
				sleep 1
			fi
		fi
	fi
	checkpid $pid
	RC=$?
	if [ "$RC" -eq 0 ]; then
		echo_and_log "ERROR: Failed to stop ${DESC} ${PKG_NAME}"
		exit $AGENT_FAILED_TO_STOP
	else
		echo_and_log "INFO: Stopped"
		cleanup
	fi
}

do_status()
{
	if is_npm_running == 0; then
		echo_and_log "${DESC} ${PKG_NAME} is stopped"
	else
		echo_and_log "${DESC} ${PKG_NAME} is running"
	fi
}

cmd=$1
if [ $# -gt 0 ]; then
	shift 1
fi

OPTSTRING='hp:'

usage()
{
	echo "Usage: $0 {start|stop|status|restart} [-p pid]"
	echo "The first argument is always one of the 4 key words defined"
	echo "above. Use them to start, stop, restart or find the status"
	echo "-p		appd-netmon will monitor the process with"
	echo "  		given pid and will exit when this process"
	echo "  		stops."
}

while getopts "$OPTSTRING" OPTION $ARGV; do
	case "$OPTION" in
		p)
			DAEMON_OPTS="$DAEMON_OPTS -p $OPTARG"
			;;
		h)
			usage
			exit $SUCCESS
			;;
		*)
			usage
			exit $UNDEFINED_ARG
			;;
	esac
done

# Log the Netviz Agent root directory where the script are being run from
# Also log the Netviz Agent version in the log file
log "INFO: Running appd-netviz.sh script in ${NPM_ROOT_DIR}"
log "INFO: $(${AGENT_BIN} -v)"
case "$cmd" in
	start)
		log "INFO: Running start script"
		do_start
		;;
	stop)
		log "INFO: Running stop script"
		do_stop
		;;
	status)
		log "INFO: Running status script"
		do_status
		;;
	restart)
		log "INFO: Running restart script"
		$0 stop
		sleep 1
		$0 start
		;;
	*)
		usage
		exit $UNDEFINED_ARG
		;;
esac

exit $SUCCESS
