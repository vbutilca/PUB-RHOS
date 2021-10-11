#### NETWORKING ####
####
#### CREATE PROVIDER NETWORKS ####
##### from controller
##### determine the available physical networks where you can create provider networks
##### Use the ovs-vsctl command to display the ovn-bridge-mappings configuration. This output lists which bridges are mapped to physical interfaces and are available for use as provider networks
```
ovs-vsctl get open . external-ids:ovn-bridge-mappings
```
###### "datacentre:br-ex,vlanprovider1:br-prov1,vlanprovider2:br-prov2,storage:br-trunk"
###### The datacentre mapping is already in use to provide the flat external network. The storage mapping allows instances to mount CephFS volumes. This leaves vlanprovider1 and vlanprovider2 available for provider networks.
######
##### Use the ovs-vsctl command to display the br-prov1 and br-prov2 bridges
```
ovs-vsctl show
```
##### Determine whether VLAN ID ranges have been defined for any of the bridge mappings
```
grep ^network_vlan_ranges \
/var/lib/config-data/puppet-generated/neutron/etc/neutron/plugins/ml2/ml2_conf.ini
```
##### as Openstack admin user
##### create a provider network with vlan 103
```
openstack network create \
--external \
--share \
--provider-network-type vlan \
--provider-physical-network vlanprovider1 \
--provider-segment 103 \
provider1-103
```
##### Create the subnet1-103 subnet
```
openstack subnet create \
--dhcp \
--subnet-range=10.0.103.0/24 \
--allocation-pool=start=10.0.103.100,end=10.0.103.149 \
--network provider1-103 \
subnet1-103
```
##### Create an INSTANCE and attach it to the created network
```
openstack server create \
--flavor default \
--image rhel8 \
--key-name example-keypair \
--config-drive true \
--network provider1-103 \
--wait \
finance-server1
```
####
#### Open Virtual Networking ####
####
##### from controller
##### Log in to the controller0 node and become root. Use the crudini command to inspect the OVN configuration
```
cd /var/lib/config-data/puppet-generated/neutron
```
```
crudini --get etc/neutron/plugins/ml2/ml2_conf.ini \
ml2 mechanism_drivers
```
```
crudini --get etc/neutron/plugins/ml2/ml2_conf.ini \
ml2 tenant_network_types
```
##### Use the podman command to list the OVN containers. 
```
podman ps -f name=ovn
```
##### Determine the listening socket for the OVN Northbound and Southbound databases.
```
ovs-vsctl list open
```
##### Use the ovs-vsctl show command to print an overview of the database contents.
##### list the configuration of the bridges
```
ovs-vsctl show
```
##### as the Openstack project admin
##### Use the openstack network list command to list the networks
```
openstack network list -c ID -c Name
```
##### as the Openstack project admin
##### use the openstack hypervisor list command to list the compute nodes
```
openstack hypervisor list \
-c "Hypervisor Hostname" -c "Host IP"
```
##### from compute node
##### list VLAN networks
```
ip link 
```
##### from compute node 
##### capture traffic between instances on diff nodes
```
tcpdump -ten -i vlan20 | grep ICMP
```
##### from controller
##### determine the IP address and port of the OVN Northbound database
```
ss -4l | grep 6642
```
##### from controller
##### Use the ovn-nbctl show command on the controller node to inspect the Northbound database.
```
podman exec -ti \
ovn_controller ovn-nbctl --db=tcp:172.24.1.52:6641 show
```
##### Use the ovsn-sbctl lflow-list command to list the OpenFlow flows for the Southbound database
```
podman exec -ti \
ovn_controller ovn-sbctl --db=tcp:172.24.1.52:6642 lflow-list \
finance-network1 > flow.txt
```
##### List the ACLs in the Northbound database.
```
podman exec -ti \
ovn-dbs-bundle-podman-0 ovn-nbctl --db=tcp:172.24.1.52:6641 list acl > acl.txt
```
##### Use the ovn-nbctl command to list the information for the logical router
```
podman exec -ti ovn_controller \
ovn-nbctl --db=tcp:172.24.1.52:6641 list Logical_Router
```
##### dump flow rules for br-ex
```
ovs-ofctl show br-ex
```
```
ovs-ofctl dump-flows br-ex
```
####
#### OVN SERVICES ####
####
##### As an Openstack project member
##### create an instance 
```
openstack server create \
--flavor default \
--image rhel8 \
--key-name example-keypair \
--config-drive true \
--network finance-network1 \
--security-group dev-web \
--wait \
finance-server3
```
##### get the ID of the port associated with finance-server3
```
openstack port list \
--server finance-server3 -f json
```
##### from controller
##### Use the ovn-sbctl lflow-list command in the ovn_controller container to view the DHCP flow rules for finance-server3
```
podman exec -ti ovn_controller \
ovn-sbctl lflow-list | grep <instance PORT ID> | grep dhcp
```
##### As an Openstack project member
##### add an inbound rule to the dev-web security group, allowing TCP traffic on port 8080
```
openstack security group rule \
create --protocol tcp --dst-port 8080:8080 dev-web
```
##### determine the ID of the group security rule
```
openstack security group list -f json
```
##### from controller
##### On controller0, use the ovn-sbctl lflow-list command in the ovn_controller container to view the flow rules for the dev-web security group. You will need the dev-web ID with the hyphens converted to underscores to filter the rules, so use the following command or manually replace them.
```
echo 5e819a11-ee85-4b14-9178-e2fa2950af8a | tr - _
```
```
podman exec -ti ovn_controller \
ovn-sbctl lflow-list | grep 5e819a11_ee85_4b14_9178_e2fa2950af8a
```