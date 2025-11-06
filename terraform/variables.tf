variable "aws_region" {
  description = "The AWS region to deploy resources in."
  type        = string
  default     = "eu-north-1"
}

variable "ssh_key_name" {
  description = "The name of your AWS SSH key pair for the selected region."
  type        = string
  # IMPORTANT: Replace this with your actual key pair name!
  # For example: default = "my-aws-key"
  default     = "YOUR_SSH_KEY_NAME_HERE"
}

variable "instance_type" {
  description = "The EC2 instance type."
  type        = string
  default     = "t3.small"
}

variable "github_repo_url" {
  description = "The HTTPS URL of the GitHub repository to clone."
  type        = string
  default     = "https://github.com/rahuljangirwork/aws-automation.git"
}