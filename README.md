## HOWTO: Build Multi-node Stackato Cluster on Openstack

## Wednesday Trials

* Download latest 2.10.6 for vbox

* Import into vbox

* add ssh keys to ~root/.ssh and ~stackato/.ssh

* fix cloud-init:  

*  ssh stackato@vm
*  sudo bash
*  dpkg-reconfigure cloud-init
*  select EC2 then OK

* shutdown

* zip the resulting image in ~/VirtualBox\ VMs/

         zip -r Stackato-880-v2.10.6.zip Stackato-880-v2.10.6

* transfer resulting zipfile to ubuntu instance

*   unzip Stackato-880-v2.10.6.zip

* convert to qcow2: qemu-img convert -O qcow2 Stackato-688-v2.8.2-disk1.vmdk stackato-282.qcow2

* upload image: glance add name=stackato282-cloudinit disk_format=qcow2 container_format=bare < stackato-282.qcow2

* launch new image: euca-run-instances -g stackato-internal -k ocs-stackato ami-00000010

## Prep

1. Install [euca2ools](http://www.eucalyptus.com/download/euca2ools) (Eucalyptus toolsuite for openstack management),
[glance](http://docs.openstack.org/developer/glance/) (vm management and uploading),  and [qema](http://en.wikibooks.org/wiki/QEMU) (handy for vm image
conversion): 

        $ sudo apt-get install euca2ools
        $ sudo apt-get install glance-client
        $ sudo apt-get install qemu

1. Obtain credentials and environment from your openstack provider,
add these (in the form of exported enviroment variables) to a source
file (I'll call it env.sh):

<pre><div class="code">export EC2_URL=https://ocs.jds.sv1.cloudscaling.com/services/Cloud
export EC2_ACCESS_KEY=2b2b888888888ffa94fakea9d421e23e
export EC2_SECRET_KEY=2b2b8888888880alsofakea9d421e23e

export OS_AUTH_URL=http://192.168.1.1:99/v2.0
export OS_TENANT_NAME=my-tenant-name
export OS_USERNAME=my-user-name</div></pre>

Source this file:

        $  . ./env.sh


With the credentials available via the environment, both eucatools and
and glance are now pre-authorized clients.

(Keep those creds in a safe place!)


####  add ssh keypair

The public key is installed on each node with the following commands,
which also safely stash the private key in ~/.ssh.

       $ euca-add-keypair ocs-stackato > ~/.ssh/ocs-stackato
       $ chmod 600 ~/.ssh/ocs-stackato



## create groups

Security groups define port forwarding rules.  Here three groups are
defined:  router, harbor, and internal 

The port forwarding rules for each group are shown below:

### Router Security Group

<pre><div class="code">   # security group for router
   euca-add-group -d "edge stackato security group for Router" stackato-router

   # firewall rules for router:
   euca-authorize -P tcp -p 22  stackato-router
   euca-authorize -P tcp -p 80  stackato-router
   euca-authorize -P tcp -p 443 stackato-router
   euca-authorize -P tcp -p 1-65535 -s 10.0.0.0/8 stackato-router</div></pre>

### Harbor Security Group

Harbor redirects traffic for a range of ports (hard-coded for now but
should be obtained from configuration)


<pre><div class="code">   # security group for harbor
   euca-add-group -d "edge stackato security group for Harbor" stackato-harbor

   # firewall rules for harbor:
   euca-authorize -P tcp -p 22  stackato-harbor
   euca-authorize -P tcp -p 35000-45000 stackato-harbor
   euca-authorize -P tcp -p 1-65535 -s 10.0.0.0/8 stackato-harbor</div></pre>


### Stackato internal node security group

<pre><div class="code">   # security group for internal
   euca-add-group -d "edge stackato security group for Harbor" stackato-internal

   euca-authorize -P tcp -p 1-65535 -s 10.0.0.0/8 stackato-harbor</div></pre>


### Get Latest Stackato Image

Download latest Stackato image in KVM format from the [Stackato download
page](http://www.activestate.com/stackato/download_vm/thank-you?dl=http://downloads.activestate.com/stackato/vm/v2.8.2/stackato-img-kvm-v2.8.2.zip)



### Convert downloaded Stackato KVM image to QCOW2:

       qemu-img convert -f raw -O qcow2 stackato-img-kvm-v2.8.2.img stackato-282.qcow2


### Upload image to OCS with glance:

       glance add name=stackato282 disk_format=qcow2 container_format=bare < stackato-282.qcow2


### create a user-data file for vm customization

call it dea-user-data.yml

        #cloud-config
        stackato:
            nats:
                ip: 10.0.3.6
            roles:
                - dea

Note that configuring the DEA via clout-init is currently not working.


### List the available vm images (templates)

        $ euca-describe-images


### Launch an instance for the Stackato core node

        $ euca-run-instances -g stackato-router -k ocs-stackato -t m1.medium  ami-00000014  


Now launch the individual DEA nodes:

         euca-run-instances ami-00000014 -g stackato-internal  -k ocs-stackato -t m1.medium -n 5 --user-data-file  sudo_user_data.yml | awk  -F $'\t' 'BEGIN {OFS = FS} {print $2}' | grep  '^i-' > /tmp/newinstances.txt


### List the instances (available Stackato VMs)

        $ euca-describe-instances



### Assign external static IP

Allocate an available address then associate it with the new instance

       $ euca-allocate-address
       $ euca-associate-address -i i-00000211 208.75.128.167


## Stackato

After core comes up, log in and configure this as a core node:

          $ ssh -i ~/.ssh/ocs-stackato 208.75.128.167

          $ kato node rename 208.75.128.135.xip.io

	  $ kato node setup core api.208.75.128.135.xip.io
	  $ kato roll add stager



### Then spawn 20 instances:

     euca-run-instances ami-00000014 -g stackato-internal  -k ocs-stackato -t m1.medium -n 5 --user-data-file  sudo_user_data.yml | awk  -F $'\t' 'BEGIN {OFS = FS} {print $2}' > /tmp/newinstances.txt


Go for coffee, then capture the ip addresses of the new instances:


   for INSTANCE in `cat /tmp/newinstances.txt|grep "^i-"`; do euca-describe-instances $INSTANCE | awk  -F $'\t' 'BEGIN {OFS = FS}    {print $18}'; done | grep -v '^$' > /tmp/newinstanceips.txt


Now run this to configure each as a DEA

    ssh api.208.75.128.159.xip.io "rm .ssh/known_hosts"  #  this prevents errors if the ip addresses have been reused

   for IP in `cat /tmp/newinstanceips.txt` ; do echo $IP; ssh -o "StrictHostKeyChecking no" -i ~/.ssh/ocs-stackato api.208.75.128.159.xip.io "ssh -o 'StrictHostKeyChecking no' $IP ssh -o "StrictHostKeyChecking no"  stackato@$IP "sudo /home/stackato/bin/kato attach -e dea 10.12.0.14"; done


   for IP in `cat /tmp/newinstanceips.txt` ; do 
        echo $IP; ssh -o "StrictHostKeyChecking no" -i ~/.ssh/ocs-stackato api.208.75.128.159.xip.io
	      "ssh -o 'StrictHostKeyChecking no' stackato@$IP 'sudo /home/stackato/bin/kato attach -e dea 10.12.0.14'";
   done



Terminating the instances

------------------------------------------
#!/bin/sh

# terminate all stackato instances listed in /tmp/newinstances.txt after first removing each from stackato cluster

export STACKATO_CORE_NAME=api.208.75.128.159.xip.io

for INSTANCE in `cat /tmp/newinstances.txt | grep '^i-'`
do
   echo terminating instance $INSTANCE
   INSTANCE_IP=`euca-describe-instances $INSTANCE | grep -v RESERVATION | awk  -F'\t' 'BEGIN {OFS = '\t'} {print $18}'`
   echo terminating instance $INSTANCE at $INSTANCE_IP
   ssh -i ~/.ssh/ocs-stackato -o "StrictHostKeyChecking no" $STACKATO_CORE_NAME "kato node remove $INSTANCE_IP"
   euca-terminate-instances $INSTANCE
done
------------------------------------------





### Questions for CloudScaling

1. how to name an instance when running it (mine are named with a guid)

2. how to find the floating ip addresses w/o using console?

3. 


### Links

Euca2ools CLI Reference
 http://open.eucalyptus.com/wiki/Euca2oolsNetworking

QEMU
  http://en.wikibooks.org/wiki/QEMU/Images

Euca Tutorial
  https://www.xsede.org/documents/234989/378230/xsede12-FG-Euca-Handson.pdf


Obtaining Metadata
  http://docs.openstack.org/trunk/openstack-compute/admin/content/metadata-service.html

    http://169.254.169.254/2009-04-04/user-data
