# Building Images Locally with Packer CLI (WSL Ubuntu)

This guide explains how to build the Ubuntu golden image locally using Packer CLI **without HCP Packer integration** on a **WSL Ubuntu** system.

## Prerequisites

1. **WSL Ubuntu** installed and running
   - Verify: `wsl --list` (from Windows PowerShell) or `cat /etc/os-release` (from WSL)
   - Ensure you're in your WSL Ubuntu environment

2. **Packer installed** (version 1.10.0 or later)
   
   **Installation on Ubuntu/WSL:**
   ```bash
   # Download Packer
   wget https://releases.hashicorp.com/packer/1.10.0/packer_1.10.0_linux_amd64.zip
   
   # Install unzip if not already installed
   sudo apt-get update && sudo apt-get install -y unzip
   
   # Unzip Packer
   unzip packer_1.10.0_linux_amd64.zip
   
   # Move to a directory in your PATH (e.g., /usr/local/bin)
   sudo mv packer /usr/local/bin/
   
   # Verify installation
   packer version
   ```
   
   **Alternative: Using HashiCorp's official repository:**
   ```bash
   # Install required packages
   sudo apt-get update && sudo apt-get install -y software-properties-common
   
   # Add HashiCorp GPG key
   curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
   
   # Add HashiCorp repository
   sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
   
   # Update and install Packer
   sudo apt-get update && sudo apt-get install -y packer
   
   # Verify installation
   packer version
   ```

3. **AWS Account** with appropriate permissions
   - IAM user or role with EC2/AMI permissions
   - AWS credentials configured locally

4. **AWS CLI configured** (recommended)
   
   **Installation on Ubuntu/WSL:**
   ```bash
   # Download AWS CLI installer
   curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
   
   # Install unzip if not already installed
   sudo apt-get update && sudo apt-get install -y unzip
   
   # Unzip and install
   unzip awscliv2.zip
   sudo ./aws/install
   
   # Verify installation
   aws --version
   ```
   
   **Alternative: Using apt (older version):**
   ```bash
   sudo apt-get update
   sudo apt-get install -y awscli
   aws --version
   ```
   
   **Configure AWS CLI:**
   ```bash
   aws configure
   ```

## Step 1: Configure AWS Credentials

You have two options for providing AWS credentials:

### Option A: AWS CLI (Recommended)

```bash
aws configure
```

Enter your:
- AWS Access Key ID
- AWS Secret Access Key
- Default region (e.g., `us-east-1`)
- Default output format (can leave as default)

### Option B: Environment Variables

Set environment variables in your WSL Ubuntu shell:

```bash
# Set AWS credentials (current session only)
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"

# Verify they're set
echo $AWS_ACCESS_KEY_ID
echo $AWS_DEFAULT_REGION
```

**To make environment variables persistent across sessions**, add them to your shell profile:

```bash
# For bash (default in Ubuntu)
echo 'export AWS_ACCESS_KEY_ID="your-access-key"' >> ~/.bashrc
echo 'export AWS_SECRET_ACCESS_KEY="your-secret-key"' >> ~/.bashrc
echo 'export AWS_DEFAULT_REGION="us-east-1"' >> ~/.bashrc

# Reload your shell configuration
source ~/.bashrc

# For zsh (if you're using zsh)
echo 'export AWS_ACCESS_KEY_ID="your-access-key"' >> ~/.zshrc
echo 'export AWS_SECRET_ACCESS_KEY="your-secret-key"' >> ~/.zshrc
echo 'export AWS_DEFAULT_REGION="us-east-1"' >> ~/.zshrc
source ~/.zshrc
```

**Note**: For better security, consider using AWS credentials file (`~/.aws/credentials`) instead of environment variables.

### Required AWS Permissions

Your AWS credentials need these permissions:
- `ec2:DescribeImages`
- `ec2:DescribeInstances`
- `ec2:RunInstances`
- `ec2:CreateImage`
- `ec2:CreateTags`
- `ec2:CreateSnapshot`
- `ec2:DescribeSnapshots`
- `ec2:DeleteSnapshot`
- `ec2:TerminateInstances`
- `ec2:DeregisterImage`
- `ec2:DescribeRegions`
- `ec2:DescribeAvailabilityZones`
- `ec2:CreateSecurityGroup`
- `ec2:DeleteSecurityGroup`
- `ec2:AuthorizeSecurityGroupIngress`
- `ec2:CreateKeyPair`
- `ec2:DeleteKeyPair`
- `ec2:DescribeKeyPairs`

## Step 2: Navigate to Project Directory

Ensure you're in the project directory in your WSL Ubuntu environment:

```bash
# If your project is in Windows filesystem (e.g., /mnt/c/Users/...)
cd /mnt/c/Users/0B9947649/GHTest/packer

# Or if you've cloned it to WSL filesystem (recommended for better performance)
# cd ~/packer

# Verify you're in the right directory
ls -la
# You should see: ubuntu-golden-image-local.pkr.hcl
```

**WSL Performance Note**: For better performance, consider cloning or copying your project to the WSL filesystem (`~/` or `/home/yourusername/`) rather than working directly from `/mnt/c/`. File I/O operations are faster on the native Linux filesystem.

## Step 3: Create Variables File (Optional)

If you want to override default values, create a variables file:

```bash
# Copy the example file
cp variables.local.pkrvars.hcl.example variables.local.pkrvars.hcl

# Edit with your preferred values using your preferred editor
nano variables.local.pkrvars.hcl
# or
vim variables.local.pkrvars.hcl
# or use VS Code: code variables.local.pkrvars.hcl
```

Edit `variables.local.pkrvars.hcl` with your values:
```hcl
aws_region     = "us-east-1"
ubuntu_version = "22.04"
instance_type  = "t3.micro"
image_name     = "ubuntu-golden-image"
```

## Step 4: Initialize Packer Plugins

Download required Packer plugins:

```bash
packer init ubuntu-golden-image-local.pkr.hcl
```

This will download the `amazon` plugin needed to build AWS AMIs. The plugins will be stored in `~/.config/packer/plugins/` or `~/.packer.d/plugins/`.

**Note**: If you encounter permission issues, ensure you have write access to your home directory:
```bash
ls -la ~/.config/packer/  # Check if directory exists and is writable
```

## Step 5: Validate the Template

Validate the Packer template before building:

```bash
# Without variables file (uses defaults)
packer validate ubuntu-golden-image-local.pkr.hcl

# With variables file
packer validate -var-file=variables.local.pkrvars.hcl ubuntu-golden-image-local.pkr.hcl
```

If validation passes, you'll see:
```
The configuration is valid.
```

## Step 6: Build the Image

Build the AMI:

```bash
# Without variables file (uses defaults)
packer build ubuntu-golden-image-local.pkr.hcl

# With variables file
packer build -var-file=variables.local.pkrvars.hcl ubuntu-golden-image-local.pkr.hcl

# Override specific variables on command line
packer build \
  -var 'aws_region=us-west-2' \
  -var 'image_name=my-custom-image' \
  ubuntu-golden-image-local.pkr.hcl
```

**WSL Networking Note**: Packer will create temporary security groups and SSH connections. Ensure your WSL network configuration allows outbound connections. If you're behind a corporate firewall, you may need to configure proxy settings.

### Build Process

The build will:
1. **Launch EC2 instance** (t3.micro by default)
2. **Wait for SSH** to become available
3. **Provision the instance**:
   - Update system packages
   - Install common utilities (curl, wget, git, unzip, AWS CLI, etc.)
   - Harden SSH configuration
   - Clean up temporary files
4. **Create AMI snapshot**
5. **Register AMI** in AWS
6. **Terminate build instance**

### Build Duration

- **Provisioning**: ~5-10 minutes (depends on package updates)
- **AMI Creation**: ~2-5 minutes (snapshot creation)
- **Total**: Approximately 8-15 minutes

## Step 7: Verify the Build

### Check Build Output

At the end of a successful build, you'll see:
```
==> Builds finished. The artifacts of successful builds are:
--> amazon-ebs.ubuntu: AMIs were created:
us-east-1: ami-xxxxxxxxxxxxxxxxx
```

### Find Your AMI in AWS Console

1. Go to **EC2** → **AMIs**
2. Filter by:
   - **Name**: `ubuntu-golden-image-*`
   - **Owner**: Your AWS account ID
3. The AMI will show:
   - **Status**: `available` (after snapshot completes)
   - **Name**: `ubuntu-golden-image-YYYY-MM-DD-HHMM`
   - **Creation Date**: When the build completed

## Using the AMI

### Launch EC2 Instance

1. Go to **EC2** → **Launch Instance**
2. Select **"My AMIs"** tab
3. Choose your `ubuntu-golden-image-*` AMI
4. Configure instance settings
5. Launch

### Use with Terraform

```hcl
# Using AWS AMI directly
data "aws_ami" "ubuntu_golden" {
  most_recent = true
  owners      = ["self"]  # Your AWS account ID
  
  filter {
    name   = "name"
    values = ["ubuntu-golden-image-*"]
  }
}

resource "aws_instance" "example" {
  ami           = data.aws_ami.ubuntu_golden.id
  instance_type = "t3.micro"
}
```

## Troubleshooting

### Build Fails: "Access Denied"

**Cause**: AWS credentials don't have required permissions

**Solution**:
1. Verify your AWS credentials are correct
2. Check IAM user/role has required EC2 permissions
3. Test with: `aws ec2 describe-images --owners self`

### Build Fails: "AMI Not Found"

**Cause**: Source AMI doesn't exist in target region

**Solution**:
1. Verify Ubuntu 22.04 AMI exists in your target region
2. Check AMI filter in template matches available AMIs
3. Try a different region

### Build Fails: "Plugin Not Found"

**Cause**: Packer plugins not initialized

**Solution**:
```bash
packer init ubuntu-golden-image-local.pkr.hcl
```

### Build Fails: "SSH Connection Timeout"

**Cause**: Security group blocking SSH or instance not ready

**Solution**:
1. Packer creates temporary security groups automatically
2. Check your AWS account limits for security groups
3. Ensure default VPC exists in your region
4. Verify network connectivity from WSL
5. **WSL-specific**: If you're behind a VPN or firewall, ensure WSL can make outbound connections:
   ```bash
   # Test connectivity
   curl -I https://ec2.us-east-1.amazonaws.com
   # Test SSH connectivity (if you have an existing EC2 instance)
   ssh -v user@your-ec2-instance
   ```
6. Check Windows Firewall isn't blocking WSL network access

### AMI Stuck in "Pending"

**Cause**: Snapshot still being created

**Solution**:
1. **Normal**: AMIs can take 10-30 minutes to become available
2. Check snapshot status in EC2 → Snapshots
3. Wait for snapshot to complete
4. If stuck >30 minutes, check AWS Service Health Dashboard

## Differences from HCP Packer Version

The local version (`ubuntu-golden-image-local.pkr.hcl`) differs from the HCP version:

- ✅ **No HCP Packer integration** - AMI is created but not published to HCP
- ✅ **No HCP variables required** - Simpler configuration
- ✅ **Faster setup** - No HCP account needed
- ❌ **No version tracking** - No centralized metadata management
- ❌ **No HCP channels** - Can't use HCP Packer data sources in Terraform

## Customization

### Modify Image Contents

Edit `ubuntu-golden-image-local.pkr.hcl`:

```hcl
# Add packages in the provisioning section
provisioner "shell" {
  inline = [
    "sudo apt-get install -y your-package-name"
  ]
}
```

### Change Build Parameters

Override variables:
```bash
packer build \
  -var 'instance_type=t3.small' \
  -var 'aws_region=us-west-2' \
  -var 'image_name=my-custom-image' \
  ubuntu-golden-image-local.pkr.hcl
```

### Add Custom Provisioning

Add new provisioner blocks in the `build` section:

```hcl
provisioner "shell" {
  script = "path/to/your/script.sh"
}
```

## Quick Reference

```bash
# Initialize plugins
packer init ubuntu-golden-image-local.pkr.hcl

# Validate template
packer validate ubuntu-golden-image-local.pkr.hcl

# Build image
packer build ubuntu-golden-image-local.pkr.hcl

# Build with custom variables
packer build -var-file=variables.local.pkrvars.hcl ubuntu-golden-image-local.pkr.hcl

# Build with inline variables
packer build -var 'aws_region=us-west-2' -var 'image_name=my-image' ubuntu-golden-image-local.pkr.hcl
```

## WSL-Specific Considerations

### File Permissions

When working with files in WSL:
- Files created in WSL have Linux permissions
- Files created in Windows (`/mnt/c/`) may have different permissions
- Use `chmod` to adjust permissions if needed:
  ```bash
  chmod 600 variables.local.pkrvars.hcl  # Make variables file readable only by owner
  ```

### Path Handling

- Use forward slashes (`/`) in paths, even when accessing Windows filesystem
- Example: `/mnt/c/Users/YourName/path/to/file`
- Avoid spaces in paths or escape them properly

### Performance Tips

1. **Work in WSL filesystem**: Copy project to `~/packer` for better performance
2. **Use native Linux tools**: Prefer `nano`/`vim` over Windows editors for quick edits
3. **SSH keys**: Store SSH keys in `~/.ssh/` (WSL filesystem) for better performance

### Environment Variables Persistence

To ensure environment variables persist across WSL sessions:

```bash
# Add to ~/.bashrc or ~/.zshrc
echo 'export AWS_DEFAULT_REGION="us-east-1"' >> ~/.bashrc
source ~/.bashrc
```

### VS Code Integration

If using VS Code with WSL:
- Install "Remote - WSL" extension
- Open folder from WSL: `code ~/packer`
- Terminal will use WSL Ubuntu by default

## Security Best Practices

1. **Never commit credentials** - Use `.gitignore` for variables files
   ```bash
   # Ensure variables.local.pkrvars.hcl is in .gitignore
   echo "variables.local.pkrvars.hcl" >> .gitignore
   ```
2. **Use IAM roles** when possible instead of access keys
3. **Rotate credentials** regularly
4. **Use least privilege** - Grant minimum required permissions
5. **Review AMI contents** - Ensure no sensitive data in images
6. **Secure credential storage**: Use `~/.aws/credentials` with proper permissions:
   ```bash
   chmod 600 ~/.aws/credentials
   chmod 600 ~/.aws/config
   ```





