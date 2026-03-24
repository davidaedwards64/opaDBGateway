output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.opa_db_gateway.public_ip
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.opa_db_gateway.id
}

output "ssh_private_key" {
  description = "Private SSH key for instance access"
  value       = tls_private_key.deployer.private_key_pem
  sensitive   = true
}

output "ssh_connection_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ssh_key.pem ubuntu@${aws_instance.opa_db_gateway.public_ip}"
}
