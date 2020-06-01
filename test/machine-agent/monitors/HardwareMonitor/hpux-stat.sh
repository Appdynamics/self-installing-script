#!/usr/bin/ksh
#
# Monitors CPU, Memory, Network and Disks on hpux
#
# version 1.7
#
# rewrite using only:
# perl, vmstat, awk, sleep, iostat and netstat
#
# working on 11.11, 11.31
#########################################

#
# find out if date works - hpux 11.11 no, 11.31 yes
#
if date +%s >/dev/null 2>&1 ; then
	alias gettime="date +%s"
else
	if [ -f /usr/bin/perl ] ; then
		PERL=/usr/bin/perl
	elif [ -f /usr/local/bin/perl ] ; then
		PERL=/usr/local/bin/perl
	fi
	alias gettime="$PERL -e 'print time()'"
fi

SAMPLE=10
LOOPTIME=60

while [ 1 ]; do

	NOW=`gettime`
	NEXTSECONDS=`expr $NOW + $LOOPTIME`

	# hpux does not break out writes and reads, just total kb.
	# disk statistics
	# it seems that the first iostat row may be garbage.
	# lets read several.only
	# only add the last statistic for each of the devices
	iostat 1 3 | awk -v OFS="" '
		/device/ {next}
		{ disk[$1] = $2; }
		END {
			kbps = 0;
			for (i in disk) {
				kbps += disk[i];
			}
			print "name=Hardware Resources|Disks|KB read/sec,aggregator=OBSERVATION,value=", kbps;
		}
	'

# net statistics
# calculate the delta between $SAMPLE seconds
#
(netstat -in ; sleep $SAMPLE; netstat -in) |
	awk -v interval=$SAMPLE -v OFS="" '
		/^Name/ { next }
		/^lo/ { next }
		{
			dev=$1;
			seen[dev]++;
			if (seen[dev] == 2) {
				inpkts[dev] = $5 - inpkts[dev];
				outpkts[dev] = $7 - outpkts[dev];
			} else {
				inpkts[dev] = $5;
				outpkts[dev] = $7;
			}
		}
		END {
			for (i in seen) {
				ipkts += inpkts[i];
				opkts += outpkts[i];
			}
			NET_PACKETS_IN = int(ipkts / interval);
			NET_PACKETS_OUT = int(opkts / interval);
			print "name=Hardware Resources|Network|Incoming packets/sec,aggregator=OBSERVATION,value=", NET_PACKETS_IN;
			print "name=Hardware Resources|Network|Outgoing packets/sec,aggregator=OBSERVATION,value=", NET_PACKETS_OUT
			print "name=Hardware Resources|Network|Incoming KB/sec,aggregator=OBSERVATION,value=", NET_PACKETS_IN;
			print "name=Hardware Resources|Network|Outgoing KB/sec,aggregator=OBSERVATION,value=", NET_PACKETS_OUT
		}
	'

# cpu and memory statistics - only believe the second report
#
vmstat 1 2 | awk -v OFS="" '
	NR == 4 {
		idle = $18;
		if (idle > 100) idle = 100;
	}
	END {
		print "name=Hardware Resources|CPU|%Idle,aggregator=OBSERVATION,value=", idle;
		print "name=Hardware Resources|CPU|%Busy,aggregator=OBSERVATION,value=", 100 - idle;
	}
	'

# this is a believable number - top is not
#
/usr/sbin/swapinfo | awk -v OFS="" '
	/^memory/ {
		MEM_TOTAL_KB = $2;
		MEM_USED_KB = $3;
		MEM_FREE_KB = MEM_TOTAL_KB - MEM_USED_KB;
		print "name=Hardware Resources|Memory|Total (MB),aggregator=OBSERVATION,value=", int(MEM_TOTAL_KB / 1024);
		print "name=Hardware Resources|Memory|Used (MB),aggregator=OBSERVATION,value=", int(MEM_USED_KB / 1024);
		print "name=Hardware Resources|Memory|Free (MB),aggregator=OBSERVATION,value=", int(MEM_FREE_KB / 1024);
		print "name=Hardware Resources|Memory|Used %,aggregator=OBSERVATION,value=",
		int((MEM_USED_KB / MEM_TOTAL_KB) * 100);
		print "name=Hardware Resources|Memory|Free %,aggregator=OBSERVATION,value=",
			int((MEM_FREE_KB / MEM_TOTAL_KB) * 100);
	}
	'

	NOW=`gettime`
	SLEEPTIME=`expr $NEXTSECONDS - $NOW`
	if [ $SLEEPTIME -gt 0 ] ; then
		sleep $SLEEPTIME
	fi

done
