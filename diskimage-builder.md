##### DISKIMAGE-BUILDER 
##### is used to create customized images for Openstack
##### install diskimage-builder
```
dnf install diskimage-builder -y
```
##### diskimage-builder works by running scripts that are found in the directories here
```
/usr/share/diskimage-builder/elements
```
##### works in diff phases
```
Phase Subdirectory Description
```
##### root.d 
```
Builds or modifies the initial root file system content. This
is where customizations are added, such as building on an
existing image. Only one element can use this at a time unless
particular care is taken not to overwrite, but instead to adapt
the context extracted by other elements. Content extracted
by previous elements should be adapted; take care not to
overwrite it.
```
##### extra-data.d 
```
Includes extra data from the host environment that hooks may
need when building the image. This copies any data, such as
SSH keys, or HTTP proxy settings, under $TMP_HOOKS_PATH.
```
##### pre-install.d 
```
Prior to any customization or package installation, this code
runs in a chroot environment.
```
##### install.d 
```
In this phase the operating system and packages are installed.
This code runs in a chroot environment.
```
##### post-install.d 
```
This is the recommended phase to use for performing
tasks that must be handled after the operating system and
application installation, but before the first boot of the image.
For example, running systemctl enable to enable required
services.
```
##### block-device.d 
```
Customizes the block device, for example, to make partitions.
Runs before the cleanup.d phase runs, but after the target
tree is fully populated.
```
##### finalize.d 
```
Runs in a chroot environment upon completion of the root
file-system content being copied to the mounted file system.
The root file system is tuned in this phase, so it is important to
limit the operations to only those necessary to affect the filesystem metadata and the image itself. post-install.d is
preferred for most operations.
```
##### cleanup.d 
```
The root file-system content is cleaned of temporary files.
```
##### to customize the image OS after all the packages are installed we edit
##### post-install.d directory under the working copy of the rhel element, since this is a rhel image
```
mkdir -p /home/student/elements/rhel/post-install.d
```
#### add customization scripts to the above directory and make them executable
```
cd /home/student/elements/rhel/post-install.d
```
```
cat <<EOF > 02-configure-named
#!/bin/bash
# add forwarders
sed -i 's|\(.*\)\(recursion yes;\)|\1\2\n\1forwarders {172.25.250.254;};|' \
/etc/named.conf
```
```
cat <<EOF > 02-configure-named
#!/bin/bash
# add forwarders
sed -i 's|\(.*\)\(recursion yes;\)|\1\2\n\1forwarders {172.25.250.254;};|' \
/etc/named.conf

# allow queries from the local subnet
sed -i 's|\(.*allow-query\).*|\1 { localhost; 192.168.1.0/24; };|' \
/etc/named.conf

# disable dnssec validation
sed -i 's|\(.*dnssec-validation\).*|\1 no;|' /etc/named.conf
EOF
```
```
chmod +x /home/student/elements/rhel/post-install.d/*
```
##### set the below variables before running the diskimage-builder
```
export DIB_LOCAL_IMAGE=/home/student/osp-small.qcow2
export DIB_YUM_REPO_CONF=/etc/yum.repos.d/openstack.repo
export ELEMENTS_PATH=/home/student/elements
export DIB_NO_TMPFS=1
```
##### run disk-image-create, vm -image for virt machine, rhel-based on rhel base image, type qcow2, -p bind, bind-utils - install these
##### also use tee to save the stdout and stder to a log file 
```
disk-image-create vm rhel \
-t qcow2 \
-p bind,bind-utils \
-o finance-rhel-dns.qcow2 2>&1 | tee diskimage-build.log
```
##### upload the finance-rhel-dns.qcow2 disk image to the OpenStack Image service as finance-rhel-dns, with a minimum disk requirement of 10 GiB, and a minimum RAM requirement of 2 GiB
```
openstack image create \
--disk-format qcow2 \
--min-disk 10 \
--min-ram 2048 \
--file ~/finance-rhel-dns.qcow2 \
finance-rhel-dns
```
##### create an Openstack Instance based on this image
```
openstack server create \
--flavor default \
--key-name example-keypair \
--nic net-id=finance-network1 \
--image finance-rhel-dns \
--security-group finance-dns \
--config-drive true \
--wait finance-dns1
```

#####
##### Use GUESTFISH to modify qcow2 images, another great tool 
##### enter guestfish shell on the image with image network access
```
guestfish -i --network -a ~/finance-rhel-db.qcow2
```
##### install these packages on the image
```
command "dnf -y install mariadb mariadb-server"
```
##### enable mariadb service
```
command "systemctl enable mariadb"
```
##### check the service is enabled
```
command "systemctl is-enabled mariadb"
```
##### create selinux relabeling to ensure that the SELinux contexts for all affected files are correct.
```
selinux-relabel /etc/selinux/targeted/contexts/files/file_contexts /
``` 
##### exit guestfish shell
```
exit
```
#####
##### Another tool for editing images is VIRT-CUSTOMIZE
#####
##### Enable the postfix service, configure postfix to listen on all interfaces, and relay all mail to workstation.lab.example.com. Install the mailx package to enable sending a test email. Ensure the SELinux contexts are restored.
```
virt-customize \
-a ~/finance-rhel-mail.qcow2 \
--run-command 'dnf -y install postfix mailx' \
--run-command 'systemctl enable postfix' \
--run-command 'postconf -e "relayhost = [workstation.lab.example.com]"' \
--run-command 'postconf -e "inet_interfaces = all"' \
--selinux-relabel
```
#####
##### edit INSTANCES using CLOUD-INIT
#####
##### create a cloud-init config file
```
vim user-data.yaml
```
```
# ssh key needs to be inline the only space is before Generated-by-Nova
#cloud-config
users:
  - name: cloud-admin
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDHufCmzG95rJkXHZOe+7rHMaf3me7geAfdYAc2fuoKjSVoBni4aF4MYkSmb1UYyXjtQ++x2+i13+Osn9FJZmvda0maqT6DuIcpiAxldVrnNJFv5L1VFGiFDbUglThPc25Ytn7bWqg02pFJz4Nc9vN+PzVETevL8b0tMvWPQ44MRuXCCM+UaHO1mBD2pcEnpQ1R/MzYxTzzdvjP5iBn4GAp7KjUw/+FvBhlNiKsXJjQGl6MHbCZhtgsntJzl7tKGY4SgJXZaUD0TnpPeCBlEmWNUz4hAoVMfiiZA4fLAmJ7yZqwRcr4EVnqbmZC6CfIhVxb1J69UHhK62KS6513MP3v Generated-by-Nova
packages:
  - aide
  - nmap
  - socat
  - wireshark
```
#### create the openstack instance with the user-data.yaml file
```
openstack server create \
--flavor default \
--key-name example-keypair \
--nic net-id=finance-network1 \
--security-group default \
--image rhel8 \
--user-data ~/user-data.yaml \
--config-drive true \
--wait finance-admin1
```