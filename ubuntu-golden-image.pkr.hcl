packer {

  required_plugins {

    amazon = {

      source  = "github.com/hashicorp/amazon"

      version = "~> 1"

    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = "~> 1"
    }
  }

}

# Variables - AWS Configuration

# Note: AWS credentials are provided via environment/role (OIDC in GitHub Actions)

# For local development, use AWS CLI or environment variables
# Defaults can be overridden via config/build-config.yml or environment variables
variable "aws_region" {

  type        = string

  description = "AWS region to build the image in"
  default     = "us-east-1"  # Overridden by config/build-config.yml in CI/CD
}

# Variables - Image Configuration
variable "ubuntu_version" {
  type        = string
  description = "Ubuntu version to use"
  default     = "22.04"  # Overridden by config/build-config.yml in CI/CD
}

variable "instance_type" {

  type        = string

  description = "EC2 instance type for building"
  default     = "t3.micro"  # Overridden by config/build-config.yml in CI/CD
}

variable "image_name" {

  type        = string

  description = "Name for the AMI"
  default     = "ubuntu-golden-image"  # Overridden by config/build-config.yml in CI/CD
}

variable "iam_instance_profile" {

  type        = string
  description = "SSH username for the instance"
  default     = "ubuntu"  # Overridden by config/build-config.yml in CI/CD
}

# Variables - Block Device Configuration
variable "block_device_name" {
  type        = string
  description = "Block device name"
  default     = "/dev/sda1"  # Overridden by config/build-config.yml in CI/CD
}

variable "volume_size" {
  type        = number
  description = "Volume size in GB"
  default     = 20  # Overridden by config/build-config.yml in CI/CD
}

variable "volume_type" {
  type        = string
  description = "Volume type"
  default     = "gp3"  # Overridden by config/build-config.yml in CI/CD
}

variable "volume_encrypted" {
  type        = bool
  description = "Enable volume encryption"
  default     = true  # Overridden by config/build-config.yml in CI/CD
}

# Variables - Tag Configuration
variable "tag_os" {
  type        = string
  description = "OS tag value"
  default     = "Ubuntu"  # Overridden by config/build-config.yml in CI/CD
}

variable "tag_managed_by" {
  type        = string
  description = "ManagedBy tag value"
  default     = "Packer"  # Overridden by config/build-config.yml in CI/CD
}

variable "tag_environment" {
  type        = string
  description = "Environment tag value"
  default     = "Production"  # Overridden by config/build-config.yml in CI/CD
}

# Variables - CIS Benchmark Configuration
variable "cis_level" {
  type        = number
  description = "CIS Benchmark Level (1 or 2)"
  default     = 2  # Overridden by config/build-config.yml in CI/CD
}

variable "cis_compliance_threshold" {
  type        = number
  description = "Minimum compliance percentage to pass (0-100)"
  default     = 80  # Overridden by config/build-config.yml in CI/CD
}

variable "fail_on_non_compliance" {
  type        = bool
  description = "Fail build if compliance below threshold"
  default     = false  # Overridden by config/build-config.yml in CI/CD
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

  iam_instance_profile = var.iam_instance_profile

  # VPC configuration (optional - only set if provided)

  # Note: If subnet_id is specified, vpc_id must also be specified

  # The subnet must exist in the specified VPC and region

  # SSM works with private IPs, so public IP is not required

  vpc_id    = var.vpc_id != "" ? var.vpc_id : null

  subnet_id = var.subnet_id != "" ? var.subnet_id : null

  # Security group configuration

  # Packer creates a temporary security group automatically

  # With SSM, no inbound ports need to be opened (SSM uses outbound HTTPS)

  # If you have issues, you can pre-create a security group and specify it here:

  # security_group_ids = ["sg-xxxxxxxxx"]

  # Tags for the AMI (values from config/build-config.yml)
  tags = {

    Name        = var.image_name
    OS          = var.tag_os
    Version     = var.ubuntu_version
    ManagedBy   = var.tag_managed_by
    Environment = var.tag_environment
    CISLevel    = "L${var.cis_level}"
  }

  # Tags for the snapshot (values from config/build-config.yml)
  snapshot_tags = {

    Name        = var.image_name
    OS          = var.tag_os
    Version     = var.ubuntu_version
    ManagedBy   = var.tag_managed_by
    CISLevel    = "L${var.cis_level}"
  }

  # Launch block device mappings (values from config/build-config.yml)
  launch_block_device_mappings {
    device_name           = var.block_device_name
    volume_size           = var.volume_size
    volume_type           = var.volume_type
    delete_on_termination = true
    encrypted             = var.volume_encrypted
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

  provisioner "shell" {

    inline = [
      "# Wait for cloud-init to complete",
      "sudo cloud-init status --wait || true",
      "# Ensure apt lists directory exists",
      "sudo mkdir -p /var/lib/apt/lists/partial",
      "sudo mkdir -p /var/lib/apt/lists/auxfiles",
      "# Clean apt cache to avoid corruption issues",
      "sudo apt-get clean",
      "sudo rm -rf /var/lib/apt/lists/*",
      "# Update package lists with retry",
      "for i in 1 2 3; do sudo apt-get update && break || sleep 10; done",
      "# Upgrade system packages",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold'",
      "# Install required packages",
      "sudo apt-get install -y software-properties-common python3 python3-pip",
      "# Cleanup",
      "sudo apt-get autoremove -y",
      "sudo apt-get autoclean -y"
    ]

  }

  # Provisioning: Install common packages

  provisioner "shell" {

    inline = [

      "# Install common utilities",

      "sudo dnf install -y curl wget git unzip",

      "sudo dnf install -y htop net-tools",

      "# Install AWS CLI v2 using official installer",

      "curl \"https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip\" -o \"/tmp/awscliv2.zip\"",

      "unzip -q /tmp/awscliv2.zip -d /tmp",

      "sudo /tmp/aws/install",

      "rm -rf /tmp/aws /tmp/awscliv2.zip",

      "# Install jq",

      "sudo dnf install -y jq || echo 'Warning: jq installation skipped'"

    ]

  }

  # Provisioning: Ensure SSM Agent is running and enabled

  # Amazon Linux 2023 comes with SSM Agent pre-installed, but ensure it's enabled

  provisioner "shell" {

    inline = [

      "# Ensure SSM Agent is enabled and running",

      "sudo systemctl enable amazon-ssm-agent",

      "sudo systemctl start amazon-ssm-agent",

      "sudo systemctl status amazon-ssm-agent || true"

    ]

  }

  # Provisioning: Install Ansible
  provisioner "shell" {
    inline = [
      "sudo pip3 install ansible",
      "ansible --version"
    ]
  }

  # Provisioning: Copy Ansible directory to remote instance
  # This ensures all task files, vars, and playbooks are available
  provisioner "file" {
    source      = "ansible"
    destination = "/tmp"
  }

  # Provisioning: CIS Benchmark Hardening with Ansible
  # Run ansible-playbook directly from the copied directory
  provisioner "shell" {
    environment_vars = [
      "ANSIBLE_FORCE_COLOR=1",
      "PYTHONUNBUFFERED=1"
    ]
    inline = [
      "cd /tmp/ansible && ansible-playbook cis-hardening-playbook.yml -e cis_level=${var.cis_level} -e cis_compliance_threshold=${var.cis_compliance_threshold} -v -c local -i localhost,"
    ]
  }

  # Provisioning: CIS Compliance Check with Ansible
  provisioner "shell" {
    environment_vars = [
      "ANSIBLE_FORCE_COLOR=1",
      "PYTHONUNBUFFERED=1"
    ]
    inline = [
      "cd /tmp/ansible && ansible-playbook cis-compliance-check.yml -e cis_compliance_threshold=${var.cis_compliance_threshold} -e fail_build_on_non_compliance=${var.fail_on_non_compliance} -v -c local -i localhost,"
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

      "sudo dnf clean all",

      "# Sync filesystem",

      "sudo sync"

    ]

  }

}