#!/bin/bash
#
# This script will ssh into the APIC IP below, and download the pysdk directories
# trying a number of different locations, hoping it finds at least one that works
#
# Use this after downloading this package and if you don't have the correct pysdk
#
if [ -z $1 ] ; then
	source env.sh
else
	source $1
fi
mkdir -p pysdk
cd pysdk
ssh $APIC_USERNAME@$IP \
'cd /controller/ishell ||
 cd /controller/mgmt ;
 tar zcf - insieme' | \
tar zxf -
