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

  description = "IAM instance profile name for SSM access (optional - Packer can create temporary one)"

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

  # Option 1: Use existing instance profile (if provided)

  iam_instance_profile = var.iam_instance_profile != "" ? var.iam_instance_profile : null

  # Option 2: Let Packer create temporary instance profile with required SSM permissions

  # This policy document grants the instance permission to use SSM Session Manager

  temporary_iam_instance_profile_policy_document = jsonencode({

    Version = "2012-10-17"

    Statement = [

      {

        Effect = "Allow"

        Action = [

          "ssm:UpdateInstanceInformation",

          "ssmmessages:CreateControlChannel",

          "ssmmessages:CreateDataChannel",

          "ssmmessages:OpenControlChannel",

          "ssmmessages:OpenDataChannel"

        ]

        Resource = "*"

      }

    ]

  })

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

  # Tags for the AMI

  tags = {

    Name        = var.image_name

    OS          = "AmazonLinux2023"

    ManagedBy   = "Packer"

    Environment = "Production"

  }

  # Tags for the snapshot

  snapshot_tags = {

    Name        = var.image_name

    OS          = "AmazonLinux2023"

    ManagedBy   = "Packer"

  }

  # Launch block device mappings

  # Amazon Linux 2023 uses /dev/xvda as the root device

  launch_block_device_mappings {

    device_name           = "/dev/xvda"

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

  provisioner "shell" {

    inline = [

      "sudo dnf update -y",

      "sudo dnf upgrade -y",

      "sudo dnf clean all"

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