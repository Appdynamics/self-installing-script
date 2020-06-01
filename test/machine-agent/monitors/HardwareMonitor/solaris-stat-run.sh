#!/usr/bin/env bash
#
# This is a wrapper to call the main function of the solaris-stat script
#
# Copyright (c) AppDynamics, Inc., and its affiliates, 2014, 2015
# All Rights Reserved
# THIS IS UNPUBLISHED PROPRIETARY CODE OF APPDYNAMICS, INC.
# The copyright notice above does not evidence any
# actual or intended publication of such source code.

# set script dir to the current
export SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# load the solaris-stat script
source "$SCRIPT_DIR"/solaris-stat.sh

main

