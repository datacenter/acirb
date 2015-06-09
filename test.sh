#!/bin/bash
if [ -z $1 ] ; then
	source env.sh
else
	source $1
fi
echo "APIC target = $APIC_URI"
rspec -Ilib -fd spec/*.rb
