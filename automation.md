#### Configure vim for yaml ####
#### If you use vim for YAML editing, configure the indentation features by adding the following syntax to your /home/student/.vimrc file
```
autocmd FileType yaml setlocal ai ts=2 sw=2 et
```
### Orchestration with HEAT ###
#####
##### deploy a stack
```
openstack stack \
create -e environment-app1.yaml -t finance-app1.yaml --wait finance-app1
```
##### list HEAT templates versions
```
we must use the same HOT version for all the template and environment files used for a single stack and declare the heat_template_version in the template
```
```
openstack orchestration template version list
```
#####
##### 1. DEFINING INPUT PARAMETERS - are defined using input parameters
#####
```
parameters:
  web_image_name:
    type: string
    default: rhel8-web
    description: Image used for web server
    constraints:
      - custom_constraint: glance.image
```
```type:``` The supported data types are string, number, JSON, comma-delimited list, and Boolean.</br>
```default:``` The value to use if no overriding parameter value is passed in to the template.</br>
```hidden:``` When set to true, hides the parameter value from the created stack's viewable information.</br>
```constraints:``` Constraints applies validation for the input parameter value. The constraints attribute can
apply to lists of different constraints.</br>
```immutable:``` When set to true, disallows modifying the initially declared parameter value and will cause a
stack creation or update to fail if a change to the parameter value is attempted.
</br></br>
The parameter name and type are required, other attributes are optional. The hidden and
immutable attributes default to false. The custom_constraints attribute adds resource
verification, implemented using orchestration plug-ins.

#####
##### 2. DEFINING RESOURCES - are defined as a separate block with their required attributes and properties
#####

```
resources:
  web_wait_handle:
    type: OS::Heat::WaitConditionHandle

  web_wait_condition:
    type: OS::Heat::WaitCondition
    properties:
      handle: { get_resource: web_wait_handle }
      count: 1
      timeout: 600

  web_server:
    type: OS::Nova::Server
    properties:
      name: { get_param: web_instance_name } 
      image: { get_param: web_image_name }
      flavor: { get_param: instance_flavor }
      key_name: { get_param: key_name }
      networks:
        - port: { get_resource: web_net_port }
      user_data_format: RAW
      user_data:
        str_replace:
          template: { get_file: /home/student/heat/webserver.sh }
          params:
            $web_private_ip: {get_attr: [web_net_port,fixed_ips,0,ip_address]}
            $db_private_ip: {get_attr: [db_net_port,fixed_ips,0,ip_address]}
            $web_public_ip: {get_attr: [web_floating_ip,floating_ip_address]}
            $wc_notify: {get_attr: [web_wait_handle,curl_cli]}
```
```resource ID```A stack-unique, user-defined resource name.</br>
```type```The core OpenStack resource types are included in the orchestration engine. Orchestration supports 
resource plug-ins to provide custom resource handling or to override the built-in resource implementation.</br>
```properties```This attribute specifies properties associated with a resource type. The property value can be
hard-coded or use an intrinsic function to retrieve its value.</br>
#####
##### List the available resource types in Openstack
#####
```
openstack orchestration resource type list
```
#####
##### Show the resource type structure in Openstack
#####
```
openstack orchestration \
resource type show OS::Octavia::PoolMember
```
##### Example - Deploy 4 instances, with diff names %index% concatenates the 2 strings with a diff value
```
resources:
  my_4_servers:
    type: OS::Heat::ResourceGroup
    properties:
      count: 4
      resource_def:
        type: OS::Nova::Server
        properties:
          name:
            list_join: [ "%index%", [ "webserver", ".overcloud.example.com" ] ]
          image: { get_param: instance_image } 
```
###### The above example will create:
```
webserver0.overcloud.example.com
webserver1.overcloud.example.com
webserver2.overcloud.example.com
webserver3.overcloud.example.com
```
#####
##### 3. INTRINSIC FUNCTIONS - are built in functions for providing data handleling tasks, these functions are used to assign values to defined properties during stack creation
#####
###### ```get_attr``` function retrieves the value of a resource attribute. In this example, get_attr retrieves the first IP address associated with the appserver instantiated resource.
```
outputs:
  instance_ip:
    description: IP address of the instance
    value: { get_attr: [appserver, first_address] }
```
###### ```get_param``` function retrieves the value of a resource input parameter. In this example, get_param retrieves the value of the appserver_flavor input parameter to set as theflavor property value.
```
parameters:
  appserver_flavor:
    type: string
    description: Flavor to be used by the appserver.
resources:
  appserver:
    type: OS::Nova::Server
    properties:
    flavor: { get_param: appserver_flavor }
```
###### ```get_resource``` function retrieves a template resource. In this example, get_resource retrieves the appserver_port resource ID to set as the port property value.
```
resources:
  appserver_port:
    type: OS::Neutron::Port
...output omitted...

  appserver:
    type: OS::Nova::Server
    properties:
      networks:
        port: { get_resource: appserver_port }
```
###### ```str_replace``` function replaces a value, parameter or string with the return from the getattrparameter. In this example, str_replace replaces the varname in the provided template string with the getattr result, creating a URL using the IP address.
```
outputs:
  website_url:
    description: The website URL of the application.
    value:
      str_replace:
        template: http://varname/MyApps
        params:
          varname: { getattr: [ appserver, first_address ] }
```
###### ```list_join``` function appends a set of strings into a single value, separated by the specified delimiter. If the delimiter is an empty string, the strings are simply concatenated. In this example, list_join combines the appserver name with a dash and a random value to set as the instance_name property value.
```
resources:
  random:
    type: OS::Heat::RandomString
    properties:
      length: 2
appserver:
  type: OS::Nova::Server
properties:
  instance_name: { list_join: [ '-', [ {get_param: appserver_name}, {get_attr:
[random, value]} ] ] }
```
#####
##### 4. DEFINING WAIT CONDITIONS - Use wait conditions to pause stack creation and wait for the defined condition to signal that it is complete. An orchestration template defines the wait condition as the task to complete, and a wait condition handle as an autogenerated URL to which the task can send back its status.
#####
```
An orchestration template defines the wait condition as the task to complete, and a wait
condition handle as an autogenerated URL to which the task can send back its status. The time-
out and the number of signals to receive can be defined in the wait condition. A wait condition is
processed in the following sequence:
• At stack creation, the wait condition and the wait condition handle are created. The stack
reports the wait condition's status as CREATE_IN_PROGRESS. The stack deployment waits to
receive one or more success signals before the time-out period expires.
• The wait condition performs the defined procedure. The procedure includes a method to
communicate SUCCESS or FAILURE status for each task.
• If the handle receives the requisite number of SUCCESS signals before the time-out expires, the
wait condition status is set to CREATE_COMPLETE, and the stack creation continues.
• If a wait condition times out or the status received is FAILURE, the wait condition status is set to
CREATE_FAILED. The stack creation is terminated with a status of CREATE_FAILED.
To use a wait condition, define an OS::Heat::WaitConditionHandle resource, which has no
configurable properties. When instantiated, the handle resource creates a presigned URL with a
user credential token that limits access to only the handle.
```
###### 1. define the example_wait_handle
```
example_wait_handle:
  type: OS::Heat::WaitConditionHandle
```
###### 2. define Wait Condition, needs to include the wait Handle, in order for the task to be considered successful the wait condition has to be met at the defined timeout and counts

```
example_wait_condtion:
  type: OS::Heat::WaitCondition
  properties:
    handle: { get_resource: example_wait_handle }
    count: 2
    timeout: 600
```
###### 3. create the procedure for each wait condition including the method for contacting the handle with the final task status.
###### In this example, example_notify uses curl to access the wait condition handle using the handle's limited access token. The example procedure is a Bash script passed to the instance as a user_data script.
```
resources:
  example_server:
    type: OS::Nova::Server
    properties:
...output omitted...
      user_data:
        str_replace:
          template: |
            #!/bin/bash
            echo $(hostname) > /tmp/test1
            [[ -f /tmp/test1 ]] && example_notify --data-binary \
            '{"status": "SUCCESS", "reason": "signal1"}'
            echo $(whoami) > /tmp/test2
            [[ -f /tmp/test2 ]] && example_notify --data-binary \
            '{"status": "SUCCESS", "reason": "signal2"}'
          params:
            example_notify: { get_attr: [example_wait_handle, curl_cli] }
```
#####
#### INSTANCE CONFIGURATION with Orchestration ####
#####
##### 1. User_data Script Method
Specify the script format and other information with the ```user_data``` 
property of the ```OS::Nova::Server``` resource type.</br> 
The contents of the ```user_data_format``` property specifies how the instance processes the ```user_data```.</br> 
Specifying RAW passes the contents of the ```user_data property``` unmodified. </br>
In the following example, ```user_data``` uses the ```str_replace``` function to replace ```$demo``` in the script template.</br> 
When the instance is launched, the script creates a file named ```/tmp/demofile```.</br>
```
resources:
  appserver:
    type: OS::Nova::Server
    properties:
...output omitted...
      user_data_format: RAW
      user_data:
        str_replace:
          template: |
            #/bin/bash
            echo "Hello World" > /tmp/$demo
        params:
          $demo: demofile
```
We can pass a script file to the ```str_replace: template:``` like this:
```
user_data:
  str_replace:
    template: { get_file: demoscript.sh }
  params:
    $demo: demofile
```
##### 2. Software Deployment Resource Method
The ```OS::Heat::SoftwareDeployment``` resource type is designed to initiate software
configuration changes without needing to replace the instance. </br>
The SoftwareDeployment resource type applies the defined SoftwareConfig. Set the
values for the input variables defined in the SoftwareConfig. The SoftwareDeployment
state changes to IN_PROGRESS when the software configuration with the new input variable
values is made available to the instance. The state changes to CREATE_COMPLETE when an
agent notifies the Orchestration engine of the software configuration return code.
```
resources:
  the_deployment:
    type: OS::Heat::SoftwareDeployment
    properties:
      server: { get_resource: the_server }
    actions:
      - CREATE
      - UPDATE
    config: { get_resource: the_config }
    input_values:
      filename: demofile
      content: 'Hello World'
```
#####
#### DEPLOYING a STACK WITH HEAT - EXAMPLE #### 
#####
###### Deployment files 
1. Environment parameters file [/heat-automation/environment-app1.yaml](./heat-automation/environment-app1.yaml)</br>
2. Stack deployment file [/heat-automation/finance-app1.yaml](./heat-automation/finance-app1.yaml)</br>
3. Web Server configs script [/heat-automation/webserver.sh](./heat-automation/webserver.sh)</br>
4. Db Server configs scripts [/heat-automation/dbserver.sh](./heat-automation/dbserver.sh)</br>
5. dbserver.sh script relies on ansible to config the DB, files located here:[/db-role/](./db-role/)

######

1. ###### Environment parameters [/heat-automation/environment-app1.yaml](./heat-automation/environment-app1.yaml), contains some parameters that are used in finance-app1.yaml
```
parameters:
  web_image_name: rhel8-app1-web
  db_image_name: rhel8-app1-db
  web_instance_name: finance-web
  db_instance_name: finance-db
  instance_flavor: default
  key_name: example-keypair
  public_net: provider-datacentre
  private_net: finance-network1
  private_subnet: finance-subnet1
```

2. ###### Stack deployment file [/heat-automation/finance-app1.yaml](./heat-automation/finance-app1.yaml), contains the definitions for parameters, resources and outputs needed for the stack deployment
###### get_param: values are populated from environment-app1.yaml
###### web_server user configs are done from webserver.sh, the script file receives variables from the output: section of finance-app1.yaml
###### web_wait_condition has to be met in order for the deployment to be considered succsessfull, web_wait_condition sends its result to the web_wait_handle

```
heat_template_version: queens
description: multi-tier stack template
```
###### PARAMENTER SECTION, here we define parameters to be used in the resource deployment ######
###### some of these params have default values that are overwritten by values from environment-app1.yaml file
```
parameters:
  web_image_name:
    type: string
    default: rhel8-web
    description: Image used for web server
    constraints:
      - custom_constraint: glance.image
  db_image_name:
    type: string
    default: rhel8-db
    description: Image used for DB server
    constraints:
      - custom_constraint: glance.image
  web_instance_name:
    type: string
    default: finance-server1
    description: Name for the web server
  db_instance_name:
    type: string
    default: finance-server2
    description: Name for the DB server
  key_name:
    type: string
    default: example-keypair
    description: SSH key to connect to the servers
    constraints:
      - custom_constraint: nova.keypair
  instance_flavor:
    type: string
    default: default
    description: flavor used by the servers
    constraints:
      - custom_constraint: nova.flavor
  public_net:
    type: string
    default: provider-datacentre
    description: Name of public network into which servers get deployed
    constraints:
      - custom_constraint: neutron.network
  private_net:
    type: string
    default: finance-network1
    description: Name of private network into which servers get deployed
    constraints:
      - custom_constraint: neutron.network
  private_subnet:
    type: string
    default: finance-subnet1
    description: Name of private subnet into which servers get deployed
    constraints:
      - custom_constraint: neutron.subnet
```
###### RESOURCES SECTION, here we define the stack resources ######
###### we use intrisec functions to set values to resource properties 
###### get_param function retrieves the value of a resource input parameter
###### get_attr function retrieves the value of a resource attribute
###### get_resource function retrieves a template resource
```
resources:
  web_wait_handle:
    type: OS::Heat::WaitConditionHandle

  db_wait_handle:
    type: OS::Heat::WaitConditionHandle

  web_wait_condition:
    type: OS::Heat::WaitCondition
    properties:
      handle: { get_resource: web_wait_handle }
      count: 1
      timeout: 600

  db_wait_condition:
    type: OS::Heat::WaitCondition
    properties:
      handle: { get_resource: db_wait_handle }
      count: 1
      timeout: 800

  web_server:
    type: OS::Nova::Server
    properties:
      name: { get_param: web_instance_name }
      image: { get_param: web_image_name }
      flavor: { get_param: instance_flavor }
      key_name: { get_param: key_name }
      networks:
        - port: { get_resource: web_net_port }
      user_data_format: RAW
      user_data:
        str_replace:
          template: { get_file: /home/student/heat/webserver.sh }
          params:
            $web_private_ip: {get_attr: [web_net_port,fixed_ips,0,ip_address]}
            $db_private_ip: {get_attr: [db_net_port,fixed_ips,0,ip_address]}
            $web_public_ip: {get_attr: [web_floating_ip,floating_ip_address]}
            $wc_notify: {get_attr: [web_wait_handle,curl_cli]}

  web_net_port:
    type: OS::Neutron::Port
    properties:
      network: { get_param: private_net }
      fixed_ips:
        - subnet: { get_param: private_subnet }
      security_groups: [{ get_resource: web_security_group }]

  web_floating_ip:
    type: OS::Neutron::FloatingIP
    properties:
      floating_network: { get_param: public_net }
      port_id: { get_resource: web_net_port }

  web_security_group:
    type: OS::Neutron::SecurityGroup
    properties:
      description: Add security group rules for the multi-tier architecture
      name: finance-web
      rules:
        - remote_ip_prefix: 0.0.0.0/0
          protocol: tcp
          port_range_min: 22
          port_range_max: 22
        - remote_ip_prefix: 0.0.0.0/0
          protocol: tcp
          port_range_min: 80
          port_range_max: 80
        - remote_ip_prefix: 0.0.0.0/0
          protocol: icmp

  db_server:
    type: OS::Nova::Server
    properties:
      name: { get_param: db_instance_name }
      image: { get_param: db_image_name }
      flavor: { get_param: instance_flavor }
      key_name: { get_param: key_name }
      networks:
        - port: { get_resource: db_net_port }
      user_data_format: RAW
      user_data:
        str_replace:
          template: { get_file: /home/student/heat/dbserver.sh }
          params:
            $db_wc_notify: {get_attr: [db_wait_handle,curl_cli]}

  db_net_port:
    type: OS::Neutron::Port
    properties:
      network: { get_param: private_net }
      fixed_ips:
        - subnet: { get_param: private_subnet }
      security_groups: [{ get_resource: db_security_group }]

  db_floating_ip:
    type: OS::Neutron::FloatingIP
    properties:
      floating_network: { get_param: public_net }
      port_id: { get_resource: db_net_port }

  db_security_group:
    type: OS::Neutron::SecurityGroup
    properties:
      description: Add security group rules for the multi-tier architecture
      name: finance-db
      rules:
        - remote_ip_prefix: 0.0.0.0/0
          protocol: tcp
          port_range_min: 22
          port_range_max: 22
        - remote_group_id: { get_resource: web_security_group }
          protocol: tcp
          port_range_min: 3306
          port_range_max: 3306
        - remote_ip_prefix: 0.0.0.0/0
          protocol: icmp
```
###### OUTPUT SECTION, retains values that become available at resource deployment
###### this values can be passed into the user_data section template scripts 
```
outputs:
  web_private_ip:
    description: Private IP address of the web server
    value: { get_attr: [ web_server, first_address ] }

  web_public_ip:
    description: External IP address of the web server
    value: { get_attr: [ web_floating_ip, floating_ip_address ] }

  db_private_ip:
    description: Private IP address of the DB server
    value: { get_attr: [ db_server, first_address ] }

  website_url:
    description: >
      This URL is the "external" URL that can be used to access the
      web server.
    value:
      str_replace:
        template: http://host/index.php
        params:
          host: { get_attr: [web_floating_ip, floating_ip_address] }
```
3. ###### Web Server configs script [/heat-automation/webserver.sh](./heat-automation/webserver.sh)
###### defined as a template under the user_data at instance creation, it configures the web server on the instance, checks if the web server deployed correctly with $response and based on this sends the status "SUCCESS" or "FAILURE" using the web_wait_handle (token + curl_cli)
```
#!/bin/bash
yum install -y httpd php mysql php-mysqlnd
curl -f -o /tmp/web-role.tar.gz http://materials.example.com/heat/resources/web-role.tar.gz
cd /tmp; tar zxvf web-role.tar.gz
cd /tmp/web-role/; cp -rf index.html about.html /var/www/html
touch /var/www/html/index.php
cat << EOF > /var/www/html/index.php
<html>
<head>
  <title>Example Application</title>
</head>
<body>
  <hr>
    <a href=http://$web_public_ip/index.html>Homepage</a>
    <a href=http://$web_public_ip/about.html>About</a>
  </hr>
  <h2>Hello, World!
  <h2>This web server was configured using OpenStack orchestration,</h2>
  <h2>and is running on the <?php echo gethostname(); ?> host.</h2>
  <hr>
  <br>
    List of databases on the MySQL server:
  </br>
<?php
  \$link = mysqli_connect('$db_private_ip', 'admin', 'redhat') or die(mysqli_connect_error(\$link));
  \$res = mysqli_query(\$link, 'SHOW DATABASES;');
?>
  <table border='2'>
   <tr>
    <th>Name</th>
   </tr>
<?php
  while (\$row = mysqli_fetch_assoc(\$res))
  {
?>
   <tr>
    <td><?php echo \$row['Database'];?></td>
   </tr>
  <?php }?>
  </table>
</body>
</html>
EOF
setsebool -P httpd_can_network_connect_db=true
systemctl restart httpd; systemctl enable httpd
export response=$(curl -s -k \
--output /dev/null \
--write-out %{http_code} http://$web_public_ip/)
[[ ${response} -eq 200 ]] && $wc_notify \
--data-binary '{"status": "SUCCESS"}' \
|| $wc_notify --data-binary '{"status": "FAILURE"}'
```
###### 4. Db Server configs scripts [/heat-automation/dbserver.sh](./heat-automation/dbserver.sh) 
###### defined as a template under the user_data at instance creation, it configures the db server on the instance and checks for creation, passes the result to db_wait_handle
##### runs ansible to deploy the DB 
```
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
```
###### 5. dbserver.sh script relies on ansible to config the DB, files located here:[/db-role/](./db-role/)
</br>

##### DEPLOY THE STACK
```
openstack stack \
create -e environment-app1.yaml -t finance-app1.yaml --wait finance-app1
```