####
#### COMPUTE NODE OPERATIONS ####
####
##### from controller
##### Configure the Compute services for debugging, and then restart the containers and confirm their status
```
crudini --set \
/var/lib/config-data/puppet-generated/nova/etc/nova/nova.conf \
DEFAULT debug True
```
```
podman restart nova_api
```
```
podman restart nova_scheduler
```
```
podman ps \
--format="{{.Names}} {{.Status}}" | grep nova
```
##### from controller and from compute
##### explore the nova logs on the controller and compute
```
cd /var/log/containers/nova
```
##### from compute, nova-compute.log - get confirmation of instance creation
```
grep <instance ID> nova-compute.log
``` 
##### from controller, 
##### nova-api.log -get creation messageserver name, image ID, flavor ID, security group ID, network ID 
##### nova-scheduler.log - get deployment schedule info, check quotas, requirements
```
grep <instance ID> nova-api.log
```
```
grep <instance ID> nova-scheduler.log
```
#####
##### as the Openstack user
##### create a new instance called finance-server1
```
openstack server create \
--image rhel8 \
--flavor default \
--config-drive true \
--nic net-id=finance-network1 \
--security-group finance-web \
--availability-zone nova:compute0.overcloud.example.com \
--wait finance-server1
```
#####
##### HOST AGGREGATES AND FLAVORS #####
#####
##### As Openstack Project Admin
##### Create a Host Aggregate
```
openstack aggregate create \
hci-aggregate
```
##### Add Compute Node to the created hci-aggregate
```
openstack aggregate add host \
hci-aggregate computehci0.overcloud.example.com
```
##### Enable the Host Aggregate
```
openstack aggregate set \
--property computehci=true hci-aggregate
```
##### Show info about the Host Aggregate
```
openstack aggregate show hci-aggregate
```
##### Create a FLAVOR that called default-hci
```
openstack flavor create \
--ram 1024 --disk 10 --vcpus 2 --public default-hci
```
##### Set the computehci property on the Flavor as true
```
openstack flavor set \
default-hci --property computehci=true
```
##### Show the Flavor details
```
openstack flavor show default-hci
```
#####
##### MIGRATION AND EVACUATION #####
#####
##### as the Openstack user
##### Use the openstack compute service list command to verify that the compute nodes are enabled
```
openstack compute service list \
--service nova-compute -c Binary -c Host -c Status -c State
```
##### Use the openstack server list command to list all INSTANCES running on compute0
```
openstack server list \
--host compute0.overcloud.example.com --all-projects \
-c ID -c Name -c Status
```
##### Use the openstack compute service set command to disable the nova-compute service on compute0 so that it no longer schedules new instances
```
openstack compute service set \
compute0.overcloud.example.com nova-compute --disable
```
##### Use the nova host-evacuate-live command to evacuate the remaining servers from compute0
```
nova host-evacuate-live compute0
```
##### Enable nova-compute service on compute0 node 
```
openstack compute service set \
compute0.overcloud.example.com nova-compute --enable
```
##### Use the openstack server migrate command to migrate finance-server2. 
```
openstack server migrate \
<finance-server2 ID> \
--live compute0.overcloud.example.com
```