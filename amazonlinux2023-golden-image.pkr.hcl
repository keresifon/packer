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
variable "aws_region" {
  type        = string
  description = "AWS region to build the image in"
  default     = "us-east-1"
}

# Variables - VPC Configuration (Required for private subnet)
variable "vpc_id" {
  type        = string
  description = "VPC ID where the build instance will be launched"
  default     = ""
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID (private subnet) where the build instance will be launched"
  default     = ""
}

variable "security_group_ids" {
  type        = list(string)
  description = "Security group IDs for the build instance (must allow SSM Session Manager)"
  default     = []
}

variable "iam_instance_profile" {
  type        = string
  description = "IAM instance profile name for SSM Session Manager access"
  default     = ""
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

# Variables - Block Device Configuration
variable "block_device_name" {
  type        = string
  description = "Block device name"
  default     = "/dev/xvda"
}

variable "volume_size" {
  type        = number
  description = "Volume size in GB"
  default     = 20
}

variable "volume_type" {
  type        = string
  description = "Volume type"
  default     = "gp3"
}

variable "volume_encrypted" {
  type        = bool
  description = "Enable volume encryption"
  default     = true
}

# Variables - Tag Configuration
variable "tag_os" {
  type        = string
  description = "OS tag value"
  default     = "AmazonLinux2023"
}

variable "tag_managed_by" {
  type        = string
  description = "ManagedBy tag value"
  default     = "Packer"
}

variable "tag_environment" {
  type        = string
  description = "Environment tag value"
  default     = "Production"
}

# Variables - CIS Benchmark Configuration
variable "cis_level" {
  type        = number
  description = "CIS Benchmark Level (1 or 2)"
  default     = 2
}

variable "cis_compliance_threshold" {
  type        = number
  description = "Minimum compliance percentage to pass (0-100)"
  default     = 80
}

variable "fail_on_non_compliance" {
  type        = bool
  description = "Fail build if compliance below threshold"
  default     = false
}

# Data source for latest Amazon Linux 2023 AMI
data "amazon-ami" "amazonlinux2023" {
  filters = {
    name                = "al2023-ami-*-x86_64"
    root-device-type    = "ebs"
    virtualization-type = "hvm"
  }
  most_recent = true
  owners      = ["amazon"]
  region      = var.aws_region
}

# Build source
source "amazon-ebs" "amazonlinux2023" {
  ami_name      = "${var.image_name}-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  instance_type = var.instance_type
  region        = var.aws_region
  source_ami    = data.amazon-ami.amazonlinux2023.id

  # VPC Configuration - Required for private subnet
  vpc_id             = var.vpc_id != "" ? var.vpc_id : null
  subnet_id          = var.subnet_id != "" ? var.subnet_id : null
  security_group_ids = length(var.security_group_ids) > 0 ? var.security_group_ids : null
  iam_instance_profile = var.iam_instance_profile != "" ? var.iam_instance_profile : null

  # Use SSM Session Manager instead of SSH (required for private subnet)
  # Packer will use SSM Session Manager when ssh_interface is set to "session_manager"
  # This allows connection to instances in private subnets without direct internet access
  # SSM agent is pre-installed on Amazon Linux 2023
  # Instance must have IAM role with SSM permissions (AmazonSSMManagedInstanceCore policy)
  ssh_interface = "session_manager"
  # Don't create temporary SSH keypair when using SSM Session Manager
  temporary_key_pair_type = "none"
  
  # Tags for the AMI
  tags = {
    Name        = var.image_name
    OS          = var.tag_os
    ManagedBy   = var.tag_managed_by
    Environment = var.tag_environment
    CISLevel    = "L${var.cis_level}"
  }

  # Tags for the snapshot
  snapshot_tags = {
    Name        = var.image_name
    OS          = var.tag_os
    ManagedBy   = var.tag_managed_by
    CISLevel    = "L${var.cis_level}"
  }

  # Launch block device mappings
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
  provisioner "shell" {
    inline = [
      "# Wait for cloud-init to complete",
      "sudo cloud-init status --wait || true",
      "# Clean DNF cache to avoid corruption issues",
      "sudo mkdir -p /var/cache/dnf",
      "sudo find /var/cache/dnf -type f -name '*.pid' -delete 2>/dev/null || true",
      "sudo find /var/cache/dnf -type f -name '*.rpm' -delete 2>/dev/null || true",
      "sudo dnf clean all || true",
      "# Update package lists with retry",
      "for i in 1 2 3; do sudo dnf makecache && break || sleep 10; done",
      "# Upgrade system packages",
      "sudo dnf upgrade -y",
      "# Install required packages",
      "sudo dnf install -y python3 python3-pip git unzip",
      "# Cleanup",
      "sudo dnf autoremove -y",
      "sudo dnf clean all"
    ]
  }

  # Provisioning: Install common packages
  provisioner "shell" {
    inline = [
      "sudo dnf install -y curl wget jq htop net-tools",
      "# Install AWS CLI v2 using official installer",
      "curl \"https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip\" -o \"/tmp/awscliv2.zip\"",
      "unzip -q /tmp/awscliv2.zip -d /tmp",
      "sudo /tmp/aws/install",
      "rm -rf /tmp/aws /tmp/awscliv2.zip"
    ]
  }

  # Provisioning: Configure SSH (optional - harden SSH)
  provisioner "shell" {
    inline = [
      "sudo sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config || true",
      "sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config || true",
      "sudo systemctl restart sshd || true"
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
  provisioner "file" {
    source      = "ansible"
    destination = "/tmp"
  }

  # Provisioning: CIS Benchmark Hardening with Ansible
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
      "sudo cloud-init clean",
      "sudo rm -f /var/log/cloud-init*.log",
      "sudo rm -rf /tmp/*",
      "sudo rm -rf /var/tmp/*",
      "sudo sync"
    ]
  }
}

