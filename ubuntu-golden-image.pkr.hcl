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

  default     = "ubuntu-golden-image"

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

 

# Data source for latest Ubuntu 22.04 AMI

data "amazon-ami" "ubuntu" {

  filters = {

    name                = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"

    root-device-type    = "ebs"

    virtualization-type = "hvm"

  }

  most_recent = true

  owners      = ["099720109477"] # Canonical

  region      = var.aws_region

}

 

# Build source

# AWS credentials come from environment (AWS CLI, environment variables, or IAM role)

source "amazon-ebs" "ubuntu" {

  ami_name      = "${var.image_name}-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  instance_type = var.instance_type

  region        = var.aws_region

  source_ami    = data.amazon-ami.ubuntu.id

  # Use SSM Session Manager for SSH access (instead of direct SSH)

  # SSM works with private IPs, no need for public IP or SSH security groups

  # Benefits: No SSH keys, no security group rules, works with private subnets

  # Configure SSH to use Session Manager as the interface

  communicator = "ssh"

  ssh_username = "ubuntu"  # Default user for Ubuntu

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

  iam_instance_profile = var.iam_instance_profile != "" ? var.iam_instance_profile : null

  # User Data + Pause Approach: Install SSM Agent via user_data before Packer connects

  # This approach requires NO network architecture changes - works with existing VPC endpoints

  # The user_data script installs SSM Agent, and pause_before_connecting gives it time to register

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -e
    exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
    
    echo "Starting SSM Agent installation via User Data..."
    
    # Wait for cloud-init to complete before installing SSM Agent
    cloud-init status --wait
    
    # Install SSM Agent using snap (Ubuntu 18.04+)
    # Snap is pre-installed on Ubuntu 22.04
    if command -v snap >/dev/null 2>&1; then
      echo "Installing SSM Agent via snap..."
      snap install amazon-ssm-agent --classic
      
      # Enable and start SSM Agent service (snap service name)
      systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
      systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service
    else
      echo "Snap not available, installing via deb package..."
      mkdir -p /tmp/ssm
      cd /tmp/ssm
      wget -q https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/debian_amd64/amazon-ssm-agent.deb
      dpkg -i amazon-ssm-agent.deb || apt-get install -f -y
      rm -rf /tmp/ssm
      
      # Enable and start SSM Agent service (deb package service name)
      systemctl enable amazon-ssm-agent
      systemctl start amazon-ssm-agent
    fi
    
    # Wait for SSM Agent to register with AWS (critical for Packer connection)
    echo "Waiting for SSM Agent to register..."
    MAX_WAIT=60
    WAIT_COUNT=0
    while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
      # Check if agent service is running
      if systemctl is-active --quiet snap.amazon-ssm-agent.amazon-ssm-agent.service 2>/dev/null || \
         systemctl is-active --quiet amazon-ssm-agent.service 2>/dev/null; then
        # Check if agent has registered (registration file exists after successful registration)
        if [ -f /var/lib/amazon/ssm/registration ] || \
           systemctl status snap.amazon-ssm-agent.amazon-ssm-agent.service 2>/dev/null | grep -q "running" || \
           systemctl status amazon-ssm-agent.service 2>/dev/null | grep -q "running"; then
          echo "SSM Agent is ready and registered"
          break
        fi
      fi
      WAIT_COUNT=$((WAIT_COUNT + 1))
      echo "Waiting for SSM Agent registration... ($WAIT_COUNT/$MAX_WAIT)"
      sleep 2
    done
    
    # Final status check
    if systemctl is-active --quiet snap.amazon-ssm-agent.amazon-ssm-agent.service 2>/dev/null; then
      systemctl status snap.amazon-ssm-agent.amazon-ssm-agent.service --no-pager || echo "Warning: SSM Agent status check"
    elif systemctl is-active --quiet amazon-ssm-agent.service 2>/dev/null; then
      systemctl status amazon-ssm-agent.service --no-pager || echo "Warning: SSM Agent status check"
    else
      echo "Warning: SSM Agent service not found"
    fi
    
    echo "SSM Agent installation complete"
    touch /var/lib/cloud/instance/boot-finished
  EOF
  )

  # Give SSM Agent time to install and register before Packer connects

  # This pause is critical - allows user_data script to complete SSM Agent installation

  # 3 minutes should be sufficient for snap installation and registration

  pause_before_connecting = "3m"

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

  #      * com.amazonaws.region.s3 (S3 - Gateway endpoint) - for SSM Agent installer if using deb package

  #    - Security group must allow outbound HTTPS (443) to VPC endpoints

  #    - Route table must have routes to VPC endpoints

  #    - For package installation, use VPC endpoint for S3 or pre-download packages

  vpc_id    = var.vpc_id != "" ? var.vpc_id : null

  subnet_id = var.subnet_id != "" ? var.subnet_id : null

  # Explicitly disable public IP assignment (private subnet)

  # With NAT Gateway, instances use private IPs but can access internet via NAT

  # With VPC endpoints, instances use private IPs and connect to AWS services privately

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

    OS          = "Ubuntu"

    Version     = "22.04"

    ManagedBy   = "Packer"

    Environment = "Production"

  }

 

  # Tags for the snapshot

  snapshot_tags = {

    Name        = var.image_name

    OS          = "Ubuntu"

    Version     = "22.04"

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

  name = "ubuntu-golden-image"

  sources = [

    "source.amazon-ebs.ubuntu"

  ]

 

  # Provisioning: Update system

  # Ubuntu uses apt-get package manager

  provisioner "shell" {

    inline = [

      "sudo apt-get update -y",

      "sudo apt-get upgrade -y",

      "sudo apt-get autoremove -y",

      "sudo apt-get autoclean -y"

    ]

  }

 

  # Provisioning: Install common packages

  provisioner "shell" {

    inline = [

      "# Install common utilities",

      "sudo apt-get install -y curl wget git unzip",

      "sudo apt-get install -y htop net-tools",

      "# AWS CLI installation skipped - install manually after instance launch",

      "# For private subnets without internet access, AWS CLI can be installed later via:",

      "#   1. NAT Gateway (if configured)",

      "#   2. S3 VPC Gateway endpoint (download installer from S3)",

      "#   3. Manual installation after instance launch with internet access",

      "#",

      "# To install AWS CLI v2 manually:",

      "#   curl \"https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip\" -o \"/tmp/awscliv2.zip\"",

      "#   unzip /tmp/awscliv2.zip -d /tmp",

      "#   sudo /tmp/aws/install",

      "#   rm -rf /tmp/aws /tmp/awscliv2.zip",

      "if command -v aws >/dev/null 2>&1; then",

      "  echo 'AWS CLI already installed: $(aws --version 2>/dev/null || echo unknown)'",

      "else",

      "  echo 'AWS CLI will be installed manually after instance launch'",

      "fi",

      "# Install jq",

      "sudo apt-get install -y jq || echo 'Warning: jq installation skipped'"

    ]

  }

 

  # Provisioning: Verify SSM Agent is running

  # SSM Agent should already be installed and running via user_data

  # This step verifies it's working correctly

  provisioner "shell" {

    inline = [

      "# Verify SSM Agent is installed and running",

      "if systemctl is-active --quiet snap.amazon-ssm-agent.amazon-ssm-agent.service 2>/dev/null; then",

      "  echo 'SSM Agent (snap) is running'",

      "  systemctl status snap.amazon-ssm-agent.amazon-ssm-agent.service --no-pager || true",

      "elif systemctl is-active --quiet amazon-ssm-agent.service 2>/dev/null; then",

      "  echo 'SSM Agent (deb) is running'",

      "  systemctl status amazon-ssm-agent.service --no-pager || true",

      "else",

      "  echo 'Warning: SSM Agent service not found or not running'",

      "  echo 'This may indicate an issue with user_data installation'",

      "fi"

    ]

  }

 

  # Provisioning: Configure SSH (optional - harden SSH)

  provisioner "shell" {

    inline = [

      "# Harden SSH configuration",

      "sudo sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config || true",

      "sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config || true",

      "sudo sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config || true",

      "sudo systemctl restart sshd || true"

    ]

  }

 

  # Provisioning: Clean up

  provisioner "shell" {

    inline = [

      "# Clean up cloud-init",

      "sudo cloud-init clean",

      "sudo rm -f /var/log/cloud-init*.log",

      "# Clean up temporary files",

      "sudo rm -rf /tmp/*",

      "sudo rm -rf /var/tmp/*",

      "# Clean up package cache",

      "sudo apt-get clean",

      "# Sync filesystem",

      "sudo sync"

    ]

  }

 

}
