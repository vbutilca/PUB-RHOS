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
