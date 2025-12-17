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

variable "cis_s3_bucket" {
  type        = string
  description = "S3 bucket name containing CIS tools (optional - CIS hardening will be skipped if not provided)"
  default     = ""
}

variable "cis_s3_prefix" {
  type        = string
  description = "S3 prefix/path for CIS tools (default: cis-tools)"
  default     = "cis-tools"
}

variable "enable_cis_hardening" {
  type        = bool
  description = "Enable CIS Level 2 hardening (requires cis_s3_bucket to be set)"
  default     = true
}

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

source "amazon-ebs" "amazonlinux2023" {
  ami_name      = "${var.image_name}-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  instance_type = var.instance_type
  region        = var.aws_region
  source_ami    = data.amazon-ami.amazonlinux2023.id
  
  communicator = "ssh"
  ssh_username = "ec2-user"
  ssh_interface = "session_manager"
  
  # Note: Packer may still create a temporary keypair when using Session Manager
  # This is a fallback mechanism, but Session Manager handles the actual connection
  # The keypair is created but not used - Session Manager uses IAM authentication instead
  # Setting temporary_key_pair_name to empty string attempts to disable it
  temporary_key_pair_name = ""
  
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
      "# Clean DNF cache and lock files to prevent corruption",
      "$${SUDO} mkdir -p /var/cache/dnf",
      "$${SUDO} find /var/cache/dnf -type f -name '*.pid' -delete 2>/dev/null || true",
      "$${SUDO} find /var/cache/dnf -type f -name '*.rpm' -delete 2>/dev/null || true",
      "$${SUDO} dnf clean all || true",
      "$${SUDO} dnf clean packages || true",
      "$${SUDO} dnf clean metadata || true",
      "# Update system packages (use --allowerasing to handle curl-minimal conflicts)",
      "$${SUDO} dnf update -y --allowerasing --setopt=keepcache=0 --setopt=metadata_expire=0",
      "$${SUDO} dnf upgrade -y --allowerasing --setopt=keepcache=0 --setopt=metadata_expire=0",
      "$${SUDO} dnf clean all || true"
    ]
  }
  
  # Provisioning: Install common packages
  provisioner "shell" {
    inline = [
      "if command -v sudo >/dev/null 2>&1; then SUDO=sudo; else SUDO=''; fi",
      "# Clean DNF cache before each install to prevent corruption",
      "$${SUDO} mkdir -p /var/cache/dnf",
      "$${SUDO} find /var/cache/dnf -type f -name '*.pid' -delete 2>/dev/null || true",
      "$${SUDO} find /var/cache/dnf -type f -name '*.rpm' -delete 2>/dev/null || true",
      "# Install common utilities (--allowerasing replaces curl-minimal with full curl)",
      "$${SUDO} dnf install -y --allowerasing --setopt=keepcache=0 --setopt=metadata_expire=0 curl wget git unzip",
      "$${SUDO} find /var/cache/dnf -type f -name '*.rpm' -delete 2>/dev/null || true",
      "$${SUDO} dnf install -y --setopt=keepcache=0 --setopt=metadata_expire=0 htop net-tools",
      "$${SUDO} find /var/cache/dnf -type f -name '*.rpm' -delete 2>/dev/null || true",
      "$${SUDO} dnf install -y --setopt=keepcache=0 --setopt=metadata_expire=0 jq || echo 'Warning: jq installation skipped'"
    ]
  }
  
  # Provisioning: Ensure SSM Agent is installed, enabled, and running
  provisioner "shell" {
    inline = [
      "if command -v sudo >/dev/null 2>&1; then SUDO=sudo; else SUDO=''; fi",
      "if ! command -v amazon-ssm-agent >/dev/null 2>&1; then",
      "  echo 'SSM Agent not found, installing...'",
      "  $${SUDO} mkdir -p /var/cache/dnf",
      "  $${SUDO} find /var/cache/dnf -type f -name '*.pid' -delete 2>/dev/null || true",
      "  $${SUDO} find /var/cache/dnf -type f -name '*.rpm' -delete 2>/dev/null || true",
      "  $${SUDO} dnf install -y --setopt=keepcache=0 --setopt=metadata_expire=0 amazon-ssm-agent || echo 'Warning: Failed to install SSM Agent'",
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
  
  # Provisioning: Install AWS CLI (optional - useful for general AWS operations)
  provisioner "shell" {
    inline = [
      "if command -v sudo >/dev/null 2>&1; then SUDO=sudo; else SUDO=''; fi",
      "if ! command -v aws >/dev/null 2>&1; then",
      "  echo 'Installing AWS CLI...'",
      "  $${SUDO} curl -fsSL 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o /tmp/awscliv2.zip || echo 'AWS CLI download failed'",
      "  $${SUDO} unzip -q /tmp/awscliv2.zip -d /tmp || echo 'AWS CLI extraction failed'",
      "  $${SUDO} /tmp/aws/install || echo 'AWS CLI installation failed'",
      "  $${SUDO} rm -rf /tmp/awscliv2.zip /tmp/aws || true",
      "fi"
    ]
  }

  # Provisioning: Apply CIS Level 2 Hardening
  # Note: CIS tools (OpenSCAP, SCAP content) are downloaded in the separate assessment job, not during build
  provisioner "shell" {
    environment_vars = [
      "ENABLE_CIS_HARDENING=${var.enable_cis_hardening}"
    ]
    script = "scripts/cis/cis-level2-hardening.sh"
  }

  # Note: CIS Assessment is now run as a separate validation job after AMI creation
  # This allows assessment to run on a fresh instance launched from the built AMI

  # Provisioning: Configure SSH (CIS hardening may have already configured this)
  provisioner "shell" {
    inline = [
      "if command -v sudo >/dev/null 2>&1; then SUDO=sudo; else SUDO=''; fi",
      "# SSH hardening (if not already done by CIS hardening)",
      "$${SUDO} sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config || true",
      "$${SUDO} sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config || true",
      "$${SUDO} sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config || true",
      "$${SUDO} systemctl restart sshd || true"
    ]
  }
  
  # Provisioning: Clean up
  # Note: Exclude Packer's temporary scripts (script_*.sh, packer-shell*) from cleanup
  # Packer needs to delete these itself, or it will fail with "Error removing temporary script"
  # We clean specific directories/files instead of using wildcards that might catch Packer's scripts
  provisioner "shell" {
    inline = [
      "if command -v sudo >/dev/null 2>&1; then SUDO=sudo; else SUDO=''; fi",
      "$${SUDO} cloud-init clean",
      "$${SUDO} rm -f /var/log/cloud-init*.log",
      "# Clean /tmp but exclude Packer's temporary scripts (script_*.sh, packer-shell*)",
      "# Use find to exclude Packer script patterns",
      "$${SUDO} find /tmp -mindepth 1 -maxdepth 1 -type f ! -name 'script_*.sh' ! -name 'packer-shell*' -delete 2>/dev/null || true",
      "$${SUDO} find /tmp -mindepth 1 -maxdepth 1 -type d ! -name 'script_*' ! -name 'packer-shell*' -exec rm -rf {} + 2>/dev/null || true",
      "# Clean /var/tmp (Packer doesn't use this directory)",
      "$${SUDO} rm -rf /var/tmp/* 2>/dev/null || true",
      "$${SUDO} dnf clean all",
      "$${SUDO} sync"
    ]
  }
}
