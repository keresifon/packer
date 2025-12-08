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

variable "ssh_username" {
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

# Data source for latest Ubuntu AMI
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
  ssh_username  = var.ssh_username

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
  name = "ubuntu-golden-image"
  sources = [
    "source.amazon-ebs.ubuntu"
  ]

  # Provisioning: Update system
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
      "sudo apt-get install -y curl wget git unzip",
      "sudo apt-get install -y htop net-tools",
      "# Install AWS CLI v2 using official installer",
      "curl \"https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip\" -o \"/tmp/awscliv2.zip\"",
      "unzip -q /tmp/awscliv2.zip -d /tmp",
      "sudo /tmp/aws/install",
      "rm -rf /tmp/aws /tmp/awscliv2.zip",
      "# Install jq - handle dependency issues by installing libonig5 first or skip if unavailable",
      "sudo apt-get install -y libonig5 || sudo apt-get install -y jq || echo 'Warning: jq installation skipped due to dependency issues'"
    ]
  }

  # Provisioning: Configure SSH (optional - harden SSH)
  provisioner "shell" {
    inline = [
      "sudo sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config",
      "sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config",
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
      "sudo cloud-init clean",
      "sudo rm -f /var/log/cloud-init*.log",
      "sudo rm -rf /tmp/*",
      "sudo rm -rf /var/tmp/*",
      "sudo sync"
    ]
  }

}

