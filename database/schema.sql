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

-- Replace <opa_admin_password> with the actual password before running locally
CREATE USER IF NOT EXISTS 'opa_admin'@'%' IDENTIFIED WITH mysql_native_password BY '<opa_admin_password>';
GRANT ALL PRIVILEGES ON employee_directory.* TO 'opa_admin'@'%';

-- Grant opa_admin global user-management privileges
GRANT CREATE USER ON *.* TO 'opa_admin'@'%';

-- Replace <opa_admin_password> with the actual password before running locally
CREATE USER IF NOT EXISTS 'dbaone'@'%' IDENTIFIED WITH mysql_native_password BY '<opa_admin_password>';
GRANT SELECT, INSERT, UPDATE, DELETE ON employee_directory.* TO 'dbaone'@'%';

CREATE USER IF NOT EXISTS 'dbatwo'@'%' IDENTIFIED WITH mysql_native_password BY '<opa_admin_password>';
GRANT SELECT, INSERT, UPDATE, DELETE ON employee_directory.* TO 'dbatwo'@'%';
FLUSH PRIVILEGES;
