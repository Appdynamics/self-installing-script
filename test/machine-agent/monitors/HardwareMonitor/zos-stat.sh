#!/bin/sh
#
# Dummy script to support the machine agent on z/OS.
# 
# Since z/OS Unix System Services as documented in:
# 
# http://publibz.boulder.ibm.com/epubs/pdf/bpxza5c0.pdf
# 
# only supports a subset of the standard Unix/Linux commands, 
# it does not have commands such as vmstat, iostat, etc.
#
# We will be getting z/OS system metrics from the MEAS
# monitoring extension:
#
# http://appsphere.appdynamics.com/t5/AppDynamics-eXchange/MEAS-zOS-Mainframe-Monitoring-Extension/idi-p/2329
#
# version 1.0
##################################################

while [ 1 ]
do
  sleep 600
done
