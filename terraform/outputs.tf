output "instance_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_eip.static_ip.public_ip
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i YOUR_SSH_KEY_FILE.pem ubuntu@${aws_eip.static_ip.public_ip}"
}

output "efs_id" {
  description = "EFS File System ID (Managed outside Terraform)"
  value       = data.aws_efs_file_system.existing_efs.id
}

output "efs_dns_name" {
  description = "EFS DNS name for mounting"
  value       = data.aws_efs_file_system.existing_efs.dns_name
}
