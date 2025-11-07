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

# Reference existing EFS - NOT managed by Terraform
data "aws_efs_file_system" "existing_efs" {
  file_system_id = "fs-0613a60feac52e288"
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

resource "aws_security_group" "efs_sg" {
  name        = "efs-sg"
  description = "Allow NFS traffic from EC2"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
    description     = "Allow NFS from EC2"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "EFS-SG"
  }
}

# Mount targets use existing EFS
resource "aws_efs_mount_target" "efs_mount_target" {
  for_each = toset(data.aws_subnets.default.ids)

  file_system_id  = data.aws_efs_file_system.existing_efs.id
  subnet_id       = each.value
  security_groups = [aws_security_group.efs_sg.id]
  
  lifecycle {
    create_before_destroy = true
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

              # Update the EFS ID in the config.sh file
              sed -i "s/EFS_ID='.*'/EFS_ID='${data.aws_efs_file_system.existing_efs.id}'/" "$CONFIG_FILE"

              # Make the main setup script executable
              chmod +x "$SETUP_SCRIPT"

              # Run the main setup script as the ubuntu user
              sudo -u ubuntu "$SETUP_SCRIPT"
              EOF

  tags = {
    Name = "RustDesk-App-Server"
  }

  depends_on = [aws_efs_mount_target.efs_mount_target]
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.app_server.id
  allocation_id = aws_eip.static_ip.id
}
