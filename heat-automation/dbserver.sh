#!/bin/bash
yum install -y ansible firewalld
export ANSIBLE_LOG_PATH=~/ansible.log
curl -f -o /tmp/db-role.tar.gz http://materials.example.com/heat/resources/db-role.tar.gz
cd /tmp; tar zxvf db-role.tar.gz
cp -rf /tmp/db-role/db /etc/ansible/roles
touch /tmp/db-role/hosts
cat << EOF > /tmp/db-role/hosts
[dbservers]
localhost ansible_connection=local
EOF
cd /tmp/db-role
ansible-playbook -i hosts dbserver.yml
RES=$?
[[ "$RES" -eq 0 ]] && $db_wc_notify \
--data-binary '{"status": "SUCCESS"}' \
|| $db_wc_notify --data-binary '{"status": "FAILURE"}'
