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
  default     = "ca-central-1"
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
  
  # VPC configuration (optional - only set if provided)
  # Note: If subnet_id is specified, vpc_id must also be specified
  # The subnet must exist in the specified VPC and region
  vpc_id    = var.vpc_id != "" ? var.vpc_id : null
  subnet_id = var.subnet_id != "" ? var.subnet_id : null
  
  # Ensure instance gets a public IP for internet access during provisioning
  # Required for: package downloads, AWS CLI installation, SSH access from Packer
  associate_public_ip_address = true
  
  # SSH configuration for connecting to the instance
  # When using VPC, Packer needs explicit SSH settings
  ssh_interface            = "public_ip"  # Use public IP instead of private IP
  ssh_timeout              = "15m"         # Increase timeout to 15 minutes
  ssh_handshake_attempts   = 50           # Retry SSH handshake up to 50 times
  ssh_clear_authorized_keys = false       # Don't clear authorized keys (use default)
  
  # Security group configuration
  # Packer creates a temporary security group, but we need to ensure it allows SSH
  # If you have a custom security group, you can specify it here
  # Otherwise, Packer will create one with SSH access from 0.0.0.0/0

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

