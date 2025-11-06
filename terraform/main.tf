provider "aws" {
  region = var.aws_region
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "ec2_sg" {
  name        = "ec2-instance-sg"
  description = "Allow SSH and Tailscale traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow SSH from anywhere"
  }

  # Tailscale uses UDP on port 41641 for NAT traversal.
  # Once connected, traffic is encapsulated, so specific app ports aren't needed here.
  ingress {
    from_port   = 41641
    to_port     = 41641
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow Tailscale NAT traversal"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "EC2-SG"
  }
}





resource "aws_eip" "static_ip" {
  domain = "vpc"
  tags = {
    Name = "RustDesk-Server-IP"
  }
}

resource "aws_instance" "app_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.ssh_key_name

  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  
  # This user_data script runs on the first boot
  user_data = <<-EOF
              #!/bin/bash
              set -e
              
              # Update and install git
              apt-get update
              apt-get install -y git
              
              # Clone the repository
              cd /home/ubuntu
              git clone "${var.github_repo_url}"
              
              # Change ownership to the ubuntu user
              chown -R ubuntu:ubuntu /home/ubuntu/aws-automation

              # Define absolute paths
              CONFIG_FILE="/home/ubuntu/aws-automation/scripts/config.sh"
              SETUP_SCRIPT="/home/ubuntu/aws-automation/setup.sh"

              # Update the EFS ID in the config.sh file with the correct one from Terraform
              sed -i "s/EFS_ID='.*'/EFS_ID='${var.efs_id}'/" "$CONFIG_FILE"

              # Make the main setup script executable
              chmod +x "$SETUP_SCRIPT"

              # Run the main setup script as the ubuntu user
              # This will run until it prompts for Tailscale authentication
              sudo -u ubuntu "$SETUP_SCRIPT"
              EOF

  tags = {
    Name = "RustDesk-App-Server"
  }
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.app_server.id
  allocation_id = aws_eip.static_ip.id
}
