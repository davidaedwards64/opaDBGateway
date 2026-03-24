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

## Configuration

All variables have defaults and can be overridden on the command line or in a `terraform.tfvars` file.

| Variable | Default | Description |
|----------|---------|-------------|
| `aws_region` | `us-west-2` | AWS region to deploy into |
| `instance_type` | `t2.micro` | EC2 instance type |
| `project_name` | `opa-dae-db-gateway` | Name prefix applied to all resources |

Example `terraform.tfvars`:

```hcl
aws_region    = "us-east-1"
instance_type = "t3.small"
project_name  = "my-opa-gateway"
```

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

Downloads the `hashicorp/aws` (~> 5.0) and `hashicorp/tls` (~> 4.0) providers.

### 3. Preview the changes

```bash
terraform plan
```

### 4. Apply

```bash
terraform apply
```

Terraform will create:
- A 4096-bit RSA key pair
- A security group (SSH open; MySQL self-referencing only)
- An EC2 instance running the latest Ubuntu 22.04 Jammy AMI

`user_data.sh` runs automatically on first boot and:
1. Updates the system packages
2. Installs and starts MySQL
3. Creates the `employee_directory` database with `employees` and `logins` tables
4. Inserts 15 sample employee records and derives matching login credentials

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

### 6. Verify the database

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

## OPA Server Agent Enrollment

The OPA agent requires a tenant-specific enrollment token that can only be obtained from the Okta admin console, so it cannot be automated at provisioning time.

**Steps after the instance is running:**

1. Log in to the Okta admin console and navigate to **Privileged Access > Infrastructure > Servers**.
2. Select or create a Server Group for this instance.
3. Generate an enrollment token for the group.
4. SSH into the instance (see step 5 above).
5. Install the OPA server agent (refer to current [Okta documentation](https://help.okta.com/opa/en-us/content/topics/privileged-access/opa-main.htm) for the package URL):

   ```bash
   curl -fsSL https://packages.okta.com/okta-advanced-server-access/amd64/<package> \
     -o /tmp/okta-sftd.deb
   sudo dpkg -i /tmp/okta-sftd.deb
   ```

6. Enroll the agent:

   ```bash
   sudo sft enroll --url https://<your-okta-tenant>.okta.com \
     --enrollment-token <ENROLLMENT_TOKEN>
   ```

7. Verify the agent is connected:

   ```bash
   sudo systemctl status sftd
   ```

Once enrolled, the instance will appear in the OPA dashboard and database sessions can be brokered through Okta Privileged Access.

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

The application user `app_user@localhost` has SELECT, INSERT, UPDATE, DELETE on `employee_directory.*`.

## Teardown

```bash
cd terraform
terraform destroy
```

This removes the EC2 instance, key pair, and security group. The generated `ssh_key.pem` file is not managed by Terraform and should be deleted manually.
