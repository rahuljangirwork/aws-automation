output "instance_public_ip" {
  description = "The public IP address of the EC2 instance."
  value       = aws_eip.static_ip.public_ip
}

output "ssh_command" {
  description = "Command to SSH into the EC2 instance."
  value       = "ssh -i YOUR_SSH_KEY_FILE.pem ubuntu@${aws_eip.static_ip.public_ip}"
}