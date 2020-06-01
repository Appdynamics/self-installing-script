#!/bin/sh
#
# Configuration for hardware monitoring scripts.

# By default, linux-stat.sh determines free memory by looking at the MemFree line in /proc/meminfo.
# Set this variable to 1 to use the '-/+ buffers/cache' line in 'free -m', which is more useful and accurate.
REPORT_MEMORY_FREE_AS_MEMORY_AVAILABLE=0
