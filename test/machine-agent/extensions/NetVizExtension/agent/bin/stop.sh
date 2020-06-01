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
LOG_DIR=logs

# make NPM_ROOT_DIR absolute
NPM_ROOT_DIR="`cd "$NPM_ROOT_DIR"; pwd`"
PKG_NAME=appd-netviz

LOG_FILE="$NPM_ROOT_DIR/$LOG_DIR/install.log"

# Log the provided message to the log file
# Log format - Script name: Time: Level: Message
log() {
        echo "${0##*/}: $(date): $1" >> $LOG_FILE
}

log "INFO: Running command: $NPM_ROOT_DIR/bin/${PKG_NAME}.sh stop"
$NPM_ROOT_DIR/bin/${PKG_NAME}.sh stop
