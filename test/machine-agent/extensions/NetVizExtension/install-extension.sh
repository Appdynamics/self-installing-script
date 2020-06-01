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

# determine netviz extension home
NETVIZ_EXTENSION_HOME="`dirname "$SCRIPT"`"

# Make netviz extension home absolute
NETVIZ_EXTENSION_HOME="`cd "$NETVIZ_EXTENSION_HOME"; pwd`"

NETVIZ_INSTALL_SCRIPT="$NETVIZ_EXTENSION_HOME/agent/install.sh"
INSTALL_EXT_LOG="$NETVIZ_EXTENSION_HOME/agent/logs/install-extension.log"

LIB_DIR="$NETVIZ_EXTENSION_HOME/lib"

check_install() {
	# Check if extension install log exists
	if [ -e "$INSTALL_EXT_LOG" ]; then
		if [ "$LIB_DIR" -nt "$INSTALL_EXT_LOG" ]; then
			return 1
		fi
		grep "Installation-Status: Successfull" $INSTALL_EXT_LOG > /dev/null 2>&1
		if [ $? -ne 0 ]; then
			return 1
		fi
		grep "Extension-Home: \[$NETVIZ_EXTENSION_HOME\]" $INSTALL_EXT_LOG > /dev/null 2>&1
		if [ $? -ne 0 ]; then
			return 1
		fi
		echo "Skipping NetViz Extension installation since already installed"
		return 0
	fi
	return 1
}

check_perm() {
	# Check that the script is run as root
	if [ "$(id -u)" != "0" ]; then
		echo "Installation-Status: Failed" > $INSTALL_EXT_LOG
		echo "Skipping NetViz Extension installation. Needs root or sudo." >> $INSTALL_EXT_LOG
		echo "Skipping NetViz Extension installation. Needs root or sudo."
		chmod 644 $INSTALL_EXT_LOG
		exit 100
	fi
}

do_install() {
	/bin/bash $NETVIZ_INSTALL_SCRIPT
	retval=$?
	if [ $retval -ne 0 ]; then
		sed -i -e "s:start\:.*:start\: false:g" "$NETVIZ_EXTENSION_HOME/conf/netVizExtensionConf.yml"
		echo "Installation-Status: Failed" > $INSTALL_EXT_LOG
		echo "Exit-Code: $retval" >> $INSTALL_EXT_LOG
		chmod 644 $INSTALL_EXT_LOG
		exit $retval
	fi

	sed -i -e "s:start\:.*:start\: true:g" "$NETVIZ_EXTENSION_HOME/conf/netVizExtensionConf.yml"
	echo "Installation-Status: Successfull" > $INSTALL_EXT_LOG
	echo "Extension-Home: [$NETVIZ_EXTENSION_HOME]" >> $INSTALL_EXT_LOG
	chmod 644 $INSTALL_EXT_LOG
}


usage() {
	echo "Usage: $0 [-h] [-c]"
	echo "Checks NetVizExtension installation and installs if required."
	echo "Installation of NetVizExtension requires root privilege and no option."
	echo "    -c           Only check NetVizExtension installation. If this option"
	echo "		   is present then NetVizExtension is not installed."
	echo "    -h"
}

OPTSTRING='hc'

while getopts "$OPTSTRING" OPTION $ARGV; do
	case "$OPTION" in
		c)
			check_install
			if [ $? -ne 0 ]; then
				echo "NetVizExtension not installed."
				exit 1
			fi
			echo "NetVizExtension already installed."
			exit 0
			shift
		;;
		h)
			usage
			exit 0
		;;
		*)
			echo "Error parsing argument $1!" >&2
			usage
			exit 1
		;;
	esac
done
check_install

if [ $? -ne 0 ]; then
	check_perm
	do_install
fi
exit 0
