#!/bin/bash -x
#
# This script cleans up directories that shouldn't be packaged and then zips up everything else
# this is for Paul's use
#
basename=$(pwd | sed -e 's/^.*\///g')
echo 'Cleaning up'
mv pysdk /tmp
rm -fv ../${basename}.zip
cd ..
echo 'Zipping'
zip -r ${basename} ${basename}/*
cd ${basename}
echo 'Uncleaning up'
mv /tmp/pysdk .
