#!/bin/sh
#
# Copyright (c) AppDynamics, Inc., and its affiliates, 2014, 2015
# All Rights Reserved
# THIS IS UNPUBLISHED PROPRIETARY CODE OF APPDYNAMICS, INC.
# The copyright notice above does not evidence any
# actual or intended publication of such source code.
#
# Monitors CPU, Memory, Network and Disks on Linux
#
# version 1.6
#
# rewrite using only:
# date, vmstat, awk, cat, sleep, tr, /proc/net/dev, /proc/diskstats, /proc/meminfo, df
#########################################

# Include configuration variables.
. ./config.sh

MOUNTS=
# uncomment the next line to enable custom metrics for mounted filesystems
#MOUNTS=`mount| awk '/^\/dev/ {sub("/dev/","",$1);printf("%s:%s;",$1, $3)}'`
# uncomment the next line to enable custom metrics for swap
#MOUNTS+=`awk '/\/dev/ {sub("/dev/","",$1);printf("%s:swap;",$1)}'< /proc/swaps`

# interval between reads of network and disk numbers
SAMPLE=10

PATH=$PATH:/bin:/usr/sbin:/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin

while [ 1 ]; do
NEXTSECONDS=`date +%s | awk '{print $1 + 60}'`

# memory statistics
if [ $REPORT_MEMORY_FREE_AS_MEMORY_AVAILABLE -eq 1 ]
then
	free -m | awk -v OFS="" '
		NR==2 { MEM_TOTAL_MB = $2; }
		NR==3 {
			MEM_USED_MB = $3;
			MEM_FREE_MB = $4;
		}
		END {
			print "name=Hardware Resources|Memory|Total (MB),aggregator=OBSERVATION,value=", MEM_TOTAL_MB;
			print "name=Hardware Resources|Memory|Used (MB),aggregator=OBSERVATION,value=", MEM_USED_MB;
			print "name=Hardware Resources|Memory|Free (MB),aggregator=OBSERVATION,value=", MEM_FREE_MB;
			MEM_USED_PCT = int((MEM_USED_MB / MEM_TOTAL_MB) * 100);
			print "name=Hardware Resources|Memory|Used %,aggregator=OBSERVATION,value=", MEM_USED_PCT;
			print "name=Hardware Resources|Memory|Free %,aggregator=OBSERVATION,value=", 100 - MEM_USED_PCT;
		}
	'
else
	cat /proc/meminfo | awk -v OFS="" '
		/^MemTotal/ { MEM_TOTAL_MB = int($2 / 1024); }
		/^MemFree/ { MEM_FREE_MB = int($2 / 1024); }
		/^Cached/ { MEM_CACHE_MB = int($2 / 1024); }
		END {
			MEM_USED_MB = MEM_TOTAL_MB - MEM_FREE_MB;
			print "name=Hardware Resources|Memory|Total (MB),aggregator=OBSERVATION,value=", MEM_TOTAL_MB;
			print "name=Hardware Resources|Memory|Used (MB),aggregator=OBSERVATION,value=", MEM_USED_MB;
			print "name=Hardware Resources|Memory|Free (MB),aggregator=OBSERVATION,value=", MEM_FREE_MB;
			print "name=Hardware Resources|Memory|Used %,aggregator=OBSERVATION,value=",
				int((MEM_USED_MB / MEM_TOTAL_MB) * 100);
			print "name=Hardware Resources|Memory|Free %,aggregator=OBSERVATION,value=",
				100 - int((MEM_USED_MB / MEM_TOTAL_MB) * 100);
		}
	'
fi

# net statistics
(cat /proc/net/dev ; sleep $SAMPLE; cat /proc/net/dev) | tr ':' ' ' |
    awk -v interval=$SAMPLE -v OFS="" '
    NF == 17 {
        dev = $1;
       if (seen[dev]) {
            bread[dev] = $2 - bread[dev];
            pread[dev] = $3 - pread[dev];
            bwrite[dev] = $10 - bwrite[dev];
            pwrite[dev] = $11 - pwrite[dev];
        } else {
            bread[dev] = $2;
            pread[dev] = $3;
            bwrite[dev] = $10;
            pwrite[dev] = $11;
        }
        seen[dev] = 1;
    }
    END {
        for (dev in seen) {
            readk += bread[dev];
            writek += bwrite[dev];
            preads += pread[dev];
            pwrites += pwrite[dev];

        }
        NET_KBYTES_IN = int((readk / 1024) / interval);
        NET_KBYTES_OUT = int((writek / 1024) / interval);
        NET_PACKETS_IN = int(preads / interval);
        NET_PACKETS_OUT = int(pwrites / interval);

print "name=Hardware Resources|Network|Incoming packets/sec,aggregator=OBSERVATION,value=", NET_PACKETS_IN;
print "name=Hardware Resources|Network|Outgoing packets/sec,aggregator=OBSERVATION,value=", NET_PACKETS_OUT
print "name=Hardware Resources|Network|Incoming KB/sec,aggregator=OBSERVATION,value=", NET_KBYTES_IN
print "name=Hardware Resources|Network|Outgoing KB/sec,aggregator=OBSERVATION,value=", NET_KBYTES_OUT
    }
'

# disk statistics
(cat /proc/diskstats ; sleep $SAMPLE; cat /proc/diskstats) |
    awk -v interval=$SAMPLE -v mounts=$MOUNTS -v OFS="" '
    BEGIN {
        fss = split(mounts, fslist, ";");
        for (f = 1; f < fss; f++) {
            split(fslist[f], fe, ":");
            fs[fe[1]] = fe[2];
        }
    }
    NF == 14 {
        dev = $3;
        if (seen[dev]) {
            r[dev] = $4 - r[dev];
            rsec[dev] = $6 - rsec[dev];
            w[dev] = $8 - w[dev];
            wsec[dev] = $10 - wsec[dev];
        } else {
            r[dev] = $4;
            rsec[dev] = $6;
            w[dev] = $8;
            wsec[dev] = $10;
        }
        seen[dev] = 1;
    }
    END {
        # dont sum devices ending in digits, they are partitions
        for (dev in seen) {
            if (match(dev, "[0-9]$") != 0) {
                continue;
            }
            reads += r[dev];
            readsk += rsec[dev] / 2;
            writes += w[dev];
            writesk += wsec[dev] / 2;
        }

        if (reads < 0) reads = 0;
        if (readsk < 0) readsk = 0;
        if (writes < 0) writes = 0;
        if (writesk < 0) writesk = 0;

print "name=Hardware Resources|Disks|Reads/sec,aggregator=OBSERVATION,value=", int(reads/interval);
print "name=Hardware Resources|Disks|Writes/sec,aggregator=OBSERVATION,value=", int(writes/interval);
print "name=Hardware Resources|Disks|KB read/sec,aggregator=OBSERVATION,value=", int(readsk/interval);
print "name=Hardware Resources|Disks|KB written/sec,aggregator=OBSERVATION,value=", int(writesk/interval);
        for (dev in fs) {
            reads = r[dev];
            readsk = rsec[dev] / 2;
            writes = w[dev];
            writesk = wsec[dev] / 2;
            if (reads < 0) reads = 0;
            if (readsk < 0) readsk = 0;
            if (writes < 0) writes = 0;
            if (writesk < 0) writesk = 0;

printf("name=Custom Metrics|Disks %s|Reads/sec,aggregator=OBSERVATION,value=%d\n", fs[dev], int(reads/interval));
printf("name=Custom Metrics|Disks %s|Writes/sec,aggregator=OBSERVATION,value=%d\n", fs[dev], int(writes/interval));
printf("name=Custom Metrics|Disks %s|KB read/sec,aggregator=OBSERVATION,value=%d\n", fs[dev], int(readsk/interval));
printf("name=Custom Metrics|Disks %s|KB written/sec,aggregator=OBSERVATION,value=%d\n", fs[dev], int(writesk/interval));
        }
    }
'

# disk usage stats
if [ -n "$MOUNTS" ]; then
    df -P -k |
    awk '
		BEGIN {
			# The partition name and mount name can contain spaces. Split the df output line with a
			# regular expression that is unlikely to occur in either the partition name or mount
			# name, so that the tokens before and after can be concatenated to form the partition
			# name and mount name, respectively.
			#
			# An example of the output we are trying to parse:
			#
			# Filesystem          1024-blocks   Used Available Capacity Mounted on
			# can have spaces             990      0       990       0% /can have spaces
			SPACE_REGEX = "[ \t]+"
			NUM_REGEX = "[0-9]+"
			COLUMN_REGEX = SPACE_REGEX NUM_REGEX
			PARTITION_SPLITTER_REGEX = COLUMN_REGEX COLUMN_REGEX COLUMN_REGEX COLUMN_REGEX "% /"
		}

		/^\/dev\// {
			# Use PARTITION_SPLITTER_REGEX to handle spaces in the partition and the mount names
			split($0, tokens, PARTITION_SPLITTER_REGEX)
			partition = tokens[1]
			partition_length = length(partition)
			mount_point = "/" tokens[2]

			# Remove the partition from the matched line so that we can parse the rest by simply
            # splitting on white space
			line = substr($0, partition_length+1)
			split(line, tokens, FS)
			used = tokens[2]
			free = tokens[3]

			printf("name=Custom Metrics|Disks %s|Space Used,aggregator=OBSERVATION,value=%d\n", mount_point, used);
			printf("name=Custom Metrics|Disks %s|Space Available,aggregator=OBSERVATION,value=%d\n", mount_point, free); 
		}
	'
fi


# cpu stats
# vmstat 1 2 = take 2 samples, 1 second apart;
# awk ignores the first, since it takes the average since startup
vmstat 1 2 | awk -v OFS="" '
    END {
        idle = $15;
print "name=Hardware Resources|CPU|%Idle,aggregator=OBSERVATION,value=", idle;
print "name=Hardware Resources|CPU|%Busy,aggregator=OBSERVATION,value=", 100 - idle;
    }
'

SLEEPTIME=`date +"$NEXTSECONDS %s" | awk '{if ($1 > $2) print $1 - $2; else print 0;}'`
sleep $SLEEPTIME

done
