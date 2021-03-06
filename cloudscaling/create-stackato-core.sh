#!/bin/sh

STACKATO_TEMPLATE=ami-00000014
GROUP_NAME=stackato-router
KEYPAIR_NAME=ocs-stackato
INSTANCE_FILE=/tmp/coreinstances_$$.txt

echo "euca-run-instances $STACKATO_TEMPLATE -g $GROUP_NAME  -k $KEYPAIR_NAME -t m1.medium | awk  -F'\t' 'BEGIN {OFS = FS} {print $2}'"
euca-run-instances $STACKATO_TEMPLATE -g $GROUP_NAME  -k $KEYPAIR_NAME -t m1.medium | awk  -F'\t' 'BEGIN {OFS = FS} {print $2}' > $INSTANCE_FILE

echo "the following instance has been created: "
echo

cat $INSTANCE_FILE
echo

echo now do the following:
echo         $ euca-allocate-address
echo         $ euca-associate-address -i instance 208.75.128.xxx
echo
echo         $ ssh $IP kato node rename 208.75.128.xxx.xip.io
echo         $ ssh $IP kato node setup core api.208.75.128.xxx.xip.io
echo         $ ssh $IP kato roll add stager

