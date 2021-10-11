#### OPENSTACK STORAGE
####
#### BLOCK STORAGE ####
##### from controller
##### Use the systemctl command to view the status of the ceph-mon service
##### LOAD = Reflects whether the unit definition was properly loaded.
##### ACTIVE = The high-level unit activation state, i.e. generalization of SUB.
##### SUB = The low-level unit activation state, values depend on unit type.
```
systemctl list-units -t service ceph\*
```
##### from controller
##### View the status of the Ceph cluster in the environment
```
podman exec -it ceph-mon-controller0 ceph -s
```
##### from controller
##### verify that the images pool is available using the ceph osd lspools command
```
podman exec -it ceph-mon-controller0 ceph osd lspools
```
##### from controller
##### Verify that the cephx user account client.openstack is available using the ceph auth list command
```
podman exec -it ceph-mon-controller0 ceph auth list
```
##### from controller
##### Verify that the Ceph settings are appropriately defined with the right pool name such that the OpenStack Image service uses the Ceph storage as the back-end storage provider to accommodate an image. Retrieve the Ceph settings from the configuration file of the OpenStack Image service API container.
```
podman exec -it glance_api grep -Ei 'rbd|ceph' \
/etc/glance/glance-api.conf | grep -v ^#
```
##### from controller
##### Verify that the Ceph settings are appropriately defined with the correct pool name such that the OpenStack Block Storage service uses the Ceph storage as the back-end storage provider to accommodate a volume
```
podman exec -it cinder_api \
grep -Ei 'rbd|ceph' \
/etc/cinder/cinder.conf" | grep -v ^#
```

#### OBJECT STORAGE ####
####
##### from controller
##### check swift config files
```
cd /var/lib/config-data/puppet-generated/swift/etc/swift
```
##### verify the swing ring builder files, running config
```
cd /var/lib/config-data/puppet-generated/swift/etc/swift/
```
```
swift-ring-builder object.builder
```
```
swift-ring-builder container.builder
```
```
swift-ring-builder account.builder
```
##### Update the OpenStack object store ring builder files to add /srv/node/d2 as an additional device. Set the weight of the new device to 100.
```
swift-ring-builder object.builder \
add z1-172.24.4.1:6000/d2 100
```
```
swift-ring-builder container.builder \
add z1-172.24.4.1:6001/d2 100
```
```
swift-ring-builder account.builder \
add z1-172.24.4.1:6002/d2 100
```
##### Set the replica count to 2 in the ring builder files, after that we need to rebalance
```
swift-ring-builder object.builder set_replicas 2
```
```
swift-ring-builder container.builder set_replicas 2
```
```
swift-ring-builder account.builder set_replicas 2
```
##### from director
##### for rebalancing the swift rings we need to go to the director and run a yaml file
```
ansible-playbook \
-i /usr/bin/tripleo-ansible-inventory \
/home/stack/swift_ring_rebalance.yaml
```
##### from controller
##### after rebalancing
##### restart the swift_proxy, swift_account_server, swift_container_server, and swift_object_server containers
```
podman restart swift_proxy swift_account_server \
swift_container_server swift_object_server
```
##### verify the rebalancing was successful -  swing ring builder files, running config
```
cd /var/lib/config-data/puppet-generated/swift/etc/swift/
```
```
swift-ring-builder object.builder
```
```
swift-ring-builder container.builder
```
```
swift-ring-builder account.builder
```
####
#### FILE SHARING with MANILA ####
####
##### from controller
##### Verify the state and the configuration settings of the OpenStack Shared File Systems service
```
podman ps --format="{{.Names}} {{.Status}}" | grep manila
```
##### from controller
##### verify the configuration settings of the Shared File Systems service that intends to use the Red Hat Ceph Storage in the classroom environment as the storage provider.
```
crudini --get \
/var/lib/config-data/puppet-generated/manila/etc/manila/manila.conf \
DEFAULT enabled_share_backends
```
```
crudini --get \
/var/lib/config-data/puppet-generated/manila/etc/manila/manila.conf \
DEFAULT enabled_share_protocols
```
```
tail \
/var/lib/config-data/puppet-generated/manila/etc/manila/manila.conf
```
##### as an Openstack Admin
##### verify the status of the Shared File Systems service instances
```
manila service-list \
--columns Binary,Status,State
```
##### create the share type cephfstype
##### To dynamically scale the share nodes, set driver_handles_share_servers to true
```
manila type-create cephfstype false
```
##### as an Openstack project member 
##### create the finance-share1 file share 
```
manila create \
--name finance-share1 --share-type cephfstype cephfs 1
```
##### Verify that the new share is available
```
manila list \
--columns Name,'Share Proto',Status,'Share Type Name'
```
##### launch an instance for future access to the share
```
openstack server create \
--flavor default \
--image rhel8 \
--key-name example-keypair \
--config-drive true \
--nic net-id=finance-network1 \
--nic net-id=provider-storage \
--user-data /home/student/manila/user-data.file \
finance-server1 --wait
```
##### Add the available floating IP address to the instance
```
openstack floating \
ip list -c 'Floating IP Address' -c Port
```
```
openstack server \
add floating ip finance-server1 172.25.250.123
```
#####
##### from the controller
##### Create the exclusive cephx user client.cloud-user to access the Ceph-backed share finance-share1. Allow the client.cloud-user cephx user to read from and write to the share. The OpenStack Shared File Systems service uses the client.manila cephx user to authenticate while communicating with the Ceph cluster, although it has more privileges than what a user actually requires to access the share
```
podman exec -it ceph-mon-controller0 ceph \
--name=client.manila \
--keyring=/etc/ceph/ceph.client.manila.keyring \
auth get-or-create client.cloud-user > /root/cloud-user.keyring
```
##### copy the generated cloud-user.keyring and ceph.config from controller to the openstack env machine
```
scp \
root@controller0:{cloud-user.keyring,/etc/ceph/ceph.conf} .
```
##### as the openstack project member user
##### copy the same files to the created instance that needs to use the share, under the cloud-user home dir
```
scp \
{cloud-user.keyring,ceph.conf} cloud-user@172.25.250.107:
```
##### as the openstack project member user
##### Add and verify the access rights to finance-share1 for client.cloud-user
```
manila access-allow \
finance-share1 cephx cloud-user
```
```
manila access-list \
finance-share1 --columns access_to,access_level,state
```
##### as the openstack project member user
##### determine the export location of finance-share1
```
manila share-export-location-list \
finance-share1 --columns Path
```
##### on the target INSTANCE that we want to mount the share to
```
ssh cloud-user@172.25.250.123
```
```
dnf install ceph-fuse
```
```
mkdir /mnt/ceph
```
##### Mount the share on /mnt/ceph from finance-server1. Use the export path from finance-share1. Verify that the share is successfully mounted
```
ceph-fuse /mnt/ceph/ \
--id=cloud-user --conf=/home/cloud-user/ceph.conf \
--keyring=/home/cloud-user/cloud-user.keyring \
--client-mountpoint=/volumes/_nogroup/cea022a9-c00c-4003-b6f3-8fea2a49bd5f
```
####
#### EPHEMERAL STORAGE ####
####
##### from compute node
##### View the settings that enable Ceph storage as the back-end storage provider for the OpenStack Compute service.
```
grep rbd \
/var/lib/config-data/puppet-generated/nova_libvirt/etc/nova/nova.conf \
| grep -v '^#'
```
##### Adjust the configuration settings of the OpenStack Compute service to use the default approach of storing the instance disks on the local compute node rather than the Ceph storage. 
```
Comment out the images_type=rbd line under the [libvirt] INI section of the
/var/lib/config-data/puppet-generated/nova_libvirt/etc/nova/
nova.conf file.
```
##### from the compute node
##### Restart the nova_compute container to bring the configuration change into effect
```
systemctl restart tripleo_nova_compute
```
##### from the compute node 
##### check were the instance drives are kept
```
ls /var/lib/nova/instances/<Instance ID>
```
#### PERSISTANT STORAGE ####
####
##### from controller
##### view the settings of the OpenStack Block Storage service that assists in using Ceph storage to accommodate persistent volumes.
```
crudini --get \
/var/lib/config-data/puppet-generated/cinder/etc/cinder/cinder.conf \
DEFAULT enabled_backends
```
##### View the settings under the tripleo_ceph INI section of the OpenStack Block Storage service configuration file
```
grep -A 6 \
'^\[tripleo_ceph\]$' \
/var/lib/config-data/puppet-generated/cinder/etc/cinder/cinder.conf
```
##### from openstack as project member user
##### First create a volume based on a redhat image
```
openstack volume create \
--size 10 \
--image rhel8 \
finance-vol1
```
##### from controller
##### Verify that the Ceph pool volumes has an object representing the volume finance-vol1. Use the unique ID of the volume noted in the preceding step
```
podman exec -it ceph-mon-controller0 rados -p volumes \
ls | grep <volume ID>
```
##### from openstack as project member user
##### Create an Instance using the persistant volume as disk
```
openstack server create \
--flavor default \
--volume finance-vol1 \
--key-name example-keypair \
--config-drive true \
--nic net-id=finance-network1 \
finance-server2 --wait
```
##### from openstack as project member user
##### create an empty volume of 1 GB
```
openstack volume create \
--size 1 finance-vol2
```
##### Attach a persistent volume(finance-vol2) to a running instance(finance-server2)
##### the vol will be listed as a block device on the instance and will need to be partitioned and formated
```
openstack server add \
volume finance-server2 finance-vol2
```