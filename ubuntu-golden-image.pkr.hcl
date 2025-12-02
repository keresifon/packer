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
  default     = "us-east-1"
}

# Variables - Image Configuration
variable "ubuntu_version" {
  type        = string
  description = "Ubuntu version to use"
  default     = "22.04"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type for building"
  default     = "t3.micro"
}

variable "hcp_bucket_name" {
  type        = string
  description = "HCP Packer bucket name"
  default     = "ubuntu-golden-image"
}

variable "image_name" {
  type        = string
  description = "Name for the AMI"
  default     = "ubuntu-golden-image"
}

variable "ssh_username" {
  type        = string
  description = "SSH username for the instance"
  default     = "ubuntu"
}

# Variables - HCP Packer Configuration
variable "hcp_client_id" {
  type        = string
  description = "HCP Client ID"
  sensitive   = true
}

variable "hcp_client_secret" {
  type        = string
  description = "HCP Client Secret"
  sensitive   = true
}

variable "hcp_organization_id" {
  type        = string
  description = "HCP Organization ID"
}

variable "hcp_project_id" {
  type        = string
  description = "HCP Project ID"
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

  # Tags for the AMI
  tags = {
    Name        = var.image_name
    OS          = "Ubuntu"
    Version     = var.ubuntu_version
    ManagedBy   = "Packer"
    Environment = "Production"
  }

  # Tags for the snapshot
  snapshot_tags = {
    Name        = var.image_name
    OS          = "Ubuntu"
    Version     = var.ubuntu_version
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

  # HCP Packer Registry Configuration
  # This will auto-create the bucket if it doesn't exist
  hcp_packer_registry {
    bucket_name = var.hcp_bucket_name
    description = "Ubuntu Golden Image for AWS"
    bucket_labels = {
      "os"         = "ubuntu"
      "managed-by" = "packer"
    }
  }

  # Provisioning: Update system
  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get upgrade -y",
      "sudo apt-get install -y software-properties-common",
      "sudo apt-get autoremove -y",
      "sudo apt-get autoclean -y"
    ]
  }

  # Provisioning: Install common packages
  provisioner "shell" {
    inline = [
      "sudo apt-get install -y curl wget git unzip",
      "sudo apt-get install -y awscli",
      "sudo apt-get install -y htop net-tools",
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

  # HCP Packer integration is handled by the hcp_packer_registry block above
  # No post-processor needed - metadata is published automatically
}

