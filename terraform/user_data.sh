#!/bin/bash
set -euo pipefail
exec > /var/log/user_data.log 2>&1

# ── System update ────────────────────────────────────────────────────────────
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y

# ── Install MySQL ─────────────────────────────────────────────────────────────
apt-get install -y mysql-server

# ── Configure MySQL authentication plugin ────────────────────────────────────
echo "default_authentication_plugin=mysql_native_password" \
  >> /etc/mysql/mysql.conf.d/mysqld.cnf

# ── Start and enable MySQL ────────────────────────────────────────────────────
systemctl start mysql
systemctl enable mysql

# ── Create database schema ────────────────────────────────────────────────────
mysql -u root <<'SQL'
CREATE DATABASE IF NOT EXISTS employee_directory;
USE employee_directory;

CREATE TABLE IF NOT EXISTS employees (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  first_name  VARCHAR(100) NOT NULL,
  last_name   VARCHAR(100) NOT NULL,
  email       VARCHAR(150) UNIQUE NOT NULL,
  phone       VARCHAR(20),
  department  VARCHAR(100),
  job_title   VARCHAR(150),
  created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_last_name (last_name),
  INDEX idx_email (email),
  INDEX idx_department (department)
);

CREATE TABLE IF NOT EXISTS logins (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  employee_id INT NOT NULL,
  username    VARCHAR(150) UNIQUE NOT NULL,
  fullname    VARCHAR(201) NOT NULL,
  password    VARCHAR(64)  NOT NULL,
  created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE CASCADE,
  INDEX idx_username (username)
);

CREATE USER IF NOT EXISTS 'app_user'@'localhost' IDENTIFIED WITH mysql_native_password BY 'AppPass!2024';
GRANT SELECT, INSERT, UPDATE, DELETE ON employee_directory.* TO 'app_user'@'localhost';

CREATE USER IF NOT EXISTS 'opa_admin'@'%' IDENTIFIED WITH mysql_native_password BY '${opa_admin_password}';
GRANT ALL PRIVILEGES ON employee_directory.* TO 'opa_admin'@'%';
FLUSH PRIVILEGES;
SQL

# ── Insert seed data ──────────────────────────────────────────────────────────
mysql -u root <<'SQL'
USE employee_directory;

INSERT INTO employees (first_name, last_name, email, phone, department, job_title) VALUES
('Sarah',   'Anderson',  'sarah.anderson@example.com',  '555-201-1001', 'Engineering',  'Senior Software Engineer'),
('Michael', 'Chen',      'michael.chen@example.com',    '555-201-1002', 'Engineering',  'Backend Engineer'),
('Emily',   'Rodriguez', 'emily.rodriguez@example.com', '555-201-1003', 'Product',      'Product Manager'),
('James',   'Williams',  'james.williams@example.com',  '555-201-1004', 'Engineering',  'DevOps Engineer'),
('Priya',   'Patel',     'priya.patel@example.com',     '555-201-1005', 'Marketing',    'Marketing Director'),
('David',   'Kim',       'david.kim@example.com',       '555-201-1006', 'Sales',        'Account Executive'),
('Laura',   'Thompson',  'laura.thompson@example.com',  '555-201-1007', 'HR',           'HR Manager'),
('Carlos',  'Gomez',     'carlos.gomez@example.com',    '555-201-1008', 'Finance',      'Financial Analyst'),
('Megan',   'Foster',    'megan.foster@example.com',    '555-201-1009', 'Product',      'UX Designer'),
('Kevin',   'Nguyen',    'kevin.nguyen@example.com',    '555-201-1010', 'Engineering',  'Frontend Engineer'),
('Rachel',  'Stewart',   'rachel.stewart@example.com',  '555-201-1011', 'Operations',   'Operations Manager'),
('Daniel',  'Brown',     'daniel.brown@example.com',    '555-201-1012', 'Sales',        'Sales Manager'),
('Jessica', 'Lee',       'jessica.lee@example.com',     '555-201-1013', 'IT',           'Systems Administrator'),
('Brian',   'Martinez',  'brian.martinez@example.com',  '555-201-1014', 'Finance',      'Controller'),
('Amanda',  'Wilson',    'amanda.wilson@example.com',   '555-201-1015', 'Marketing',    'Content Strategist');

INSERT INTO logins (employee_id, username, fullname, password)
SELECT id,
       email,
       CONCAT(first_name, ' ', last_name),
       LEFT(MD5(UUID()), 16)
FROM employees;
SQL

echo "Database setup complete."

# ── OPA Server Agent — manual post-provisioning steps ────────────────────────
#
# The Okta Privileged Access (OPA) server agent requires a tenant-specific
# enrollment token that can only be obtained from the Okta admin console.
# Automated installation is therefore not possible at provisioning time.
#
# After the instance is running, complete the following steps:
#
# 1. Log in to your Okta admin console and navigate to:
#    Privileged Access > Infrastructure > Servers
#
# 2. Select or create a Server Group for this gateway instance.
#
# 3. Generate an enrollment token for the group.
#
# 4. SSH into the instance:
#    ssh -i ssh_key.pem ubuntu@<instance_public_ip>
#
# 5. Install the OPA server agent (refer to current Okta documentation for the
#    exact package URL and version):
#
#    curl -fsSL https://packages.okta.com/okta-advanced-server-access/amd64/... \
#      -o /tmp/okta-sftd.deb
#    sudo dpkg -i /tmp/okta-sftd.deb
#
# 6. Enroll the agent using your enrollment token:
#
#    sudo sft enroll --url https://<your-okta-tenant>.okta.com \
#      --enrollment-token <ENROLLMENT_TOKEN>
#
# 7. Verify the agent is connected:
#
#    sudo systemctl status sftd
#
# Once the agent is enrolled, this instance will appear in the OPA dashboard
# and database sessions can be brokered through Okta Privileged Access.
