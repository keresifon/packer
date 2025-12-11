packer {

  required_plugins {

    amazon = {

      source  = "github.com/hashicorp/amazon"

      version = "~> 1"

    }

  }

}

 

# Variables - AWS Configuration

# Note: AWS credentials are provided via environment/role (OIDC in GitHub Actions)

# For local development, use AWS CLI or environment variables

variable "aws_region" {

  type        = string

  description = "AWS region to build the image in"

  default     = "us-east-2"

}

 

# Variables - Image Configuration

variable "instance_type" {

  type        = string

  description = "EC2 instance type for building"

  default     = "t3.micro"

}

 

variable "image_name" {

  type        = string

  description = "Name for the AMI"

  default     = "amazonlinux2023-golden-image"

}

 

variable "iam_instance_profile" {

  type        = string

  description = "IAM instance profile name for SSM Session Manager (optional - Packer can create temporary one)"

  default     = ""

}

 

variable "vpc_id" {

  type        = string

  description = "VPC ID to launch instance in (optional - will use default VPC if not specified)"

  default     = ""

}

 

variable "subnet_id" {

  type        = string

  description = "Subnet ID to launch instance in (optional - will use default subnet if not specified)"

  default     = ""

}

 

variable "security_group_ids" {

  type        = list(string)

  description = "List of security group IDs to attach to the instance (optional - Packer creates temporary one if not specified). For private subnets, pre-create a security group with outbound HTTPS (443) to VPC endpoints."

  default     = []

}

 

# Data source for latest Amazon Linux 2023 AMI

data "amazon-ami" "amazonlinux2023" {

  filters = {

    name                = "al2023-ami-*-x86_64"

    root-device-type    = "ebs"

    virtualization-type = "hvm"

  }

  most_recent = true

  owners      = ["amazon"] # AWS

  region      = var.aws_region

}

 

# Build source

# AWS credentials come from environment (AWS CLI, environment variables, or IAM role)

source "amazon-ebs" "amazonlinux2023" {

  ami_name      = "${var.image_name}-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  instance_type = var.instance_type

  region        = var.aws_region

  source_ami    = data.amazon-ami.amazonlinux2023.id

  # Use SSM Session Manager for SSH access (instead of direct SSH)

  # SSM works with private IPs, no need for public IP or SSH security groups

  # Benefits: No SSH keys, no security group rules, works with private subnets

  # Configure SSH to use Session Manager as the interface

  communicator = "ssh"

  ssh_username = "ec2-user"  # Default user for Amazon Linux 2023

  ssh_interface = "session_manager"  # Use SSM Session Manager for SSH connection

  # SSM configuration

  # Packer will automatically create a temporary IAM instance profile if not provided

  # The instance profile needs: AmazonSSMManagedInstanceCore policy

  # Required IAM permissions for Packer to create temporary instance profile:

  # - iam:CreateInstanceProfile

  # - iam:AddRoleToInstanceProfile

  # - iam:RemoveRoleFromInstanceProfile

  # - iam:DeleteInstanceProfile

  # - iam:PassRole (for the SSM role)

  # - iam:CreateRole

  # - iam:AttachRolePolicy

  # - iam:DetachRolePolicy

  # - iam:DeleteRole

  # IAM instance profile configuration

  # Required for SSM Session Manager connectivity

  # The instance profile must have the AmazonSSMManagedInstanceCore policy attached

  # You must create an IAM instance profile with the AmazonSSMManagedInstanceCore policy

  # Example AWS CLI command to create:

  # aws iam create-instance-profile --instance-profile-name packer-ssm-profile

  # aws iam create-role --role-name packer-ssm-role --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}'

  # aws iam attach-role-policy --role-name packer-ssm-role --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore

  # aws iam add-role-to-instance-profile --instance-profile-name packer-ssm-profile --role-name packer-ssm-role

  iam_instance_profile = var.iam_instance_profile != "" ? var.iam_instance_profile : null

  # User data to ensure SSM Agent starts immediately on instance launch

  # This is critical - SSM Agent must be running for Packer to connect via SSM

  user_data = base64encode(<<-EOF
    #!/bin/bash
    # Ensure SSM Agent starts immediately on boot
    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent
    # Wait for SSM Agent to be ready
    sleep 10
  EOF
  )

  # VPC configuration (optional - only set if provided)

  # Note: If subnet_id is specified, vpc_id must also be specified

  # The subnet must exist in the specified VPC and region

  # SSM works with private IPs, so public IP is not required

  # IMPORTANT: For private subnets:

  # Option A: Private subnet with NAT Gateway (internet access via NAT)

  #    - No VPC endpoints required (but recommended for cost savings)

  #    - Security group needs outbound HTTPS (443) to 0.0.0.0/0 (or NAT Gateway)

  #    - Package installation works normally (via NAT Gateway)

  #    - SSM Session Manager works via NAT Gateway

  # Option B: Private subnet with NO internet (fully isolated)

  #    - VPC endpoints REQUIRED for AWS services:

  #      * com.amazonaws.region.ssm (SSM service)

  #      * com.amazonaws.region.ssmmessages (SSM messages)

  #      * com.amazonaws.region.ec2 (EC2 API)

  #      * com.amazonaws.region.s3 (S3 - Gateway endpoint)

  #      * com.amazonaws.region.sts (Security Token Service)

  #    - Security group must allow outbound HTTPS (443) to VPC endpoints

  #    - Route table must have routes to VPC endpoints

  #    - For package installation, use VPC endpoint for S3 or pre-download packages

  vpc_id    = var.vpc_id != "" ? var.vpc_id : null

  subnet_id = var.subnet_id != "" ? var.subnet_id : null

  # Explicitly disable public IP assignment (private subnet)

  # With NAT Gateway, instances use private IPs but can access internet via NAT

  associate_public_ip_address = false

  # Security group configuration

  # IMPORTANT: When using ssh_interface = "session_manager":

  # - Packer WILL create a temporary security group automatically if security_group_ids is not specified

  # - However, Packer's auto-created security group may NOT have outbound HTTPS (443) rules

  # - For private subnets, SSM Session Manager REQUIRES outbound HTTPS (443) to:

  #   * VPC endpoints (if using VPC endpoints), OR

  #   * 0.0.0.0/0 via NAT Gateway (if using NAT Gateway)

  # - RECOMMENDED for private subnets: Pre-create a security group with outbound HTTPS (443) rule

  # - Packer's auto-created security group works fine for public subnets or if NAT Gateway provides internet access

  # Example AWS CLI to create security group for private subnet:

  # aws ec2 create-security-group --group-name packer-ssm-sg --description "Security group for Packer SSM" --vpc-id vpc-xxxxx

  # aws ec2 authorize-security-group-egress --group-id sg-xxxxx --protocol tcp --port 443 --cidr 0.0.0.0/0

  # If security_group_ids is not specified, Packer will create a temporary one (may not have HTTPS outbound rule)

  security_group_ids = length(var.security_group_ids) > 0 ? var.security_group_ids : null

 

  # Tags for the AMI

  tags = {

    Name        = var.image_name

    OS          = "AmazonLinux2023"

    Version     = "2023"

    ManagedBy   = "Packer"

    Environment = "Production"

  }

 

  # Tags for the snapshot

  snapshot_tags = {

    Name        = var.image_name

    OS          = "AmazonLinux2023"

    Version     = "2023"

    ManagedBy   = "Packer"

  }

 

  # Launch block device mappings

  launch_block_device_mappings {

    device_name           = "/dev/sda1"

    volume_size           = 20

    volume_type           = "gp3"

    delete_on_termination = true

    encrypted             = true

  }

}

 

# Build configuration

build {

  name = "amazonlinux2023-golden-image"

  sources = [

    "source.amazon-ebs.amazonlinux2023"

  ]

 

  # Provisioning: Update system

  # Amazon Linux 2023 uses dnf package manager

  # Note: Check if sudo exists, if not assume we're root

  provisioner "shell" {

    inline = [

      "if command -v sudo >/dev/null 2>&1; then SUDO=sudo; else SUDO=''; fi",

      "# Update system packages (use --allowerasing to handle curl-minimal conflicts)",

      "$${SUDO} dnf update -y --allowerasing",

      "$${SUDO} dnf upgrade -y --allowerasing",

      "$${SUDO} dnf clean all"

    ]

  }

 

  # Provisioning: Install common packages

  provisioner "shell" {

    inline = [

      "# Determine if sudo is available, if not assume we're root",

      "if command -v sudo >/dev/null 2>&1; then SUDO=sudo; else SUDO=''; fi",

      "# Install common utilities",

      "# Note: curl-minimal is pre-installed in Amazon Linux 2023, use --allowerasing to replace with full curl",

      "$${SUDO} dnf install -y --allowerasing curl wget git unzip",

      "$${SUDO} dnf install -y htop net-tools",

      "# Install AWS CLI v2 using official installer",

      "curl \"https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip\" -o \"/tmp/awscliv2.zip\"",

      "unzip -q /tmp/awscliv2.zip -d /tmp",

      "$${SUDO} /tmp/aws/install",

      "rm -rf /tmp/aws /tmp/awscliv2.zip",

      "# Install jq",

      "$${SUDO} dnf install -y jq || echo 'Warning: jq installation skipped'"

    ]

  }

 

  # Provisioning: Ensure SSM Agent is installed, enabled, and running

  # Amazon Linux 2023 comes with SSM Agent pre-installed, but ensure it's properly configured

  # This must run early in provisioning since Packer uses SSM to connect

  provisioner "shell" {

    inline = [

      "# Determine if sudo is available, if not assume we're root",

      "if command -v sudo >/dev/null 2>&1; then SUDO=sudo; else SUDO=''; fi",

      "# Check if SSM Agent is installed",

      "if ! command -v amazon-ssm-agent >/dev/null 2>&1; then",

      "  echo 'SSM Agent not found, installing...'",

      "  $${SUDO} dnf install -y amazon-ssm-agent || echo 'Warning: Failed to install SSM Agent'",

      "fi",

      "# Ensure SSM Agent service exists",

      "if $${SUDO} systemctl list-unit-files | grep -q amazon-ssm-agent.service; then",

      "  echo 'SSM Agent service found'",

      "  # Enable SSM Agent to start on boot",

      "  $${SUDO} systemctl enable amazon-ssm-agent",

      "  # Start SSM Agent immediately",

      "  $${SUDO} systemctl start amazon-ssm-agent",

      "  # Wait a moment for service to start",

      "  sleep 5",

      "  # Check status",

      "  $${SUDO} systemctl status amazon-ssm-agent --no-pager || echo 'Warning: SSM Agent status check failed'",

      "else",

      "  echo 'ERROR: SSM Agent service not found'",

      "  exit 1",

      "fi"

    ]

  }

 

  # Provisioning: Configure SSH (optional - harden SSH)

  provisioner "shell" {

    inline = [

      "# Determine if sudo is available, if not assume we're root",

      "if command -v sudo >/dev/null 2>&1; then SUDO=sudo; else SUDO=''; fi",

      "# Harden SSH configuration",

      "$${SUDO} sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config || true",

      "$${SUDO} sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config || true",

      "$${SUDO} sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config || true",

      "$${SUDO} systemctl restart sshd || true"

    ]

  }

 

  # Provisioning: Clean up

  provisioner "shell" {

    inline = [

      "# Determine if sudo is available, if not assume we're root",

      "if command -v sudo >/dev/null 2>&1; then SUDO=sudo; else SUDO=''; fi",

      "# Clean up cloud-init",

      "$${SUDO} cloud-init clean",

      "$${SUDO} rm -f /var/log/cloud-init*.log",

      "# Clean up temporary files",

      "$${SUDO} rm -rf /tmp/*",

      "$${SUDO} rm -rf /var/tmp/*",

      "# Clean up package cache",

      "$${SUDO} dnf clean all",

      "# Sync filesystem",

      "$${SUDO} sync"

    ]

  }

 

}