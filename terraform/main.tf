terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# RSA key pair for SSH access
resource "tls_private_key" "deployer" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "deployer" {
  key_name   = "${var.project_name}-key"
  public_key = tls_private_key.deployer.public_key_openssh
}

# Security group: SSH (22) open; MySQL (3306) self-referencing only
# OPA agent proxies DB connections locally — port 3306 does not need
# to be reachable from the internet.
resource "aws_security_group" "opa_db_gateway" {
  name        = "${var.project_name}-sg"
  description = "Security group for OPA DB gateway instance"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "MySQL (internal only)"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    self        = true
  }

  egress {
    description = "Allow all outbound - required for OPA agent to reach Okta cloud"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg"
  }
}

# EC2 instance
resource "aws_instance" "opa_db_gateway" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.opa_db_gateway.id]

  user_data = templatefile("${path.module}/user_data.sh", {
    opa_admin_password = var.opa_admin_password
  })

  tags = {
    Name = "opa-dae-db-gateway"
  }
}

resource "null_resource" "copy_gateway_deb" {
  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = tls_private_key.deployer.private_key_pem
    host        = aws_instance.opa_db_gateway.public_ip
  }

  # Wait for SSH to be ready before copying
  provisioner "remote-exec" {
    inline = ["echo 'SSH ready'"]
  }

  provisioner "file" {
    source      = "../scaleft-gateway_1.100.0-cci317-g2762eae45~jammy_amd64.deb"
    destination = "/home/ubuntu/scaleft-gateway_1.100.0-cci317-g2762eae45~jammy_amd64.deb"
  }

  depends_on = [aws_instance.opa_db_gateway]
}
