#!/usr/bin/ksh
#
# Monitors CPU, Memory, Network and Disks on aix
#
# version 1.5
#
# rewrite using only:
# vmstat, awk, sleep, iostat and netstat
# tested on aix7
#########################################

# Set unspecified system commands
SAMPLE=10
LOOPTIME=60

PATH=/usr/bin

#
# the user should edit this file to set the following value
#
# 0 - include the file cache as 'used' memory
# 1 - don't count the file cache as 'used' memory
#
EXCLUDE_FILE_CACHE=1

while [ 1 ]; do

	NOW=`date +%s`
	NEXTSECONDS=`expr $NOW + $LOOPTIME`

# disk statistics
iostat -Dl 1 1 | awk -v OFS="" '
	function units(arg) {
		val = arg + 0;
		if (arg ~ "K$") val *= 1000;
		if (arg ~ "M$") val *= 1000000;
		return int(val);
	}
	NF == 24 {
		dev = $1;
		rb[dev] = units($5);
		wb[dev] = units($6);
		rc[dev] = $7;
		wc[dev] = $13;
		rk += rb[dev];
		wk += wb[dev];
		reads += rc[dev];
		writes += wc[dev];
		next;
	}
	END {
        printf "name=Hardware Resources|Disks|KB read/sec,aggregator=OBSERVATION,value=%.0f\n", int(rk/1000);
        printf "name=Hardware Resources|Disks|KB written/sec,aggregator=OBSERVATION,value=%.0f\n", int(wk/1000);
        printf "name=Hardware Resources|Disks|Reads/sec,aggregator=OBSERVATION,value=%.0f\n", int(reads);
        printf "name=Hardware Resources|Disks|Writes/sec,aggregator=OBSERVATION,value=%.0f\n", int(writes);
	}
'

# net statistics
(netstat -v ; sleep $SAMPLE; netstat -v) |
	awk -v interval=$SAMPLE -v OFS="" '
	/^ETHERNET STATISTICS/ {
		dev = $3;
		seen[dev]++;
	}
	/^Packets:/ {
		if (seen[dev] == 2) {
			inpkts[dev] = $4 - inpkts[dev];
			outpkts[dev] = $2 - outpkts[dev];
		} else {
			inpkts[dev] = $4;
			outpkts[dev] = $2;
		}
	}
	/^Bytes:/ {
		if (seen[dev] == 2) {
			inbytes[dev] = $4 - inbytes[dev];
			outbytes[dev] = $2 - outbytes[dev];
		} else {
			inbytes[dev] = $4;
			outbytes[dev] = $2;
		}
	}
	END {
		for (i in seen) {
			ipkts += inpkts[i];
			opkts += outpkts[i];
			ibytes += inbytes[i];
			obytes += outbytes[i];
		}
		NET_PACKETS_IN = int(ipkts / interval);
		NET_PACKETS_OUT = int(opkts / interval);
		NET_KBYTES_IN = int((ibytes / 1024) / interval);
		NET_KBYTES_OUT = int((obytes / 1024) / interval);

        printf "name=Hardware Resources|Network|Incoming packets/sec,aggregator=OBSERVATION,value=%.0f\n", NET_PACKETS_IN;
        printf "name=Hardware Resources|Network|Outgoing packets/sec,aggregator=OBSERVATION,value=%.0f\n", NET_PACKETS_OUT
        printf "name=Hardware Resources|Network|Incoming KB/sec,aggregator=OBSERVATION,value=%.0f\n", NET_KBYTES_IN
        printf "name=Hardware Resources|Network|Outgoing KB/sec,aggregator=OBSERVATION,value=%.0f\n", NET_KBYTES_OUT
	}
'

#
# cpu statistics
#
vmstat 1 1 | awk -v OFS="" '
	{ idle = $16; }
	END {
        print "name=Hardware Resources|CPU|%Idle,aggregator=OBSERVATION,value=", idle;
        print "name=Hardware Resources|CPU|%Busy,aggregator=OBSERVATION,value=", 100 - idle;
	}
'

#
# memory statistics
#
vmstat -v | awk -v OFS="" -v EXCLUDE_FILE_CACHE=$EXCLUDE_FILE_CACHE '
	/memory pages/ { MEM_TOTAL_KB = $1 * 4 }
	/free pages/   { MEM_FREE_PAGES_KB = $1 * 4 }
	/file pages/   { MEM_FILE_KB = $1 * 4 }
	END {
		if (EXCLUDE_FILE_CACHE) {
			MEM_FREE_KB = MEM_FREE_PAGES_KB + MEM_FILE_KB;
		} else {
			MEM_FREE_KB = MEM_FREE_PAGES_KB;
		}
		MEM_USED_KB = MEM_TOTAL_KB - MEM_FREE_KB;
        printf "name=Hardware Resources|Memory|Total (MB),aggregator=OBSERVATION,value=%.0f\n", int(MEM_TOTAL_KB / 1024);
        printf "name=Hardware Resources|Memory|Used (MB),aggregator=OBSERVATION,value=%.0f\n", int(MEM_USED_KB / 1024);
        printf "name=Hardware Resources|Memory|Free (MB),aggregator=OBSERVATION,value=%.0f\n", int(MEM_FREE_KB / 1024);
        print "name=Hardware Resources|Memory|Used %,aggregator=OBSERVATION,value=", int((MEM_USED_KB / MEM_TOTAL_KB) * 100);
        print "name=Hardware Resources|Memory|Free %,aggregator=OBSERVATION,value=", int((MEM_FREE_KB / MEM_TOTAL_KB) * 100);
	}
'

	NOW=`date +%s`
        SLEEPTIME=`expr $NEXTSECONDS - $NOW`
        if [ $SLEEPTIME -gt 0 ] ; then
                sleep $SLEEPTIME
        fi

done
