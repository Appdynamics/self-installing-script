#!/bin/sh

# Setup PATH environment variable to have paths required by our scripts.
PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:

SCRIPT="$0"
AGENT_NAME=appd-netagent
AGENT=bin/$AGENT_NAME
CONF_DIR=conf/
LOG_DIR=logs/
normal_user=false

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
NPM_ROOT_DIR="`dirname "$SCRIPT"`"

# make NPM_ROOT_DIR absolute
NPM_ROOT_DIR="`cd "$NPM_ROOT_DIR"; pwd`"

AGENT="$NPM_ROOT_DIR/$AGENT"
AGENT_CONF_FILE="$NPM_ROOT_DIR/$CONF_DIR/agent_config.lua"
LOG_FILE="$NPM_ROOT_DIR/$LOG_DIR/install.log"
AGENT_METADATA_FILE="$NPM_ROOT_DIR/agent_metadata"

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

fail_installation() {
	echo_and_log "ERROR: Installation failed"
	exit 1
}

# Run a command and check whether its successful or not.
run_cmd() {
	"$@" | tee -a $LOG_FILE
	if [ $? -ne 0 ]; then
		echo_and_log "ERROR: Command failed: $@"
		fail_installation
	fi
}

# check the libc version of the binary as compare the system's default
# version.
check_libc() {
	MAX_SUPPORTED_VER="$(getconf GNU_LIBC_VERSION | cut -d' ' -f 2)"
	MAX_SUPPORTED_MAJ_VER="$(echo $MAX_SUPPORTED_VER | cut -d'.' -f 1)"
	MAX_SUPPORTED_MIN_VER="$(echo $MAX_SUPPORTED_VER | cut -d'.' -f 2)"

	MAJ_VER="$(grep GLIBC_MAJ_VER $AGENT_METADATA_FILE | cut -d "=" -f 2)"
	MIN_VER="$(grep GLIBC_MIN_VER $AGENT_METADATA_FILE | cut -d "=" -f 2)"
	VER="$MAJ_VER.$MIN_VER"

	if echo "$MAJ_VER $MAX_SUPPORTED_MAJ_VER $MIN_VER $MAX_SUPPORTED_MIN_VER" | awk '{exit $1>$2||$3>$4?0:1}'; then
		echo_and_log "ERROR: This package of NetViz agent requires minimum $VER version of the GLIBC on this system ($MAX_SUPPORTED_VER)."
		fail_installation
	fi
}

# Checks that the user running the script has root privileges.
check_user() {
	# Check that the script is run as root
	if [ "$(id -u)" != "0" ]; then
		echo_and_log "ERROR: This script must be run as sudo or root"
		fail_installation
	fi
}

# Common function to print errors found in mount directory where
# network agent is installed.
print_mount_error() {
	echo_and_log "ERROR: Filesystem where NetViz agent is getting installed should not have 'noexec' or 'nosuid' flags enabled."
	echo_and_log "ERROR: Use 'mount' command to see more details."
	echo_and_log "ERROR: Mount point $1 has noexec or nosuid flag set"
}

# Check that the mount point where agent is unzipped does not have
# noexec and nosuid flags
check_mount() {
	# Get mount point
	mnt_pt="$(df -P $AGENT | tail -1 | awk '{ print $6 }')"

	# Check for noexec flag on the mount point
	mount | grep "on\s\+$mnt_pt\s\+.*\<noexec\>.*" > /dev/null 2>&1
	if [ $? -eq 0 ]; then
		print_mount_error $mnt_pt
		fail_installation
	fi

	# Check for nosuid flag on the mount point
	mount | grep "on\s\+$mnt_pt\s\+.*\<nosuid\>.*" > /dev/null 2>&1
	if [ $? -eq 0 ]; then
		print_mount_error $mnt_pt
		fail_installation
	fi
}

# Set file permissions on binaries
do_perm() {
	file=$AGENT
	if which setcap > /dev/null 2>&1; then
		echo_and_log "INFO: Setting capabilities on $file"
		run_cmd chmod u=rwx,g=rx,o=rx $file
		if ! setcap cap_net_raw,cap_net_admin,cap_net_bind_service=eip $file > /dev/null 2>&1; then
			echo_and_log "ERROR: Setting capabilities for $file failed."
			echo_and_log "INFO: Falling back to setting set-user-id bit."
			chown root $file
			chmod u=rwxs,g=rx,o=rx $file
		fi
	else
		echo_and_log "INFO: Setting set-user-id on $file"
		run_cmd chown root $file
		run_cmd chmod u=rwxs,g=rx,o=rx $file
	fi
}

# Set file permissions on binaries for non-root user.
# All the privileged commands need to be run with sudo.
do_perm_normal_user() {
	file=$AGENT
	if which setcap > /dev/null 2>&1; then
		echo_and_log "INFO: Setting capabilities on $file"
		run_cmd sudo chmod u=rwx,g=rx,o=rx $file
		if ! sudo setcap cap_net_raw,cap_net_admin,cap_net_bind_service=eip $file > /dev/null 2>&1; then
			echo_and_log "ERROR: Setting capabilities for $file failed."
			echo_and_log "ERROR: Falling back to setting set-user-id bit."
			run_cmd sudo chown root $file
			run_cmd sudo chmod u=rwxs,g=rx,o=rx $file
		fi
	else
		echo_and_log "INFO: Setting set-user-id on $file"
		run_cmd sudo chown root $file
		run_cmd sudo chmod u=rwxs,g=rx,o=rx $file
	fi
}

# Make configuration file changes
do_config_change() {
	run_cmd sed -i -e "s:ROOT_DIR=.*:ROOT_DIR=\"$NPM_ROOT_DIR\":g" $AGENT_CONF_FILE
}

while getopts u OPTION; do
	case "$OPTION" in
		u)
			normal_user=true
			;;
		*)
			;;
	esac
done

# Make sure the log file has 444 permissions. This is needed because
# the install script is run as sudo but the start/stop scripts are
# run as regular user. All scripts write to the same log file
if [ ! -f $LOG_FILE ]; then
	touch $LOG_FILE
	chmod 666 $LOG_FILE
fi

check_libc
check_mount
if [ "$normal_user" = true ]; then
	do_perm_normal_user
else
	check_user
	do_perm
fi

do_config_change

echo_and_log "INFO: Installation successful"

exit 0
