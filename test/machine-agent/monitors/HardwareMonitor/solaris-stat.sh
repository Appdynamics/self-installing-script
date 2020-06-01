#!/usr/bin/bash
#
# Monitors CPU, Memory, Network and Disks on Solaris
#
# version 2.21
#
#########################################
#
# depends on:
# 	awk nawk tail egrep grep date cat tr sed df sleep perl
#	vmstat zonename kstat iostat netstat zpool pagesize
#
# Copyright (c) AppDynamics, Inc., and its affiliates, 2014, 2015
# All Rights Reserved
# THIS IS UNPUBLISHED PROPRIETARY CODE OF APPDYNAMICS, INC.
# The copyright notice above does not evidence any
# actual or intended publication of such source code.

# Fails with the given message
fail() {
    1>&2 echo "$1"
    exit 1
}

# Outputs a warning log event to stderr
log_warn() {
    1>&2 echo "event-type=MACHINE_AGENT_LOG, severity=WARN, message=$1"
}

# Use NAWK to return the number of seconds since an epoch
get_nawk_timestamp() {
    # NAWK calls time(NULL) for its implementation of srand without any arguments (as described in the NAWK man page)
    nawk 'BEGIN { print srand }'
}
GET_NAWK_TIMESTAMP_CMD="get_nawk_timestamp"

# Returns 0 if NAWK timestamp is monotonically increasing. Else, returns 1. This check is needed since NAWK's
# implementation of srand could change.
check_nawk_timestamp() {
    local prev=`$GET_NAWK_TIMESTAMP_CMD`

    # Collect a few time stamps. Solaris 10 does not have the "seq" command.
    for i in 1 2 3; do
        sleep 1
        local curr=`$GET_NAWK_TIMESTAMP_CMD`
        if [ $curr -le $prev ]; then
            return 1
        fi
        prev=$curr
    done

    return 0
}
CHECK_NAWK_TIMESTAMP_CMD="check_nawk_timestamp"

# Echo the command to return the number of seconds since an epoch
DATE_CMD="date +%s"
PERL_CMD="perl"
get_timestamp_cmd() {
    # Method 1: Use date command (fastest but not supported on Solaris 10)
    local date_output=`$DATE_CMD | awk '/^[0-9]+$/ { if (NF == 1) { print "success" } }'`
    if [ $date_output ]; then
        echo "$DATE_CMD"
        return
    fi

    # Method 2: Use perl if it is available
    if "$PERL_CMD" < /dev/null > /dev/null 2>&1 ; then
        echo "$PERL_CMD -e print(time())"
        return
    fi

    # Method 3: Use NAWK if it seems to work
    if $CHECK_NAWK_TIMESTAMP_CMD ; then
        echo "$GET_NAWK_TIMESTAMP_CMD"
        return
    fi
}

# Intialize and validate command to get time stamps
GET_TIMESTAMP="`get_timestamp_cmd`"
if [ "x$GET_TIMESTAMP" = "x" ]; then
    fail "ERROR: Unable to initialize command to get time stamp"
fi

# produce a report, once per minute, which contains lots of machine statistics
#
# edit the following to enable additional reporting options
# set to 0 or 1, depending on whether you want:
# DO_DISK: detailed disk i/o
# DO_FS: fs space
# DO_BLOCKS: packets and blocks in and out
# DO_IF: detailed network interface
DO_DISK=0
DO_FS=0
DO_BLOCKS=1
DO_IF=0

PATH=/usr/bin:/usr/sbin

LOOPTIME=60

# this is how long we wait between network samples to calculate a delta.
SAMPLE=10

main() {

# these do not vary per run, so they are hoisted out of the loop

#
# we need lists network interfaces, disks: exclude zpools from disks
#
NETIFS=`netstat -i | tail +2 | grep -v ^lo0 | awk '/^$/{exit}{print de,$1;de=":"}' ORS= OFS=`
ZPOOLS=`zpool list | tail +2 | awk '{print de,$1; de="|"}' ORS= OFS=`
if [ -z "$ZPOOLS" ] ; then
	POOLFILTER=cat
else
	POOLFILTER="egrep -v $ZPOOLS"
fi
DISKS=`iostat -x | tail +3 | $POOLFILTER | awk '{print de,$1;de=":"}' ORS= OFS=`

PAGESIZE=`pagesize`
MEM_TOTAL_PAGES=`kstat -p unix::system_pages:physmem | cut -f 2`
MEM_TOTAL_MB=$(($MEM_TOTAL_PAGES * $PAGESIZE / 1048576))

# forever - body intentionally not indented
while [ 1 ]; do

NOW=`$GET_TIMESTAMP`
NEXTSECONDS=$(($NOW + $LOOPTIME))

# MEMORY usage

MEM_FREE_PAGES=`kstat -p unix::system_pages:freemem | cut -f 2`
MEM_FREE_MB=$(($MEM_FREE_PAGES * $PAGESIZE / 1048576))

#
# account for the size of the zfs arc - this is considered to be 'free' memory,
# except for the minimum arc, which can't go away due to memory pressure
# if you don't do this, free memory stays at minfree once the arc fills up.
#
ARC_SIZE=`kstat -p zfs::arcstats:size | cut -f 2`
ARC_MIN_SIZE=`kstat -p zfs::arcstats:c_min | cut -f 2`
if [ -z "$ARC_MIN_SIZE" ] ; then ARC_MIN_SIZE=0 ; fi
if [ -z "$ARC_SIZE" ] ; then ARC_SIZE=0 ; fi
#
# correct for systems without ZFS or non-warmed up ZFS
#
if [ $ARC_MIN_SIZE -gt $ARC_SIZE ] ; then
	ARC_SIZE=0
	ARC_MIN_SIZE=0
fi
ARC_MB=$((($ARC_SIZE-$ARC_MIN_SIZE) / 1048576))
MEM_FREE_MB=$(($MEM_FREE_MB + $ARC_MB))

MEM_USED_MB=$(($MEM_TOTAL_MB - $MEM_FREE_MB))
MEM_USED_PC=$((($MEM_USED_MB * 100) / $MEM_TOTAL_MB))
MEM_FREE_PC=$((100 - $MEM_USED_PC))

echo "name=Hardware Resources|Memory|Total (MB),aggregator=OBSERVATION,value="$MEM_TOTAL_MB
echo "name=Hardware Resources|Memory|Used (MB),aggregator=OBSERVATION,value="$MEM_USED_MB
echo "name=Hardware Resources|Memory|Free (MB),aggregator=OBSERVATION,value="$MEM_FREE_MB
echo "name=Hardware Resources|Memory|Used %,aggregator=OBSERVATION,value="$MEM_USED_PC
echo "name=Hardware Resources|Memory|Free %,aggregator=OBSERVATION,value="$MEM_FREE_PC

#
# this code works as follows: the first time we see a network interface
# or disk, we set seen to 2. the next time, we set it to 4.
# then, whenever we see a statistic, we subtract 3 from this magic number.
# this gives us a -1 or a 1.  this is what we multiply the statistic by
# and accumulate it.  given exactly two samples, this means that it is a
# delta between the two samples.
#
# furthermore, we iterate over all the interfaces we have, so that we sum all
# the interface rates for our final output.
#
# finally, we divide by the number of seconds between samples
#
kstat -p -T u -c "/net|disk|nfs/" $SAMPLE 2 | tr ':' ' ' | awk '

	# any line consisting of just numbers is the timestamp
	/^[0-9]+/ {
		if (seconds) { seconds += $1; } else { seconds = - $1; } next;
	}

	{
		if (!init) {
			split(NETIFS, ifs, ":");
			for (i in ifs) { real_interface[ifs[i]] = 1; }
			split(DISKS, drives, ":");
			for (d in drives) { real_disk[drives[d]] = 1; }
			init++;
		}
		name = $1;
		instance = $2;
		group = $3;
		stat = $4;
		value = $5;
	}

	stat == "class" {
		class = value;
		if (value == "disk") { device = group; diskseen[device] += 2; next; }
		if (value == "net") { device = group; netseen[device] += 2; next; }
	}

	class == "disk" && stat == "nread" { din[device] += value * (diskseen[device] - 3);}
	class == "disk" && stat == "nwritten" { dout[device] += value * (diskseen[device] - 3);}
	class == "disk" && stat == "writes" { dwrites[device] += value * (diskseen[device] - 3);}
	class == "disk" && stat == "reads" { dreads[device] += value * (diskseen[device] - 3);}

	class == "net" && stat == "opackets" { np_out[device] += value * (netseen[device] - 3);}
	class == "net" && stat == "ipackets" { np_in[device] += value * (netseen[device] - 3);}
	class == "net" && stat == "obytes" { nb_out[device] += value * (netseen[device] - 3);}
	class == "net" && stat == "rbytes" { nb_in[device] += value * (netseen[device] - 3);}

	END {
		for (ifname in netseen) {
			if (real_interface[ifname] == 0) {
				continue;
			}
if (DO_NETIF == 1) {
if (DO_BLOCKS == 1) {
		print "name=Hardware Resources|Network|",ifname,"|Incoming packets/sec,aggregator=OBSERVATION,value=", int(np_in[ifname]/seconds);
		print "name=Hardware Resources|Network|",ifname,"|Outgoing packets/sec,aggregator=OBSERVATION,value=", int(np_out[ifname]/seconds);
}
		print "name=Hardware Resources|Network|",ifname,"|Incoming KB/sec,aggregator=OBSERVATION,value=", int(((nb_in[ifname]/seconds) + 1023) / 1024);
		print "name=Hardware Resources|Network|",ifname,"|Outgoing KB/sec,aggregator=OBSERVATION,value=", int(((nb_out[ifname]/seconds) + 1023) / 1024);
}
			kb_in += nb_in[ifname];
			kb_out += nb_out[ifname];
			pkt_out += np_out[ifname];
			pkt_in += np_in[ifname];
		}	
		for (disk in diskseen) {
			if (real_disk[disk] == 0) {
				continue;
			}
if (DO_DISKS == 1) {
if (DO_BLOCKS == 1) {
print "name=Hardware Resources|Disks|",disk,"|Reads/sec,aggregator=OBSERVATION,value=", int(dreads[disk]/seconds);
print "name=Hardware Resources|Disks|",disk,"|Writes/sec,aggregator=OBSERVATION,value=", int(dwrites[disk]/seconds);
}
print "name=Hardware Resources|Disks|",disk,"|KB read/sec,aggregator=OBSERVATION,value=", int(((din[disk]/seconds) + 1023) / 1024);
print "name=Hardware Resources|Disks|",disk,"|KB written/sec,aggregator=OBSERVATION,value=", int(((dout[disk]/seconds) + 1023) / 1024);
}
			disk_in += din[disk];
			disk_out += dout[disk];
			disk_writes += dwrites[disk];
			disk_reads += dreads[disk];
		}	

		kb_in = int(((kb_in / seconds) + 1023) / 1024);
		kb_out = int(((kb_out / seconds) + 1023) / 1024);
		disk_in = int(((disk_in / seconds) + 1023) / 1024);
		disk_out = int(((disk_out / seconds) + 1023) / 1024);

		pkt_in = int(pkt_in / seconds);
		pkt_out = int(pkt_out / seconds);
		disk_reads = int(disk_reads / seconds);
		disk_writes = int(disk_writes / seconds);

if (DO_BLOCKS) {
		print "name=Hardware Resources|Network|Incoming packets/sec,aggregator=OBSERVATION,value=", pkt_in;
		print "name=Hardware Resources|Network|Outgoing packets/sec,aggregator=OBSERVATION,value=", pkt_out;
		print "name=Hardware Resources|Disks|Reads/sec,aggregator=OBSERVATION,value=", disk_reads;
		print "name=Hardware Resources|Disks|Writes/sec,aggregator=OBSERVATION,value=", disk_writes;
}
		print "name=Hardware Resources|Network|Incoming KB/sec,aggregator=OBSERVATION,value=", kb_in;
		print "name=Hardware Resources|Network|Outgoing KB/sec,aggregator=OBSERVATION,value=", kb_out;
		print "name=Hardware Resources|Disks|KB read/sec,aggregator=OBSERVATION,value=", disk_in;
		print "name=Hardware Resources|Disks|KB written/sec,aggregator=OBSERVATION,value=", disk_out;
	}
' DO_DISKS=$DO_DISK DO_BLOCKS=$DO_BLOCKS DO_NETIF=$DO_IF NETIFS=$NETIFS DISKS=$DISKS OFS=''

# CPU

#
# Check if the zonename(1) utility exists.  If not, this system is likely running
# Solaris 8 or 9, so use vmstat(1m) to gather the CPU utilization.
#
ZONENAME=$(which zonename)

if [[ -x "${ZONENAME}" ]]; then
	zone=`${ZONENAME}`
	CPU_BUSY_TEMP=`prstat -Z 1 1 | grep $zone | awk '{print $7}' | sed 's/%//'`
	CPU_BUSY=`printf "%0.f\n" $CPU_BUSY_TEMP`
	CPU_IDLE=$((100 - $CPU_BUSY))
else
	CPU_IDLE_TEMP=`vmstat 1 2 | tail -1 | awk '{print $22}'`
	CPU_IDLE=${CPU_IDLE_TEMP}
	CPU_BUSY=$((100 - $CPU_IDLE))
fi

echo "name=Hardware Resources|CPU|%Idle,aggregator=OBSERVATION,value="$CPU_IDLE
echo "name=Hardware Resources|CPU|%Busy,aggregator=OBSERVATION,value="$CPU_BUSY

#
# solaris df output
#
if [ $DO_FS == 1 ] ; then
(df -gk -F nfs ; df -gk -F ufs ; df -gk -F zfs) | awk '
/\(/ { mountpt = substr($0,1,index($0,"(")-1);
	if (index(mountpt," ")) {
		mountpt = substr(mountpt,1,index(mountpt," ")-1);
	}
}
(NF == 11) {
	total = int($1/2);
	free = int($4/2);
	available = int($7/2);
	print "name=Hardware Resources|Filesystems|", mountpt, "|Total KB,aggregator=OBSERVATION,value=", total;
	print "name=Hardware Resources|Filesystems|", mountpt, "|Used KB,aggregator=OBSERVATION,value=", total-free;
	print "name=Hardware Resources|Filesystems|", mountpt, "|Available KB,aggregator=OBSERVATION,value=", available;
}' OFS=
fi

PREV=$NOW
NOW=`$GET_TIMESTAMP`

if [ $NOW -le $PREV ]; then
    fail "ERROR: Time stamps are not increasing (before=$PREV after=$NOW)"
fi

SLEEPTIME=$(($NEXTSECONDS - $NOW))
if [ $SLEEPTIME -gt 0 ] ; then
	sleep $SLEEPTIME
else
    log_warn "Scripts are running longer than $LOOPTIME seconds"
fi

# not indented
done

}

# Execute any arguments (e.g., calling functions)
$@

