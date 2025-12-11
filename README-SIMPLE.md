# Manual Packer Build Guide for WSL2

This guide shows you how to manually build the AWS golden image using Packer in WSL2.

## Prerequisites

1. **Packer** - Installed locally (see `INSTALL-PACKER.md`)
2. **AWS CLI** - Configured with credentials
3. **Session Manager Plugin** - For SSM connectivity (optional but recommended)

## Step 1: Install Packer

Follow the instructions in `INSTALL-PACKER.md` to install Packer manually.

Quick version:
```bash
PACKER_VERSION="1.10.0"
wget https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip
unzip packer_${PACKER_VERSION}_linux_amd64.zip
sudo mv packer /usr/local/bin/
packer version
```

## Step 2: Configure AWS Credentials

```bash
# Configure AWS CLI
aws configure

# Or set environment variables
export AWS_ACCESS_KEY_ID=your-access-key
export AWS_SECRET_ACCESS_KEY=your-secret-key
export AWS_REGION=us-east-1

# Verify credentials
aws sts get-caller-identity
```

## Step 3: Navigate to Project Directory

```bash
# From WSL2, navigate to your Windows project directory
cd /mnt/c/Users/0B9947649/GHTest/packer
```

## Step 4: Initialize Packer Plugins

**First time only:**
```bash
packer init aws-golden-image.pkr.hcl
```

This downloads the required Packer plugins (amazon plugin).

## Step 5: Validate Template

```bash
packer validate aws-golden-image.pkr.hcl
```

This checks the template syntax and configuration.

## Step 6: Build the AMI

### Basic Build (Uses Defaults)

```bash
packer build aws-golden-image.pkr.hcl
```

Defaults:
- Region: `us-east-1`
- Instance Type: `t3.micro`
- Image Name: `amazonlinux2023-golden-image`

### Build with Custom Variables

```bash
packer build \
  -var="aws_region=us-east-1" \
  -var="vpc_id=vpc-12345678" \
  -var="subnet_id=subnet-12345678" \
  -var="iam_instance_profile=packer-image-role" \
  aws-golden-image.pkr.hcl
```

### Build with Security Groups

```bash
packer build \
  -var="aws_region=us-east-1" \
  -var="vpc_id=vpc-0c680556684d4feed" \
  -var="subnet_id=subnet-0a21c4c91cd05109e" \
  -var="security_group_ids=[\"sg-095ddb4568d73a1a1\"]" \
  -var="iam_instance_profile=packer-image-role" \
  aws-golden-image.pkr.hcl
```

## Available Variables

You can override these with `-var="key=value"`:

- `aws_region` - AWS region (default: `us-east-1`)
- `instance_type` - EC2 instance type (default: `t3.micro`)
- `image_name` - Base name for the AMI (default: `amazonlinux2023-golden-image`)
- `iam_instance_profile` - IAM instance profile name (optional)
- `vpc_id` - VPC ID (optional)
- `subnet_id` - Subnet ID (optional)
- `security_group_ids` - List of security group IDs (optional)

## Build Output

After successful build, you'll see:

```
==> Builds finished. The artifacts of the build are shown below.
--> amazon-ebs.amazonlinux2023: AMIs were created:
us-east-1: ami-0123456789abcdef0
```

Save the AMI ID to launch instances!

## Troubleshooting

### "Packer: command not found"
- Packer is not in PATH
- Check: `which packer`
- Add to PATH or reinstall (see `INSTALL-PACKER.md`)

### "AWS credentials not configured"
```bash
aws configure
# Or set environment variables
export AWS_ACCESS_KEY_ID=your-key
export AWS_SECRET_ACCESS_KEY=your-secret
```

### "session-manager-plugin not found"
- Required for SSM Session Manager connectivity
- Install in WSL2:
  ```bash
  curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm" -o /tmp/session-manager-plugin.rpm
  sudo yum install -y /tmp/session-manager-plugin.rpm  # For RHEL/CentOS
  # Or for Ubuntu/Debian, convert RPM to DEB or use alternative method
  ```

### Plugin initialization fails
```bash
# Clear Packer plugin cache
rm -rf ~/.packer.d/plugins
packer init aws-golden-image.pkr.hcl
```

### Permission errors accessing Windows files
- Ensure you're in `/mnt/c/...` path
- Check file permissions: `ls -la aws-golden-image.pkr.hcl`

## Complete Example

```bash
# 1. Install Packer (if not already installed)
PACKER_VERSION="1.10.0"
wget https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip
unzip packer_${PACKER_VERSION}_linux_amd64.zip
sudo mv packer /usr/local/bin/

# 2. Configure AWS
aws configure

# 3. Navigate to project
cd /mnt/c/Users/0B9947649/GHTest/packer

# 4. Initialize plugins
packer init aws-golden-image.pkr.hcl

# 5. Validate
packer validate aws-golden-image.pkr.hcl

# 6. Build
packer build aws-golden-image.pkr.hcl
```
