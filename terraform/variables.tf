variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-west-2"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "project_name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "opa-dae-db-gateway"
}

variable "opa_admin_password" {
  description = "Password for the opa_admin MySQL user (prompted at apply time)"
  type        = string
  sensitive   = true
}

variable "setup_token" {
  description = "OPA gateway setup token (prompted at apply time)"
  type        = string
  sensitive   = true
}
