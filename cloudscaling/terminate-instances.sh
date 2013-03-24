#!/bin/sh

# terminate all stackato instances not in 208.75 subnet

export STACKATO_CORE_NAME=api.208.75.128.161.xip.io

INSTANCES=`euca-describe-instances | grep -v RESERVATION | grep -v '208\.75\.128\.161' | grep -v '208\.75\.128\.184' | awk  -F'\t' 'BEGIN {OFS = FS} {print $2}'`

for INSTANCE in $INSTANCES
do
   echo terminating instance $INSTANCE
   INSTANCE_IP=`euca-describe-instances $INSTANCE | grep -v RESERVATION | awk  -F'\t' 'BEGIN {OFS = '\t'} {print $18}'`
   echo terminating instance $INSTANCE at $INSTANCE_IP
#   ssh -i ~/.ssh/ocs-stackato -o "StrictHostKeyChecking no" $STACKATO_CORE_NAME "kato node remove $INSTANCE_IP"
   euca-terminate-instances $INSTANCE
done
