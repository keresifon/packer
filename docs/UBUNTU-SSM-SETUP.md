# Using SSM Session Manager with Ubuntu Images

This guide explains how to configure Packer to use SSM Session Manager with Ubuntu images in private subnets, similar to Amazon Linux 2023.

## Key Differences from Amazon Linux 2023

1. **SSM Agent not pre-installed**: Ubuntu doesn't include SSM Agent by default
2. **Installation required**: Must install SSM Agent via `user_data` script
3. **Timing critical**: SSM Agent must be installed and running before Packer connects
4. **Package manager**: Uses `apt-get` instead of `dnf`

## Solution: Install SSM Agent via user_data

The `user_data` script must:
1. Install SSM Agent
2. Start the service
3. Wait for it to be ready before Packer connects

## Example Packer Configuration for Ubuntu

```hcl
source "amazon-ebs" "ubuntu" {
  ami_name      = "ubuntu-golden-image-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  instance_type = "t3.micro"
  region        = "us-east-2"
  source_ami    = data.amazon-ami.ubuntu.id
  
  # Use SSM Session Manager
  communicator = "ssh"
  ssh_username = "ubuntu"  # Default user for Ubuntu
  ssh_interface = "session_manager"
  
  # IAM instance profile for SSM
  iam_instance_profile = var.iam_instance_profile != "" ? var.iam_instance_profile : null
  
  # CRITICAL: Install and start SSM Agent via user_data
  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -e
    
    # Update package list
    apt-get update -y
    
    # Install SSM Agent
    # Method 1: Using snap (Ubuntu 18.04+)
    snap install amazon-ssm-agent --classic || {
      # Method 2: Using deb package (fallback)
      mkdir -p /tmp/ssm
      cd /tmp/ssm
      wget https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/debian_amd64/amazon-ssm-agent.deb
      dpkg -i amazon-ssm-agent.deb || apt-get install -f -y
      rm -rf /tmp/ssm
    }
    
    # Start SSM Agent
    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent
    
    # Wait for SSM Agent to be ready and registered
    # This is critical - Packer needs SSM Agent to be ready before connecting
    echo "Waiting for SSM Agent to be ready..."
    for i in {1..30}; do
      if systemctl is-active --quiet amazon-ssm-agent && \
         [ -f /var/lib/amazon/ssm/registration ]; then
        echo "SSM Agent is ready"
        break
      fi
      echo "Waiting for SSM Agent... ($i/30)"
      sleep 2
    done
    
    # Verify SSM Agent is running
    systemctl status amazon-ssm-agent --no-pager || echo "Warning: SSM Agent status check"
    
    # Signal that user_data is complete
    # This helps Packer know when to start connecting
    touch /var/lib/cloud/instance/boot-finished
  EOF
  )
  
  # Private subnet configuration
  vpc_id    = var.vpc_id != "" ? var.vpc_id : null
  subnet_id = var.subnet_id != "" ? var.subnet_id : null
  associate_public_ip_address = false
  
  # Security group (same as Amazon Linux)
  security_group_ids = length(var.security_group_ids) > 0 ? var.security_group_ids : null
}
```

## Important Considerations

### 1. Timing Issue

**Problem**: Packer may try to connect before SSM Agent is ready.

**Solutions**:
- **Option A**: Use `ssh_ready_timeout` to give SSM Agent time to start
  ```hcl
  communicator = "ssh"
  ssh_username = "ubuntu"
  ssh_interface = "session_manager"
  ssh_ready_timeout = "10m"  # Give it time to install and start
  ```

- **Option B**: Use a more robust user_data script that waits for SSM registration
  ```bash
  # Wait until SSM Agent is registered with AWS
  while [ ! -f /var/lib/amazon/ssm/registration ]; do
    sleep 2
  done
  ```

### 2. Network Access for Installation

**Problem**: SSM Agent installer needs to be downloaded.

**Solutions**:
- **With NAT Gateway**: Works automatically (internet access)
- **With VPC Endpoints**: Need S3 VPC Gateway endpoint to download from S3
- **Pre-install**: Pre-bake SSM Agent into a custom AMI

### 3. SSM Agent Installation Methods

**Method 1: Snap (Recommended for Ubuntu 18.04+)**
```bash
snap install amazon-ssm-agent --classic
```

**Method 2: Deb Package**
```bash
wget https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/debian_amd64/amazon-ssm-agent.deb
dpkg -i amazon-ssm-agent.deb
apt-get install -f -y  # Fix dependencies
```

**Method 3: From Ubuntu Repos (if available)**
```bash
apt-get install -y amazon-ssm-agent
```

## Complete Example: Ubuntu with SSM

Here's a complete example combining everything:

```hcl
variable "iam_instance_profile" {
  type    = string
  default = ""
}

variable "vpc_id" {
  type    = string
  default = ""
}

variable "subnet_id" {
  type    = string
  default = ""
}

variable "security_group_ids" {
  type    = list(string)
  default = []
}

data "amazon-ami" "ubuntu" {
  filters = {
    name                = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
    root-device-type    = "ebs"
    virtualization-type = "hvm"
  }
  most_recent = true
  owners      = ["099720109477"] # Canonical
  region      = "us-east-2"
}

source "amazon-ebs" "ubuntu" {
  ami_name      = "ubuntu-ssm-golden-image-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  instance_type = "t3.micro"
  region        = "us-east-2"
  source_ami    = data.amazon-ami.ubuntu.id
  
  # SSM Session Manager configuration
  communicator     = "ssh"
  ssh_username     = "ubuntu"
  ssh_interface    = "session_manager"
  ssh_ready_timeout = "10m"  # Give time for SSM Agent installation
  
  iam_instance_profile = var.iam_instance_profile != "" ? var.iam_instance_profile : null
  
  # Install SSM Agent via user_data
  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -e
    exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
    
    echo "Starting SSM Agent installation..."
    
    # Update package list
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    
    # Install SSM Agent using snap (Ubuntu 18.04+)
    if command -v snap >/dev/null 2>&1; then
      echo "Installing SSM Agent via snap..."
      snap install amazon-ssm-agent --classic
    else
      echo "Snap not available, installing via deb package..."
      mkdir -p /tmp/ssm
      cd /tmp/ssm
      wget -q https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/debian_amd64/amazon-ssm-agent.deb
      dpkg -i amazon-ssm-agent.deb || apt-get install -f -y
      rm -rf /tmp/ssm
    fi
    
    # Start SSM Agent
    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent
    
    # Wait for SSM Agent to register (critical for Packer connection)
    echo "Waiting for SSM Agent to register..."
    MAX_WAIT=60
    WAIT_COUNT=0
    while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
      if systemctl is-active --quiet amazon-ssm-agent; then
        # Check if agent has registered (file exists after registration)
        if [ -f /var/lib/amazon/ssm/registration ] || \
           systemctl status amazon-ssm-agent | grep -q "running"; then
          echo "SSM Agent is ready and running"
          break
        fi
      fi
      WAIT_COUNT=$((WAIT_COUNT + 1))
      echo "Waiting for SSM Agent registration... ($WAIT_COUNT/$MAX_WAIT)"
      sleep 2
    done
    
    # Final status check
    systemctl status amazon-ssm-agent --no-pager || echo "Warning: SSM Agent status check"
    
    echo "SSM Agent installation complete"
    touch /var/lib/cloud/instance/boot-finished
  EOF
  )
  
  # VPC configuration
  vpc_id    = var.vpc_id != "" ? var.vpc_id : null
  subnet_id = var.subnet_id != "" ? var.subnet_id : null
  associate_public_ip_address = false
  security_group_ids = length(var.security_group_ids) > 0 ? var.security_group_ids : null
  
  tags = {
    Name      = "ubuntu-ssm-golden-image"
    OS        = "Ubuntu"
    Version   = "22.04"
    ManagedBy = "Packer"
  }
}

build {
  name = "ubuntu-ssm-golden-image"
  sources = ["source.amazon-ebs.ubuntu"]
  
  # Provisioning steps...
  provisioner "shell" {
    inline = [
      "echo 'Provisioning Ubuntu instance via SSM'",
      "sudo apt-get update -y",
      "sudo apt-get upgrade -y",
      # ... other provisioning steps
    ]
  }
}
```

## Comparison: Ubuntu vs Amazon Linux 2023

| Feature | Amazon Linux 2023 | Ubuntu |
|---------|------------------|--------|
| SSM Agent pre-installed | ✅ Yes | ❌ No |
| Installation method | Enable service | Install + enable |
| user_data complexity | Simple (start service) | Complex (install + start + wait) |
| Reliability | High | Medium (timing dependent) |
| Network requirements | Same (VPC endpoints/NAT) | Same + S3 for installer |

## Best Practices

1. **Use `ssh_ready_timeout`**: Give Packer enough time (10+ minutes) for installation
2. **Robust user_data**: Include retry logic and status checks
3. **Logging**: Log user_data execution to troubleshoot issues
4. **Test first**: Test SSM Agent installation in a standalone instance before Packer
5. **Consider pre-baking**: Create a base AMI with SSM Agent already installed

## Troubleshooting

**SSM Agent not connecting?**
1. Check user_data logs: `/var/log/user-data.log` or `/var/log/cloud-init-output.log`
2. Verify IAM instance profile has `AmazonSSMManagedInstanceCore` policy
3. Check security group allows outbound HTTPS (443)
4. Verify VPC endpoints or NAT Gateway is configured
5. Check SSM Agent status: `systemctl status amazon-ssm-agent`

**Packer timeout?**
- Increase `ssh_ready_timeout` to 15-20 minutes
- Check if SSM Agent installation is completing successfully
- Verify network connectivity (can download SSM Agent installer)

## Recommendation

For **private subnets**, using SSM Session Manager with Ubuntu is **possible but more complex** than Amazon Linux 2023. Consider:

1. **Use Amazon Linux 2023** if possible (simpler, more reliable)
2. **Pre-bake SSM Agent** into a base Ubuntu AMI if you must use Ubuntu
3. **Use NAT Gateway** for simpler network setup (allows internet access for installer)

The same VPC endpoints and security group configuration applies to Ubuntu as it does to Amazon Linux 2023.

