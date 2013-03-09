#!/bin/bash

# build up a multi-node cluster on openstack

INSTANCE_COUNT=$1

STACKATO_CORE_NAME=api.208.75.128.162.xip.io
STACKATO_CORE_INTERNAL_IP=10.14.0.22
STACKATO_TEMPLATE=ami-00000014
KEYPAIR_NAME=ocs-stackato
GROUP_NAME=stackato-internal

echo "creating $INSTANCE_COUNT new nodes on core node $STACKATO_CORE_NAME"
echo

# fire up the instances, saving the instance ids to a file
echo launch instances
euca-run-instances $STACKATO_TEMPLATE -g $GROUP_NAME  -k $KEYPAIR_NAME -t m1.medium -n $INSTANCE_COUNT --user-data-file  sudo_user_data.yml | awk  -F'\t' 'BEGIN {OFS = FS} {print $2}' > /tmp/newinstances.txt

for i in {0..10}
do
  echo "sleeping..."
  sleep 15
done

# save IP addresses
echo save IP addresses
for INSTANCE in `cat /tmp/newinstances.txt|grep "^i-"`; do euca-describe-instances $INSTANCE | awk  -F'\t' 'BEGIN {OFS = FS}    {print $18}'; done | grep -v '^$' > /tmp/newinstanceips.txt

# remove known_hosts to prevent errors if IPs recycled
echo remove known_hosts
ssh -i ~/.ssh/ocs-stackato $STACKATO_CORE_NAME "rm -f .ssh/known_hosts"

echo "sleeping..."
sleep 1

for INSTANCE_IP in `cat /tmp/newinstanceips.txt` ; do echo "adding $INSTANCE_IP to cluster"; ssh -o "StrictHostKeyChecking no" -i ~/.ssh/ocs-stackato $STACKATO_CORE_NAME "ssh -o 'StrictHostKeyChecking no' $INSTANCE_IP \"sudo /home/stackato/bin/kato attach -e dea $STACKATO_CORE_INTERNAL_IP\""; done
