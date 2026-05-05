# OPA Database Gateway

An AWS EC2 instance provisioned with MySQL and configured as a target for [Okta Privileged Access (OPA)](https://help.okta.com/opa/en-us/content/topics/privileged-access/opa-main.htm) database session brokering. Terraform handles all infrastructure; `user_data.sh` bootstraps MySQL and loads sample data on first boot. The OPA server agent is enrolled manually after the instance is running.

## Architecture

```
Internet
   │
   │  SSH :22 (open)
   ▼
┌─────────────────────────────────┐
│  EC2 (Ubuntu 22.04)             │
│                                 │
│  MySQL :3306 (self-ref only)    │
│  └─ employee_directory          │
│     ├─ employees (15 rows)      │
│     └─ logins   (15 rows)       │
│                                 │
│  OPA server agent (sftd)        │
│  └─ proxies DB sessions to      │
│     Okta cloud (outbound only)  │
└─────────────────────────────────┘
```

MySQL port 3306 is not reachable from the internet — the OPA agent proxies database connections locally.

## Prerequisites

| Tool | Version |
|------|---------|
| [Terraform](https://developer.hashicorp.com/terraform/install) | >= 1.3 |
| [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) | any |
| AWS credentials | configured in environment or `~/.aws/credentials` |

AWS credentials must have permission to create EC2 instances, key pairs, and security groups.

> **Gateway package:** The OPA gateway `.deb` package (`scaleft-gateway_1.102.0-cci7-g53653ba29~jammy_amd64.deb`) is not stored in this repository. You must obtain it separately and place it at `terraform/files/scaleft-gateway_1.102.0-cci7-g53653ba29~jammy_amd64.deb` before running any Terraform commands.

## Configuration

Most variables have defaults and can be overridden on the command line or in a `terraform.tfvars` file. `opa_admin_password` and `setup_token` have no defaults and will be prompted interactively at `apply` time.

| Variable | Default | Description |
|----------|---------|-------------|
| `aws_region` | `us-west-2` | AWS region to deploy into |
| `instance_type` | `t2.micro` | EC2 instance type |
| `project_name` | `opa-dae-db-gateway` | Name prefix applied to all resources |
| `opa_admin_password` | *(prompted)* | Password for the `opa_admin` MySQL user — sensitive |
| `setup_token` | *(prompted)* | OPA gateway setup token from the Okta admin console — sensitive |

Example `terraform.tfvars`:

```hcl
aws_region    = "us-east-1"
instance_type = "t3.small"
project_name  = "my-opa-gateway"
```

> `opa_admin_password` and `setup_token` should not be placed in `terraform.tfvars` to avoid committing them to source control. Supply them at the prompt or via the `TF_VAR_opa_admin_password` and `TF_VAR_setup_token` environment variables.

## Build and Deploy

### 1. Configure AWS credentials

Terraform uses the standard AWS credential chain. Choose one of the following methods:

**Option A — AWS CLI (recommended):**

```bash
aws configure
```

You will be prompted for:

```
AWS Access Key ID:     <your-access-key-id>
AWS Secret Access Key: <your-secret-access-key>
Default region name:   us-west-2
Default output format: json
```

Credentials are written to `~/.aws/credentials` and reused by Terraform automatically.

**Option B — Environment variables:**

```bash
export AWS_ACCESS_KEY_ID="<your-access-key-id>"
export AWS_SECRET_ACCESS_KEY="<your-secret-access-key>"
export AWS_DEFAULT_REGION="us-west-2"
```

**Required IAM permissions:**

The credentials must allow the following actions:

- `ec2:RunInstances`, `ec2:DescribeInstances`, `ec2:TerminateInstances`
- `ec2:CreateKeyPair`, `ec2:DeleteKeyPair`, `ec2:DescribeKeyPairs`
- `ec2:CreateSecurityGroup`, `ec2:DeleteSecurityGroup`, `ec2:AuthorizeSecurityGroupIngress`, `ec2:AuthorizeSecurityGroupEgress`, `ec2:DescribeSecurityGroups`
- `ec2:DescribeImages`

Verify your credentials are working before proceeding:

```bash
aws sts get-caller-identity
```

### 2. Initialise Terraform

```bash
cd terraform
terraform init
```

Downloads the `hashicorp/aws` (~> 5.0), `hashicorp/tls` (~> 4.0), and `hashicorp/null` (~> 3.0) providers.

### 3. Preview the changes

```bash
terraform plan
```

### 4. Apply

```bash
terraform apply
```

Terraform will prompt for two sensitive values before making any changes:

```
var.opa_admin_password
  Password for the opa_admin MySQL user (prompted at apply time)

  Enter a value: ********

var.setup_token
  OPA gateway setup token (prompted at apply time)

  Enter a value: ********
```

Obtain the gateway setup token from the Okta admin console (**Resource Administration > Gateways > Set up gateway > Create setup token**) before running `apply`. The token is only shown once.

Terraform will create:
- A 4096-bit RSA key pair
- A security group (SSH open; MySQL self-referencing only)
- An EC2 instance running the latest Ubuntu 22.04 Jammy AMI

After the instance is reachable over SSH, Terraform will automatically:
1. Copy and install the OPA gateway package (`sudo dpkg -i`)
2. Place `sft-gatewayd.yaml` at `/etc/sft/sft-gatewayd.yaml`
3. Write the setup token to `/var/lib/sft-gatewayd/setup.token`

`user_data.sh` runs on first boot and:
1. Updates the system packages
2. Sets `mysql_native_password` as the server-wide default authentication plugin
3. Installs and starts MySQL
4. Creates the `employee_directory` database with `employees` and `logins` tables
5. Creates `app_user@localhost`, `opa_admin@'%'`, `dbaone@'%'`, and `dbatwo@'%'` using `mysql_native_password`
6. Grants `opa_admin` global `CREATE USER` privilege (required for OPA user management)
7. Inserts 15 sample employee records and derives matching login credentials

Allow 2–3 minutes after `apply` completes for `user_data.sh` to finish.

### 5. Retrieve the SSH key and connect

```bash
# Write the private key to disk
terraform output -raw ssh_private_key > ../ssh_key.pem
chmod 600 ../ssh_key.pem

# Print the ready-made SSH command
terraform output ssh_connection_command
```

Then connect:

```bash
ssh -i ../ssh_key.pem ubuntu@<instance_public_ip>
```

### 6. Verify the database and gateway

```bash
sudo mysql -u root -e "SELECT COUNT(*) FROM employee_directory.employees;"
# Expected: 15

sudo mysql -u root -e "SELECT COUNT(*) FROM employee_directory.logins;"
# Expected: 15

sudo mysql -u root -e "
  SELECT l.username, l.fullname, l.password, e.department
  FROM employee_directory.logins l
  JOIN employee_directory.employees e ON l.employee_id = e.id
  LIMIT 5;"

# Confirm all users were created with mysql_native_password
sudo mysql -u root -e "
  SELECT user, host, plugin
  FROM mysql.user
  WHERE user IN ('app_user', 'opa_admin', 'dbaone', 'dbatwo');"
# Expected: all four rows show mysql_native_password

# Confirm opa_admin has global CREATE USER privilege
sudo mysql -u root -e "SHOW GRANTS FOR 'opa_admin'@'%';"
# Expected: includes GRANT ALL PRIVILEGES ON *.* WITH GRANT OPTION

# Confirm dbaone and dbatwo grants
sudo mysql -u root -e "SHOW GRANTS FOR 'dbaone'@'%'; SHOW GRANTS FOR 'dbatwo'@'%';"
# Expected: SELECT, INSERT, UPDATE, DELETE on employee_directory.*

# Confirm the gateway package was installed
dpkg -l | grep scaleft-gateway

# Confirm config and token files are in place
sudo ls -lh /etc/sft/sft-gatewayd.yaml
sudo ls -lh /var/lib/sft-gatewayd/setup.token
```

### 7. Check provisioning logs

If the database is not ready, inspect the cloud-init log:

```bash
sudo tail -f /var/log/user_data.log
```

## Outputs

| Output | Description |
|--------|-------------|
| `instance_public_ip` | Public IP of the EC2 instance |
| `instance_id` | EC2 instance ID |
| `ssh_private_key` | Generated private key (sensitive) |
| `ssh_connection_command` | Ready-to-use SSH command |

## Database Schema

### `employees`

| Column | Type | Notes |
|--------|------|-------|
| `id` | INT | Auto-increment PK |
| `first_name` | VARCHAR(100) | |
| `last_name` | VARCHAR(100) | Indexed |
| `email` | VARCHAR(150) | Unique, indexed |
| `phone` | VARCHAR(20) | |
| `department` | VARCHAR(100) | Indexed |
| `job_title` | VARCHAR(150) | |
| `created_at` | TIMESTAMP | |
| `updated_at` | TIMESTAMP | Auto-updated |

### `logins`

| Column | Type | Notes |
|--------|------|-------|
| `id` | INT | Auto-increment PK |
| `employee_id` | INT | FK → employees(id) ON DELETE CASCADE |
| `username` | VARCHAR(150) | Unique, indexed; seeded from `email` |
| `fullname` | VARCHAR(201) | Seeded from `first_name + last_name` |
| `password` | VARCHAR(64) | 16-char random hex string |
| `created_at` | TIMESTAMP | |
| `updated_at` | TIMESTAMP | Auto-updated |

All MySQL users are created with `mysql_native_password` for OPA gateway compatibility:

| User | Host | Privileges |
|------|------|------------|
| `app_user` | `localhost` | SELECT, INSERT, UPDATE, DELETE on `employee_directory.*` |
| `opa_admin` | `%` | ALL PRIVILEGES on `*.*` WITH GRANT OPTION (superadmin) — used by the OPA agent |
| `dbaone` | `%` | SELECT, INSERT, UPDATE, DELETE on `employee_directory.*` |
| `dbatwo` | `%` | SELECT, INSERT, UPDATE, DELETE on `employee_directory.*` |

## Teardown

```bash
cd terraform
terraform destroy
```

This removes the EC2 instance, key pair, and security group. The generated `ssh_key.pem` file is not managed by Terraform and should be deleted manually.
