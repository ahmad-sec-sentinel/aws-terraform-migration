#!/bin/bash
set -e

apt update -y
apt upgrade -y
apt install -y apache2 php libapache2-mod-php php-mysql

systemctl enable apache2
systemctl start apache2

cd /var/www/html

# Writing DB config from Terraform values
cat > dbconfig.php <<EOF
<?php
define('DB_SERVER',   "${rds_endpoint}");
define('DB_USERNAME', "${db_username}");
define('DB_PASSWORD', "${db_password}");
define('DB_NAME',     "${db_name}");
?>
EOF

# Writing custom index.php
cat > index.php <<'PHP'
<html>
<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css">
<body background="images/2.png" style="background-repeat:no-repeat;
background-size: 100% 100%">
<br><br><br><br>
<div class="container">
  <div class="jumbotron vertical-center">
    <table class="grid" cellspacing="0">
      <tr>
        <td colspan="4"></td>
        <td colspan="4">
          <form method="post">
            <div class="form-group" action="post">
              <label for="firstname">Name:</label>
              <input type="text" class="form-control" name="firstname">
            </div>
            <div class="form-group">
              <label for="email">Email:</label>
              <input type="text" class="form-control" name="email">
            </div>
            <button type="submit" class="btn btn-success">Submit</button>
          </form>
        </td>
        <td colspan="4"></td>
      </tr>
    </table>
  </div>
</div>
<?php
require 'dbconfig.php';

$conn = new mysqli(DB_SERVER, DB_USERNAME, DB_PASSWORD, DB_NAME);

if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
}

// Ensure table exists
$tableSql = "CREATE TABLE IF NOT EXISTS contacts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL
)";

if ($conn->query($tableSql) !== TRUE) {
    die("Error creating table: " . $conn->error);
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (!empty($_POST['firstname']) && !empty($_POST['email'])) {
        $firstname = $_POST['firstname'];
        $email     = $_POST['email'];

        $sql = "INSERT INTO contacts (name, email)
                VALUES ('".$firstname."', '".$email."')";

        if ($conn->query($sql) === TRUE) {
            echo "<p>New record created successfully</p>";
        } else {
            echo "<p>Error: " . $conn->error . "</p>";
        }
    }
}

$conn->close();
?>
</body>
</html>
PHP

rm -f index.html
chown www-data:www-data /var/www/html/index.php /var/www/html/dbconfig.php
chmod 640 /var/www/html/dbconfig.php

systemctl restart apache2
