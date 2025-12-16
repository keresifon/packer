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

source "amazon-ebs" "ubuntu" {
  ami_name      = "${var.image_name}-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  instance_type = var.instance_type
  region        = var.aws_region
  source_ami    = data.amazon-ami.ubuntu.id
  
  communicator = "ssh"
  ssh_username = "ubuntu"
  ssh_interface = "session_manager"
  
  iam_instance_profile = var.iam_instance_profile != "" ? var.iam_instance_profile : null
  
  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -e
    exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
    
    echo "Starting SSM Agent installation via User Data..."
    
    # Wait for cloud-init to complete before installing SSM Agent
    cloud-init status --wait
    
    # Install SSM Agent using snap (Ubuntu 22.04+)
    if command -v snap >/dev/null 2>&1; then
      echo "Installing SSM Agent via snap..."
      snap install amazon-ssm-agent --classic
      systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
      systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service
    else
      echo "Snap not available, installing via deb package..."
      mkdir -p /tmp/ssm
      cd /tmp/ssm
      wget -q https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/debian_amd64/amazon-ssm-agent.deb
      dpkg -i amazon-ssm-agent.deb || apt-get install -f -y
      rm -rf /tmp/ssm
      systemctl enable amazon-ssm-agent
      systemctl start amazon-ssm-agent
    fi
    
    # Wait for SSM Agent to register with AWS
    echo "Waiting for SSM Agent to register..."
    MAX_WAIT=60
    WAIT_COUNT=0
    while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
      if systemctl is-active --quiet snap.amazon-ssm-agent.amazon-ssm-agent.service 2>/dev/null || \
         systemctl is-active --quiet amazon-ssm-agent.service 2>/dev/null; then
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
    
    echo "SSM Agent installation complete"
    touch /var/lib/cloud/instance/boot-finished
  EOF
  )
  
  # Give SSM Agent time to install and register before Packer connects
  pause_before_connecting = "3m"
  
  vpc_id    = var.vpc_id != "" ? var.vpc_id : null
  subnet_id = var.subnet_id != "" ? var.subnet_id : null
  
  associate_public_ip_address = false
  
  security_group_ids = length(var.security_group_ids) > 0 ? var.security_group_ids : null
  
  tags = {
    Name        = var.image_name
    OS          = "Ubuntu"
    Version     = "22.04"
    ManagedBy   = "Packer"
    Environment = "Production"
  }
  
  snapshot_tags = {
    Name        = var.image_name
    OS          = "Ubuntu"
    Version     = "22.04"
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
  name = "ubuntu-golden-image"
  sources = [
    "source.amazon-ebs.ubuntu"
  ]
  
  # Provisioning: Update system
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
      "sudo apt-get install -y curl wget git unzip",
      "sudo apt-get install -y htop net-tools",
      "sudo apt-get install -y jq || echo 'Warning: jq installation skipped'"
    ]
  }
  
  # Provisioning: Verify SSM Agent is running
  provisioner "shell" {
    inline = [
      "if systemctl is-active --quiet snap.amazon-ssm-agent.amazon-ssm-agent.service 2>/dev/null; then",
      "  echo 'SSM Agent (snap) is running'",
      "  systemctl status snap.amazon-ssm-agent.amazon-ssm-agent.service --no-pager || true",
      "elif systemctl is-active --quiet amazon-ssm-agent.service 2>/dev/null; then",
      "  echo 'SSM Agent (deb) is running'",
      "  systemctl status amazon-ssm-agent.service --no-pager || true",
      "else",
      "  echo 'Warning: SSM Agent service not found or not running'",
      "fi"
    ]
  }
  
  # Provisioning: Configure SSH (optional - harden SSH)
  provisioner "shell" {
    inline = [
      "sudo sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config || true",
      "sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config || true",
      "sudo sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config || true",
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
      "sudo apt-get clean",
      "sudo sync"
    ]
  }
}
