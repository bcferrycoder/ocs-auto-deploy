#!/bin/bash

# add a data-services node to an existing cluster

INSTANCE_COUNT=1

STACKATO_CORE_NAME=api.208.75.128.184.xip.io
STACKATO_CORE_INTERNAL_IP=10.14.0.10
STACKATO_TEMPLATE=ami-00000014
KEYPAIR_NAME=ocs-stackato
GROUP_NAME=stackato-internal

echo "creating data-services node and adding to existing cluster at $STACKATO_CORE_NAME"
echo

# fire up the instance, saving the instance ids to a file
echo launch instance
euca-run-instances $STACKATO_TEMPLATE -g $GROUP_NAME  -k $KEYPAIR_NAME -t m1.medium -n $INSTANCE_COUNT --user-data-file  sudo_user_data.yml | awk  -F'\t' 'BEGIN {OFS = FS} {print $2}' > /tmp/new-ds-instances.txt

for i in {0..3}
do
  echo "sleeping..."
  sleep 15
done

# save IP address
echo save IP address
for INSTANCE in `cat /tmp/new-ds-instances.txt|grep "^i-"`; do euca-describe-instances $INSTANCE | awk  -F'\t' 'BEGIN {OFS = FS}    {print $18}'; done | grep -v '^$' > /tmp/new-ds-instanceips.txt

# remove known_hosts to prevent errors if IPs recycled
echo remove known_hosts
ssh -i ~/.ssh/ocs-stackato -o "StrictHostKeyChecking no" $STACKATO_CORE_NAME "rm -f .ssh/known_hosts"

echo "sleeping..."
sleep 1

for INSTANCE_IP in `cat /tmp/new-ds-instanceips.txt` ; do echo "adding $INSTANCE_IP to cluster"; ssh -o "StrictHostKeyChecking no" -i ~/.ssh/ocs-stackato $STACKATO_CORE_NAME "ssh -o 'StrictHostKeyChecking no' $INSTANCE_IP \"sudo /home/stackato/bin/kato attach -e data-services $STACKATO_CORE_INTERNAL_IP\""; done
