##### UNDERCLOUD #####
##### all services deployed as containers

##### from director
##### passwords for Undercloud are stored in ~/undercloud-passwords.conf
```
cat undercloud-passwords.conf
```
##### from director
##### verify UNDERCLOUD network settings
##### The undercloud.conf file contains the parameters required to install the undercloud
```
cat ~/undercloud.conf | egrep -v "(^#.*|^$)"
ip -br a
```
##### The inspection_iprange parameter is the list of addresses offered by the Bare Metal
##### dnsmasq service, temporarily assigned to registered nodes during the PXE boot that begins the
##### introspection process. 

##### from director
##### find and register available baremetal nodes that can be used to deploy the Overcloud 
```
openstack baremetal node list \
-c Name -c 'Power State' -c 'Provisioning State'
```
##### from director
##### view images used for the overcloud deployment
```
sudo podman images --format="{{.Repository}}"
```
<!-- The undercloud contains a default set of TripleO overcloud templates, with many optional
configuration environment files, in the /usr/share/openstack-tripleo-heat-templates/
directory. The Orchestration service manages an overcloud deployment using these templates
and environment files to determine and configure each selected node with an assigned role. -->

##### from director
##### we set parameters for the OVERCLOUD nodes using a json file
```
cat instackenv-initial.json
```
##### json file example
```
{
"nodes": [
{
"name": "controller0",
"arch": "x86_64",
"cpu": "2",
"disk": "40",
"memory": "8192",
"mac": [ "52:54:00:00:f9:01" ],
"pm_addr": "172.25.249.101",
"pm_type": "pxe_ipmitool",
"pm_user": "admin",
"pm_password": "password",
"pm_port": "623",
"capabilities": "node:controller0,boot_option:local"
},
...output omitted...
```
##### from director
##### we can use IPMI to manage power capabilities nodes with the ipmitool 
##### get power status
```
ipmitool -I lanplus \
-U admin -P password -H 172.25.249.101 power status
```
##### from director
##### by default we have the env set for the UNDERCLOUD
##### to change source the overcloud rc file
```
source ~/overcloudrc
```
##### list Controllers
##### ssh to director and list openstack servers
```
openstack server list
openstack server list \
-c 'Name' -c 'Status' -c 'Networks'
```
##### ssh to director
##### list networks
```
openstack network list
```
##### ssh to director
##### list subnets
```
openstack network list
```
##### ssh to director
##### show subnet info, dhcp, allocation pools
```
openstack subnet show <subnet_name/id>
```
##### ssh to director
##### type of services 
```
openstack service list
```
##### ssh to director
##### show connectivity data for all the services, for public, admin, internal network
```
openstack endpoint list
```

##### INSTALL/BKP/RECOVERY WITH REAR

##### from director
#### PREREQUISITES
##### generate nfs-inventory.ini file
```
cat <<'EOF'> ~/nfs-inventory.ini
[BACKUP_NODE]
backup ansible_host=<IP_ADDRESS> ansible_user=<USER>
EOF
```
#### generate bar_nfs_setup.yaml 
```
cat <<'EOF'> ~/bar_nfs_setup.yaml
# Playbook
# Substitute <BACKUP_NODE> with the host name of your backup node.
- become: true
hosts: <BACKUP_NODE>
name: Setup NFS server for ReaR
roles:
- role: backup-and-restore
EOF
```
##### generate bar_rear_setup-undercloud.yaml file for installing rear on the undercloud
```
cat <<'EOF'> ~/bar_rear_setup-undercloud.yaml
# Playbook
# Installing and configuring ReaR on the undercloud node
- become: true
hosts: undercloud
name: Install ReaR
roles:
- role: backup-and-restore
EOF
```
##### generate bar_rear_setup-controller.yaml file for installing rear on the controller
```
cat <<'EOF'> ~/bar_rear_setup-controller.yaml
# Playbook
# Installing and configuring ReaR on the control plane nodes
- become: true
hosts: Controller
name: Install ReaR
roles:
- role: backup-and-restore
EOF
```
##### create yaml file for undercloud BKP bar_rear_create_restore_images-undercloud.yaml
```
cat <<'EOF'> \
> ~/bar_rear_create_restore_images-undercloud.yaml
# Playbook
# Using ReaR on the undercloud node.
- become: true
hosts: undercloud
name: Create the recovery images for the undercloud
roles:
- role: backup-and-restore
EOF
```
##### create yaml file for undercloud BKP bar_rear_create_restore_images-controller.yaml
```
cat <<'EOF'> \
> ~/bar_rear_create_restore_images-controller.yaml
# Playbook
# Using ReaR on the control plane nodes.
- become: true
hosts: Controller
name: Create the recovery images for the control plane
roles:
- role: backup-and-restore
EOF
```
##### SET-up the backup NODE
```
ansible-playbook -v -i ~/nfs-inventory.ini \
--extra="ansible_ssh_common_args='-o StrictHostKeyChecking=no'" \
--become --become-user root --tags bar_setup_nfs_server \
~/bar_nfs_setup.yaml
```
##### Use the tripleo-ansible-inventory command to create a static inventory file of the
##### control plane
```
tripleo-ansible-inventory \
--ansible_ssh_user heat-admin \
--static-yaml-inventory /home/stack/tripleo-inventory.yaml
```
##### Install and configure ReaR on the director server. Run the Ansible Playbook
##### bar_rear_setup-undercloud.yaml file, using tripleo-inventory.yaml as the
##### inventory file
```
ansible-playbook -v -i ~/tripleo-inventory.yaml \
--extra="ansible_ssh_common_args='-o StrictHostKeyChecking=no'" \
--become --become-user root --tags bar_setup_rear \
~/bar_rear_setup-undercloud.yaml
```
##### Install and configure ReaR on the controller0 server. Run the Ansible Playbook
##### bar_rear_setup-controller.yaml file, using tripleo-inventory.yaml as the
##### inventory file.
```
ansible-playbook -v -i ~/tripleo-inventory.yaml \
-e tripleo_backup_and_restore_exclude_paths_controller_non_bootrapnode=false \
--extra="ansible_ssh_common_args='-o StrictHostKeyChecking=no'" \
--become --become-user root --tags bar_setup_rear \
~/bar_rear_setup-controller.yaml
```
##### Create a backup of the director server. Run the Ansible Playbook
##### bar_rear_create_restore_images-undercloud.yaml file, using tripleo-inventory.yaml as the inventory file.
```
ansible-playbook -v -i ~/tripleo-inventory.yaml \
--extra="ansible_ssh_common_args='-o StrictHostKeyChecking=no'" \
--become --become-user root --tags bar_create_recover_image \
~/bar_rear_create_restore_images-undercloud.yaml
```



##### OVERCLOUD #####

#################### PACEMAKER / HIGH AVAILABILITY SERVICES / BUNDLES ####################

##### from controller
##### check Peacemaker status
```
sudo pcs status
```
##### get more info on pcs galera-bundle
```
pcs resource config galera-bundle
```
##### disable/enable pcs resource
```
pcs resource disable/enable galera-bundle
```
##### from controller or director
##### access the OVERCLOUD
```
source ~/overcloudrc
```

#################### GET CONTAINER INFO ####################

##### from controller
##### list images
```
sudo podman images
```
##### from controller
##### list all containers 
```
sudo podman ps -a \
--format="table {{.Names}} {{.Status}}" 
```
##### from controller
##### list all running containers, formated output by ID/Name/Status 
```
sudo podman ps --filter status=running \
--format="table {{.ID}} {{.Names}} {{.Status}}"
```
##### from controller 
##### check memmory usage/limits for cinder_api container
```
podman stats cinder_api
```
##### from controller
##### inspect Openstack service details
```
sudo podman inspec cinder_api 
```
##### from controller 
##### inspect Openstack service and filter output using jq
##### in this case get host/POD mountpoints host=source destination=container
##### we can share config data to and from the container using mount points, 
##### which are similar to shares from the host to the container 
```
sudo podman inspect cinder_api | jq .[0].Mounts
```

#################### EXEC COMMANDS in containers ####################

##### from controller
##### acess a container
```
sudo podman exec -it keystone /bin/bash
```
##### run hostname command in keystone container
```
sudo podman exec keystone hostname
```
##### from controller
##### access a container as a specific user
```
sudo podman exec --user 0 -it <container_name> /bin/bash
```
#################### TRIPLEO SERVICES ####################

##### from controller
##### some of the Openstack containers are managed by systemd, so we can
##### verify the status of these components
```
sudo systemctl status tripleo_cinder_api
```
##### from controller
##### view how sysmtemd manages the container
```
cat /etc/systemd/system/tripleo_cinder_api.service
```
##### from controller
##### to start, stop, restart a managed Openstack container
```
sudo systemctl start/stop/restart tripleo_cinder_api
```
##### from controller
##### list tripleo_ services
```
sudo ls /etc/systemd/system/tripleo_*.service
```
##### from controller
##### systemd monitor's container health by using timers
##### see systemctl timer info 
```
sudo systemctl list-timers | grep tripleo
```
```
sudo systemctl status \
tripleo_cinder_api_healthcheck.timer
```

#################### LOGS ####################

##### from controller
##### get logs from a container
```
sudo podman logs cinder_api
```
```
sudo podman logs --since 3h
```
##### from controller 
##### stdout and stderr are consolidated here for all the containers 
```
sudo ls -1 /var/log/containers/stdouts
```
##### from controller
##### container configuration files are located at
```
sudo ls -1 /var/lib/config-data/puppet-generated/
```
#################### NETWORKING ####################

##### from controller
##### view configured networks on the Overcloud
```
ip -br a
```
```
ip -br a | grep -E 'eth0|br-ex'
```
##### from controller
##### view configured bridges
```
sudo ovs-vsctl show
```
```
sudo ovs-vsctl list-br
```
##### from controller 
##### list interfaces on br-trunk
```
sudo ovs-vsctl list-ifaces br-trunk
```
 ##### from controller
 ##### list network interfaces
```
ip -br a | grep -E 'eth0|vlan|eth2'
```
##### from controller
##### check which networks belong to a specific vlan, defined in the bridge trunk
```
ip -br a s vlan30
```
##### from controller
##### check which processes are listening on a vlan30 network for ex.
```
ss -tupln | grep 172.24.3.1
```
##### check which services are listening on port 3306
```
ss -tnlp | grep 3306
```

#################### CONTAINER CONFIG FILES ####################

##### from controller
##### get host/container config bindings for a specific container
```
podman inspect nova_scheduler \
--format "{{json .HostConfig.Binds}}" | jq .
```
##### from controller
##### use crudini to check config files in containers and host
##### check the config file on the container
```
podman exec -u root keystone crudini \
--get /etc/keystone/keystone.conf DEFAULT debug
```
##### check the same config file on the host
```
crudini --get \
/var/lib/config-data/puppet-generated/keystone/etc/keystone/keystone.conf \
DEFAULT debug
```
##### set a new config on the host share and then restart the container to set the new config
```
crudini --set \
/var/lib/config-data/puppet-generated/keystone/etc/keystone/keystone.conf \
DEFAULT debug True
```
##### restart container
```
podman restart keystone
```
##### check container config
``` 
podman exec -u root keystone crudini \
--get /etc/keystone/keystone.conf DEFAULT debug
```
#################### CEPH SERVICES ####################

##### from controller
##### view CEPH services, on controller CEPH runs MGMT and health services
```
podman ps --format "{{.Names}}" | grep ceph
```
```
systemctl list-units | grep ceph
```
```
systemctl status ceph-mon@controller0.service
```
##### from controller
##### check CEPH OSD
```
podman exec ceph-mon-controller ceph osd ls
```
##### from controller
##### check ceph stats
```
podman exec ceph-mon-controller ceph -s
```
##### from controller
##### get CEPH size/pools info
```
podman exec ceph-mon-controller ceph df
```


############ RABBITMQ #############

##### from controller
##### set a tracer on a RABBITMQ mesage
##### create a new user in RABBITMQ
```
podman exec -t rabbitmq-bundle-podman-0 rabbitmqctl \
add_user tracer redhat
```
##### set permissions for the tracer user
```
podman exec -t rabbitmq-bundle-podman-0 rabbitmqctl \
set_permissions tracer ".*" ".*" ".*"
```
##### enable trace_on the RABBITMQ container
```
podman exec -t rabbitmq-bundle-podman-0 rabbitmqctl trace_on
```
##### check the RABBITMQ container ip, the port is 5672
```
ss -tnlp | grep :5672
```
##### start tracing
##### amq.rabbitmq.trace exchange. Use the -u and -p options to specify the tracer user
##### and password. Use the -t option to provide the target IP address located in the previous
##### step. Redirect the output to /tmp/rabbit.trace for analysis.
```
~/rmq_trace.py -u tracer -p redhat \
-t 172.24.1.1 > /tmp/rabbit.trace
```
##### stop tracing
```
podman exec -t rabbitmq-bundle-podman-0 rabbitmqctl \
trace_off
```
##### see trace information from /tmp/rabbit.trace
```
vim /tmp/rabbit.trace
```
##### from controller
##### determine the TOKEN driver using crudini
```
crudini --get \
/var/lib/config-data/puppet-generated/keystone/etc/keystone/keystone.conf \
token provider
```
##### determine the catalog driver
```
crudini --get \
/var/lib/config-data/puppet-generated/keystone/etc/keystone/keystone.conf \
catalog driver
```
##### determine fernet keys repository, fernet keys are used to encrypt tokens
```
crudini --get \
/var/lib/config-data/puppet-generated/keystone/etc/keystone/keystone.conf \
fernet_tokens key_repository
```
##### determine the maximum number of fernet keys
```
crudini --get \
/var/lib/config-data/puppet-generated/keystone/etc/keystone/keystone.conf \
fernet_tokens max_active_keys
```
##### see the fernet keys on the controller, cat the contents
```
ls -l \
/var/lib/config-data/puppet-generated/keystone/etc/keystone/fernet-keys/
```

##### from director
##### rotate fernet keys
```
openstack workflow execution create \
tripleo.fernet_keys.v1.rotate_fernet_keys '{"container": "overcloud"}'
```
##### get workflow execution
```
openstack workflow execution show <workflow_id>
```
#####
######## OPENSTACK OPERATIONS #########
##### IMAGES
##### upload the finance-rhel-dns.qcow2 disk image to the OpenStack Image service as finance-rhel-dns, with a minimum disk requirement of 10 GiB, and a minimum RAM requirement of 2 GiB
```
openstack image create \
--disk-format qcow2 \
--min-disk 10 \
--min-ram 2048 \
--file ~/finance-rhel-dns.qcow2 \
finance-rhel-dns
```
##### INSTANCES
##### create an openstack instance/VM
```
openstack server create \
--image rhel8 \
--flavor default \
--security-group default \
--key-name example-keypair \
--nic net-id=finance-network1 \
finance-server2 --wait
```
##### DOMAINS
##### create a domain called Example
```
openstack domain create Example
```
##### add user admin role to user admin for the Example domain
```
openstack role add --domain Example --user admin \
admin
```
##### list users under the Example domain
```
openstack user list --domain Example -f json
```
#####
##### PROJECTS
##### Create a new project named support in the Lab domain
```
openstack project create support --domain Lab
```
##### Create a new project named dev in the support project(nested project)
```
openstack project create dev --parent support \
--domain Lab
```
##### GROUPS
##### Create a new user group named developers in the Lab domain
```
openstack group create developers --domain Lab
```
##### ROLES
##### create custom openstack role named troubleshooters
##### need to add this role later on individual containers we want to us on
```
openstack role create troubleshooters
```
##### Assign the developers group in the Lab domain the member role for the support
##### project in the Lab domain.
```
openstack role add --group developers \
--group-domain Lab --project support --project-domain Lab member
```
##### Assign the developers group in the Lab domain the member role for all the subprojects
##### of the support project in the Lab domain. Use the --inherited option to have the role
##### inherited by subprojects of the support project
```
openstack role add --group developers \
--group-domain Lab --project support --project-domain Lab --inherited member
```
##### Verify the role assignments for the support project in the Lab domain
```
openstack role assignment list --project support \
--project-domain Lab --names --effective
```
##### Verify the role assignments for the dev subproject in the Lab domain
```
openstack role assignment list --project dev \
--project-domain Lab --names --effective
```
##### USERS
##### Create the developer4 user in the Lab domain, and set the password to redhat
```
openstack user create developer4 --domain Lab \
--password redhat
```
##### Add the developer4 user of the Lab domain to the developers user group of the Lab
##### domain.
```
openstack group add user --group-domain Lab \
--user-domain Lab developers developer4
```
#####
##### NETWORKING
##### list floating IPs
```
openstack floating ip list \
-c "Floating IP Address" -c Port
```
##### add floating IP to server finance-dns1
```
openstack server add floating \
ip finance-dns1 172.25.250.110
```

#### OBJECT STORAGE
#####
##### create the object container finance-container1
```
openstack container create \
finance-container1
```
##### upload a file to a container, Upload /home/student/finance-object1 to finance-container1
```
openstack object create \
finance-container1 finance-object1
```
##### from controller
##### Locate finance-object1 in the back-end storage devices of the OpenStack object store, as per the swift back-end config the object file is stored in 2 diff locations
```
cat `find /srv/node -iname *.data`
```
####
#### EPHEMERAL/PERSISTANT STORAGE ####
####
##### By default instances use ephemeral storage for root
##### create an instance with ephemeral storage
```
openstack server create \
--flavor default \
--image rhel8 \
--key-name example-keypair \
--config-drive true \
--nic net-id=finance-network1 \
--availability-zone nova:compute1.overcloud.example.com \
finance-server1 --wait
```
##### get the ID of the instance
```
openstack server list \
-c ID -c Name
```
##### on the controller
##### Match the unique ID of the instance with the back-end object in the Ceph pool vms.
```
podman exec -it ceph-mon-controller0 rados -p vms \
ls | grep <instance ID>
```
