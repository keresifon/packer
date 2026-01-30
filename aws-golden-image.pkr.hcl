packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1"
    }
  }
}

variable "aws_region" {
  type        = string
  description = "AWS region to build the image in"
  default     = "us-east-1"
}

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

variable "source_ami_id" {
  type        = string
  description = "Specific AMI ID to use as source (overrides SSM parameter lookup)"
  default     = ""
}

# Use AWS Systems Manager Parameter Store to get the latest official AL2023 AMI (optional)
# Using data source as primary due to potential minimal AMI issues with SSM parameter
data "amazon-parameterstore" "amazonlinux2023" {
  name   = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
  region = var.aws_region
}

# Fallback: Use specific AMI filter to ensure we get full AL2023 with proper repo config
# Avoiding minimal variants that may have incomplete package repository setup
data "amazon-ami" "amazonlinux2023_fallback" {
  filters = {
    # Match only full AL2023 images with kernel version (not minimal)
    name                = "al2023-ami-2023.*-kernel-6.*-x86_64"
    root-device-type    = "ebs"
    virtualization-type = "hvm"
    architecture        = "x86_64"
  }
  most_recent = true
  owners      = ["137112412989"]  # Amazon's official owner ID
  region      = var.aws_region
}

# Determine which AMI to use (priority: manual override > data source > SSM parameter)
# Using data source as primary since SSM parameter may return minimal AMIs without proper repo config
locals {
  source_ami = var.source_ami_id != "" ? var.source_ami_id : data.amazon-ami.amazonlinux2023_fallback.id
}

source "amazon-ebs" "amazonlinux2023" {
  ami_name      = "${var.image_name}-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  instance_type = var.instance_type
  region        = var.aws_region
  source_ami    = local.source_ami

  
  communicator = "ssh"
  ssh_username = "ec2-user"
  ssh_interface = "session_manager"
  
  iam_instance_profile = var.iam_instance_profile != "" ? var.iam_instance_profile : null
  
  user_data = base64encode(<<-EOF
    #!/bin/bash
    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent
    sleep 10
  EOF
  )
  
  vpc_id    = var.vpc_id != "" ? var.vpc_id : null
  subnet_id = var.subnet_id != "" ? var.subnet_id : null
  
  associate_public_ip_address = false
  
  security_group_ids = length(var.security_group_ids) > 0 ? var.security_group_ids : null
  
  tags = {
    Name        = var.image_name
    OS          = "AmazonLinux2023"
    Version     = "2023"
    ManagedBy   = "Packer"
    Environment = "Production"
  }
  
  snapshot_tags = {
    Name        = var.image_name
    OS          = "AmazonLinux2023"
    Version     = "2023"
    ManagedBy   = "Packer"
  }
  
  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }
}

build {
  name = "amazonlinux2023-golden-image"
  sources = [
    "source.amazon-ebs.amazonlinux2023"
  ]
  
  # Provisioning: Update system
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
      "if command -v sudo >/dev/null 2>&1; then SUDO=sudo; else SUDO=''; fi",
      "# Install common utilities (--allowerasing replaces curl-minimal with full curl)",
      "$${SUDO} dnf install -y --allowerasing curl wget git unzip",
      "$${SUDO} dnf install -y htop net-tools",
      "$${SUDO} dnf install -y jq || echo 'Warning: jq installation skipped'"
    ]
  }
  
  # Provisioning: Ensure SSM Agent is installed, enabled, and running
  provisioner "shell" {
    inline = [
      "if command -v sudo >/dev/null 2>&1; then SUDO=sudo; else SUDO=''; fi",
      "if ! command -v amazon-ssm-agent >/dev/null 2>&1; then",
      "  echo 'SSM Agent not found, installing...'",
      "  $${SUDO} dnf install -y amazon-ssm-agent || echo 'Warning: Failed to install SSM Agent'",
      "fi",
      "if $${SUDO} systemctl list-unit-files | grep -q amazon-ssm-agent.service; then",
      "  echo 'SSM Agent service found'",
      "  $${SUDO} systemctl enable amazon-ssm-agent",
      "  $${SUDO} systemctl start amazon-ssm-agent",
      "  sleep 5",
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
      "if command -v sudo >/dev/null 2>&1; then SUDO=sudo; else SUDO=''; fi",
      "$${SUDO} sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config || true",
      "$${SUDO} sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config || true",
      "$${SUDO} sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config || true",
      "$${SUDO} systemctl restart sshd || true"
    ]
  }
  
  # Provisioning: Clean up
  provisioner "shell" {
    inline = [
      "if command -v sudo >/dev/null 2>&1; then SUDO=sudo; else SUDO=''; fi",
      "$${SUDO} cloud-init clean",
      "$${SUDO} rm -f /var/log/cloud-init*.log",
      "$${SUDO} rm -rf /tmp/*",
      "$${SUDO} rm -rf /var/tmp/*",
      "$${SUDO} dnf clean all",
      "$${SUDO} sync"
    ]
  }
}
