# Golden Image Builder with Packer

This repository automates the creation of hardened golden images (AMIs) on AWS using Packer and GitHub Actions for CI/CD. Supports both **Ubuntu 22.04 LTS** and **Amazon Linux 2023**. All builds run automatically through GitHub Actions - no local setup required. The project includes CIS benchmark hardening, automated validation, and multi-region AMI distribution.

## Overview

This project provides a fully automated pipeline for building golden images:

- **Packer**: Infrastructure as Code tool for creating machine images
- **AWS**: Cloud platform for building and storing AMIs
- **GitHub Actions**: CI/CD pipeline that handles all builds automatically
- **Multi-OS Support**: Ubuntu 22.04 LTS and Amazon Linux 2023

### Key Features

- ✅ **Fully Automated**: All builds run through GitHub Actions - no local setup needed
- ✅ **Multi-OS Support**: Ubuntu 22.04 LTS and Amazon Linux 2023
- ✅ **Secure Authentication**: Uses AWS OIDC (Ubuntu) or AWS credentials (Amazon Linux 2023)
- ✅ **CIS Hardening**: Automated CIS Level 2 benchmark compliance (validated during build)
- ✅ **Encrypted AMIs**: All AMIs are encrypted by default
- ✅ **Tagged Resources**: AMIs and snapshots are automatically tagged
- ✅ **Post-Build Validation**: Automated AMI validation with functional and security tests
- ✅ **Multi-Region Distribution**: Automatically copies AMIs to target regions
- ✅ **Parameter Store Integration**: Stores AMI IDs in Systems Manager for easy lookup
- ✅ **VPC Support**: Amazon Linux 2023 builds support VPC/private subnet with SSM Session Manager

## Architecture & Workflow

### Build Process Flow

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Trigger Build                                            │
│    - Push to main branch                                    │
│    - Manual workflow dispatch                               │
│    - Pull request (validation only)                         │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. GitHub Actions: Validate Job                            │
│    - Checkout code                                          │
│    - Setup Packer 1.10.0                                    │
│    - Configure AWS credentials (OIDC)                       │
│    - Initialize Packer plugins                              │
│    - Validate template syntax                               │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼ (if validation passes)
┌─────────────────────────────────────────────────────────────┐
│ 3. GitHub Actions: Build Job                                │
│    - Checkout code                                          │
│    - Setup Packer 1.10.0                                    │
│    - Configure AWS credentials (OIDC)                       │
│    - Initialize Packer plugins                              │
│    - Run packer build                                       │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. Packer Build Process                                     │
│    a) Launch EC2 instance (t3.micro)                        │
│       - Ubuntu: Public subnet with SSH                      │
│       - Amazon Linux 2023: Private subnet with SSM         │
│    b) Wait for connectivity (SSH or SSM)                    │
│    c) Provision instance:                                   │
│       - Update system packages                              │
│       - Install common utilities                            │
│       - Install AWS CLI v2                                  │
│       - Install Ansible                                     │
│       - Apply CIS benchmark hardening (via Ansible)         │
│       - Run CIS compliance check (validates hardening)       │
│       - Harden SSH configuration                            │
│       - Clean up temporary files                            │
│    d) Create AMI snapshot                                   │
│    e) Register AMI in AWS                                   │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ 5. Post-Build Validation                                    │
│    - Launch test instance from AMI                          │
│    - Run functional tests (SSH/SSM, services, network)     │
│    - Run security tests (passwords, file permissions)        │
│    Note: CIS compliance is validated during build, not here│
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ 6. AMI Distribution (Optional)                             │
│    - Copy AMI to target regions                            │
│    - Store AMI IDs in Parameter Store                      │
│    - Tag copied AMIs                                        │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ 7. Output                                                   │
│    - AMI available in AWS EC2                               │
│    - AMI ID displayed in build output                       │
│    - Ready to use for launching instances                   │
└─────────────────────────────────────────────────────────────┘
```

### Workflow Triggers

The project includes separate workflows for each OS:

**Ubuntu Workflow** (`.github/workflows/build-image.yml`):
- Triggers on push to `main` branch
- Manual workflow dispatch
- Pull request validation

**Amazon Linux 2023 Workflow** (`.github/workflows/build-amazonlinux2023.yml`):
- Triggers on push to `amazonlinux2023-vpc-private-subnet` branch
- Manual workflow dispatch
- Pull request validation
- Requires VPC configuration (VPC ID, subnet ID, IAM instance profile)

Both workflows:
1. **Validate** the Packer template syntax
2. **Build** the AMI with CIS hardening
3. **Validate** the AMI with functional and security tests
4. **Distribute** AMIs to target regions (optional)
5. **Store** AMI IDs in Parameter Store (optional)

## Prerequisites

Before setting up this repository, ensure you have:

### 1. AWS Account Setup

- **AWS Account** with appropriate permissions
- **IAM Permissions** to create:
  - EC2 instances
  - AMIs
  - Snapshots
  - Security groups
  - Key pairs (temporary)
- **OIDC Identity Provider** configured (see setup below)

### 2. GitHub Repository

- **Repository** with GitHub Actions enabled
- **Access** to configure secrets and workflows

## Detailed Setup Instructions

### Step 1: Clone the Repository

```bash
git clone https://github.com/your-username/packer.git
cd packer
```

### Step 2: Configure AWS Authentication

**For Ubuntu Builds:**
This project uses AWS OIDC (OpenID Connect) for secure authentication between GitHub Actions and AWS. This eliminates the need to store AWS access keys as secrets.

**📖 For detailed step-by-step instructions, see [AWS OIDC Setup Guide](docs/AWS-OIDC-SETUP.md)**

**Quick Summary:**
1. Create OIDC Identity Provider in AWS IAM (`https://token.actions.githubusercontent.com`)
2. Create IAM Role with trust policy allowing your GitHub repository
3. Attach permissions policy with required EC2 and SSM permissions
4. Add `AWS_ROLE_ARN` secret to GitHub repository

**For Amazon Linux 2023 Builds:**
Uses AWS credentials from GitHub Secrets (for VPC/private subnet builds).

**📖 For detailed setup, see [Amazon Linux 2023 VPC Setup Guide](docs/AMAZONLINUX2023-VPC-SETUP.md)**

**Quick Summary:**
1. Configure VPC endpoints (SSM, S3, EC2) for private subnet access
2. Create IAM instance profile with `AmazonSSMManagedInstanceCore` policy
3. Add GitHub Secrets: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN` (optional)
4. Add GitHub Variables: `VPC_ID`, `SUBNET_ID`, `IAM_INSTANCE_PROFILE`, `SECURITY_GROUP_IDS`

**Required IAM Permissions:**
- EC2: Run instances, create images, manage snapshots, security groups
- SSM Parameter Store: Put/get parameters for AMI ID storage
- See [AWS-OIDC-SETUP.md](docs/AWS-OIDC-SETUP.md#required-iam-permissions) for complete permissions list

### Step 3: Configure Build Settings (Optional)

Edit `config/build-config.yml` to customize:
- Default AWS region and OS version
- Instance types for build and validation
- CIS compliance thresholds
- Target regions for AMI distribution
- Parameter Store settings
- VPC configuration (for Amazon Linux 2023)

See [Configuration Guide](config/README.md) for details.

**For Amazon Linux 2023**, also configure:
- VPC ID, subnet ID, security group IDs
- IAM instance profile name
- See [AMAZONLINUX2023-VPC-SETUP.md](docs/AMAZONLINUX2023-VPC-SETUP.md) for details

### Step 4: Verify Setup

1. **Check GitHub Secrets**: Ensure `AWS_ROLE_ARN` secret is configured
2. **Check AWS Role**: Verify the IAM role exists and has correct permissions
3. **Verify Workflow File**: Ensure `.github/workflows/build-image.yml` exists
4. **Test Build**: Run a manual workflow dispatch to verify everything works

## Usage

### Triggering a Build

#### Method 1: Manual Trigger (Recommended for First Build)

**For Ubuntu:**
1. Go to your GitHub repository
2. Click on the **Actions** tab
3. Select **"Build Ubuntu Golden Image"** workflow from the left sidebar
4. Click **"Run workflow"** button (top right)
5. Configure options:
   - **Ubuntu version**: Choose `22.04` (default) or `20.04`
   - **AWS region**: Enter region (default: `us-east-1`)
6. Click **"Run workflow"**

**For Amazon Linux 2023:**
1. Go to your GitHub repository
2. Click on the **Actions** tab
3. Select **"Build Amazon Linux 2023 Golden Image Hardened"** workflow
4. Click **"Run workflow"** button (top right)
5. Configure options:
   - **AWS region**: Enter region (default: `us-east-1`)
   - **Target regions**: Comma-separated list (optional)
   - **Store in Parameter Store**: true/false (default: true)
6. Click **"Run workflow"**

Note: VPC configuration is sourced from GitHub Variables/Secrets (see Step 2)

#### Method 2: Automatic Trigger (Push to Branch)

**For Ubuntu:**
1. Make changes to Packer template files (`.pkr.hcl`) or workflow files
2. Commit and push to `main` branch:
   ```bash
   git add .
   git commit -m "Update Packer template"
   git push origin main
   ```
3. The workflow will automatically:
   - Validate the template
   - Build the AMI (if validation passes)

**For Amazon Linux 2023:**
1. Make changes to Packer template files or workflow files
2. Commit and push to `amazonlinux2023-vpc-private-subnet` branch:
   ```bash
   git add .
   git commit -m "Update Amazon Linux template"
   git push origin amazonlinux2023-vpc-private-subnet
   ```
3. The workflow will automatically:
   - Validate the template
   - Build the AMI (if validation passes)

#### Method 3: Pull Request (Validation Only)

1. Create a feature branch
2. Make changes
3. Create a pull request to `main`
4. The workflow will validate the template (no build)

### Monitoring Build Progress

#### In GitHub Actions

1. Go to **Actions** tab
2. Click on the running workflow
3. Expand the **"Validate Packer Template"** job to see validation progress
4. Expand the **"Build AMI"** job to see:
   - Packer initialization
   - AWS credential configuration
   - Build progress:
     - Instance launch
     - SSH connection
     - Provisioning steps
     - AMI creation

#### What to Look For

**Successful Build:**
- ✅ All steps show green checkmarks
- ✅ "Build AMI" job completes successfully
- ✅ "Validate AMI" job completes successfully
- ✅ Final step shows "AMI build completed successfully!"
- ✅ Build output displays the AMI ID:
  ```
  ==> Builds finished. The artifacts of successful builds are:
  --> amazon-ebs.ubuntu: AMIs were created:
  us-east-1: ami-xxxxxxxxxxxxxxxxx
  
  OR
  
  --> amazon-ebs.amazonlinux2023: AMIs were created:
  us-east-1: ami-xxxxxxxxxxxxxxxxx
  ```

**Failed Build:**
- ❌ Red X on failed step
- Click on the failed step to see error details
- Common issues:
  - AWS permissions
  - Template syntax errors
  - Package installation failures
  - Network connectivity issues

### Build Duration

- **Validation**: ~30 seconds
- **Build**: ~5-10 minutes (depends on package updates)
- **AMI Creation**: ~2-5 minutes (snapshot creation)

**Total**: Approximately 8-15 minutes

### Finding Your AMI

#### In AWS Console

1. Go to **EC2** → **AMIs**
2. Filter by:
   - **Name**: 
     - `ubuntu-golden-image-*` (for Ubuntu)
     - `amazonlinux2023-golden-image-*` (for Amazon Linux 2023)
   - **Owner**: Your AWS account ID
3. The AMI will show:
   - **Status**: `available` (after snapshot completes)
   - **Name**: `{os}-golden-image-YYYY-MM-DD-HHMM`
   - **Creation Date**: When the build completed
   - **AMI ID**: e.g., `ami-xxxxxxxxxxxxxxxxx`

#### From Build Output

The AMI ID is displayed at the end of a successful build in the GitHub Actions logs:

```
==> Builds finished. The artifacts of successful builds are:
--> amazon-ebs.ubuntu: AMIs were created:
us-east-1: ami-xxxxxxxxxxxxxxxxx

OR

--> amazon-ebs.amazonlinux2023: AMIs were created:
us-east-1: ami-xxxxxxxxxxxxxxxxx
```

Copy the AMI ID from the build output for immediate use.

### Using the AMI

#### Launch EC2 Instance

1. Go to **EC2** → **Launch Instance**
2. Select **"My AMIs"** tab
3. Choose your `ubuntu-golden-image-*` AMI
4. Configure instance settings
5. Launch

#### Use with Terraform

```hcl
# Using AWS AMI directly (Ubuntu)
data "aws_ami" "ubuntu_golden" {
  most_recent = true
  owners      = ["self"]  # Your AWS account ID
  
  filter {
    name   = "name"
    values = ["ubuntu-golden-image-*"]
  }
}

# Using AWS AMI directly (Amazon Linux 2023)
data "aws_ami" "amazonlinux2023_golden" {
  most_recent = true
  owners      = ["self"]  # Your AWS account ID
  
  filter {
    name   = "name"
    values = ["amazonlinux2023-golden-image-*"]
  }
}

resource "aws_instance" "example" {
  ami           = data.aws_ami.ubuntu_golden.id  # or amazonlinux2023_golden.id
  instance_type = "t3.micro"
}
```

#### Use AMI ID Directly

If you know the AMI ID from the build output:

```hcl
resource "aws_instance" "example" {
  ami           = "ami-xxxxxxxxxxxxxxxxx"  # Replace with your AMI ID
  instance_type = "t3.micro"
}
```

#### Use AMI from Parameter Store (Multi-Region)

AMIs are automatically stored in AWS Systems Manager Parameter Store for easy cross-region access:

```hcl
# Get latest AMI ID from Parameter Store (Ubuntu)
data "aws_ssm_parameter" "ami_us_west_2" {
  name = "/packer/ubuntu-golden-image/us-west-2/latest"
}

# Get latest AMI ID from Parameter Store (Amazon Linux 2023)
data "aws_ssm_parameter" "ami_al2023_us_west_2" {
  name = "/packer/amazonlinux2023-golden-image/us-west-2/latest"
}

resource "aws_instance" "example" {
  ami           = data.aws_ssm_parameter.ami_us_west_2.value  # or ami_al2023_us_west_2.value
  instance_type = "t3.micro"
}
```

See [AMI-DISTRIBUTION.md](docs/AMI-DISTRIBUTION.md) for detailed information about multi-region distribution.

## Workflow Details

### Validate Job

**Purpose**: Check template syntax before building

**Steps**:
1. **Checkout code**: Gets the latest code from repository
2. **Setup Packer**: Installs Packer 1.10.0
3. **Configure AWS Credentials (OIDC)**: Authenticates with AWS using the IAM role
4. **Initialize Packer**: Downloads required plugins (amazon plugin)
5. **Validate Packer template**: Checks syntax and required variables

**Duration**: ~30 seconds

**Failure Points**:
- Template syntax errors
- Missing required variables
- Plugin download failures

### Build Job

**Purpose**: Create the actual AMI

**Steps**:
1. **Checkout code**: Gets the latest code
2. **Setup Packer**: Installs Packer 1.10.0
3. **Configure AWS Credentials (OIDC)**: Authenticates with AWS
4. **Initialize Packer**: Downloads plugins
5. **Build Packer image**: 
   - Launches EC2 instance
   - Provisions the instance
   - Creates AMI snapshot
   - Registers AMI in AWS

**Duration**: ~8-15 minutes

**Failure Points**:
- AWS permissions issues
- Provisioning script errors
- Network connectivity issues
- Package installation failures

### Environment Variables

**Ubuntu Workflow** sets these environment variables:
- `PKR_VAR_aws_region`: AWS region (default: `us-east-1`)
- `PKR_VAR_ubuntu_version`: Ubuntu version (default: `22.04`)

**Amazon Linux 2023 Workflow** sets these environment variables:
- `PKR_VAR_aws_region`: AWS region (default: `us-east-1`)
- `PKR_VAR_vpc_id`: VPC ID (from GitHub Variables/Secrets)
- `PKR_VAR_subnet_id`: Subnet ID (from GitHub Variables/Secrets)
- `PKR_VAR_iam_instance_profile`: IAM instance profile name (from GitHub Variables/Secrets)
- `SECURITY_GROUP_IDS`: Security group IDs (from GitHub Variables/Secrets)
- `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`: AWS credentials (from GitHub Secrets)

These are passed to Packer as variables during the build.

## Image Contents

The golden images include:

### System Updates
- **Ubuntu**: Latest Ubuntu LTS security updates
- **Amazon Linux 2023**: Latest Amazon Linux 2023 security updates
- System packages upgraded to latest versions

### Installed Packages
- **Utilities**: curl, wget, git, unzip
- **AWS Tools**: AWS CLI v2 (installed via official installer)
- **Monitoring**: htop, net-tools
- **Optional**: jq (if dependencies available)

### Security Hardening
- SSH root login disabled
- Password authentication disabled
- SSH configuration hardened
- **CIS Level 2 Benchmark compliance**:
  - Ubuntu: CIS Ubuntu 22.04 LTS Benchmark
  - Amazon Linux 2023: CIS Amazon Linux 2023 Benchmark
  - See CIS Benchmarking section below

### CIS Benchmarking
The images include automated CIS (Center for Internet Security) benchmark hardening at **Level 2** (includes all Level 1 controls plus additional hardening):

**Supported OS:**
- **Ubuntu**: CIS Ubuntu 22.04 LTS Benchmark
- **Amazon Linux 2023**: CIS Amazon Linux 2023 Benchmark

**Level 1 Controls:**
- **Filesystem Configuration**: Disables unnecessary filesystem types (cramfs, squashfs, udf)
- **Process Hardening**: Core dumps restricted, ASLR enabled
- **Mandatory Access Control**: 
  - Ubuntu: AppArmor installed and configured
  - Amazon Linux 2023: SELinux installed and configured
- **Network Security**: IP forwarding disabled, SYN cookies enabled, packet redirects disabled
- **System File Permissions**: Proper permissions on critical system files (/etc/passwd, /etc/shadow, etc.)
- **Service Hardening**: Unnecessary services removed (xinetd, NIS, rsh, telnet, etc.)
- **Logging**: rsyslog configured and enabled
- **Time Synchronization**: chrony configured for accurate timekeeping
- **Warning Banners**: Login banners configured

**Level 2 Additional Controls:**
- **Enhanced Filesystem Restrictions**: Additional filesystem types disabled (freevxfs, jffs2, hfs, hfsplus)
- **Advanced Process Hardening**: Kernel dmesg restrictions, unprivileged BPF disabled
- **Enhanced Network Security**: Additional network hardening parameters, IPv6 restrictions
- **Strict SSH Configuration**: Protocol 2 only, approved ciphers/MACs/KEX algorithms, connection timeouts
- **Password Policies**: Password expiration, minimum days, warning periods configured
- **Enhanced Logging**: Journald forwarding, persistent storage, remote logging support
- **Cron Security**: Restricted cron access, proper permissions on cron directories
- **Additional Service Removals**: More services removed (RPC, Avahi, CUPS, DHCP, DNS, FTP, HTTP, Samba, etc.)

**Important**: CIS compliance is validated **during the build process** (not in post-build validation). The compliance check runs immediately after hardening is applied and can be configured to fail the build if compliance is below threshold. Post-build validation focuses on functional and security tests only.

### Cleanup
- Cloud-init logs cleared
- Temporary files removed
- System cache cleaned

## CIS Benchmarking

### Overview

This project includes automated CIS (Center for Internet Security) benchmark hardening for both Ubuntu 22.04 LTS and Amazon Linux 2023. The CIS benchmarks provide a set of security configuration guidelines to help organizations secure their systems.

### Implementation

The CIS hardening is implemented using **Ansible playbooks** for better maintainability and idempotency:

1. **`ansible/cis-hardening-playbook.yml`**: Applies CIS benchmark recommendations during image build (supports both Ubuntu and Amazon Linux 2023)
2. **`ansible/cis-compliance-check.yml`**: Performs compliance checks and generates an audit report (runs during build, not in validation)

**Why Ansible?**
- ✅ **Idempotent**: Safe to run multiple times
- ✅ **Maintainable**: Structured playbooks, easier to read and modify
- ✅ **Flexible**: Easy to customize which CIS sections to apply
- ✅ **Better reporting**: Structured compliance reports
- ✅ **Reusable**: Can leverage community CIS roles from Ansible Galaxy

### What Gets Hardened

The hardening playbook implements **CIS Level 2** recommendations (includes all Level 1 plus additional controls) for both Ubuntu and Amazon Linux 2023:

**Level 1 Controls:**
- **Filesystem Security**: Disables unnecessary filesystem types (cramfs, squashfs, udf)
- **Process Hardening**: Restricts core dumps, enables ASLR
- **Network Security**: Configures secure network parameters (IP forwarding disabled, SYN cookies enabled)
- **Access Control**: 
  - Ubuntu: Sets up AppArmor mandatory access control
  - Amazon Linux 2023: Sets up SELinux mandatory access control
- **System Permissions**: Ensures proper file permissions on critical system files
- **Service Management**: Removes unnecessary and insecure services
- **Logging**: Configures system logging (rsyslog)
- **Time Synchronization**: Sets up accurate timekeeping (chrony)

**Level 2 Additional Controls:**
- **Enhanced Filesystem Security**: Additional filesystem types disabled (freevxfs, jffs2, hfs, hfsplus)
- **Advanced Process Hardening**: Kernel dmesg restrictions, unprivileged BPF disabled
- **Enhanced Network Security**: Additional network hardening, IPv6 restrictions, log martians
- **Strict SSH Configuration**: Protocol 2 only, approved ciphers/MACs/KEX algorithms, connection timeouts, MaxAuthTries
- **Password Policies**: Password expiration (365 days), minimum days (7), warning periods
- **Enhanced Logging**: Journald forwarding, persistent storage, remote logging support
- **Cron Security**: Restricted cron access, proper permissions on cron directories
- **Comprehensive Service Removal**: Removes additional services (RPC, Avahi, CUPS, DHCP, DNS, FTP, HTTP, Samba, SNMP, etc.)

### CIS Compliance Validation

**During Build Process:**
The CIS compliance check (`cis-compliance-check.yml`) runs automatically **during the build** immediately after hardening is applied. This ensures:
- Hardening was applied correctly
- Compliance threshold is met before AMI creation
- Build can fail if compliance is below threshold (configurable)

**Post-Build Validation:**
The AMI validation playbook (`ami-validation-playbook.yml`) focuses on:
- **Functional Tests**: SSH/SSM connectivity, services, network, utilities, disk space
- **Security Tests**: Default passwords, critical file permissions

**Note**: CIS compliance is **not** re-checked in post-build validation since it's already validated during build. This separation ensures:
- Build = hardening + compliance validation
- Validation = functional + security verification

### Customizing CIS Hardening

To modify the CIS hardening:

1. Edit `ansible/cis-hardening-playbook.yml` to add or remove hardening tasks (supports both Ubuntu and Amazon Linux 2023)
2. Edit `ansible/cis-compliance-check.yml` to add or modify compliance checks
3. Adjust variables in the Packer template:
   - `cis_level`: Set to 1 (Level 1) or 2 (Level 2)
   - `cis_compliance_threshold`: Minimum compliance percentage (default: 80)
   - `fail_on_non_compliance`: Set to `true` to fail build on non-compliance

**Example (Ubuntu):**
```hcl
packer build \
  -var 'cis_level=2' \
  -var 'cis_compliance_threshold=90' \
  -var 'fail_on_non_compliance=true' \
  ubuntu-golden-image.pkr.hcl
```

**Example (Amazon Linux 2023):**
```hcl
packer build \
  -var 'cis_level=2' \
  -var 'cis_compliance_threshold=90' \
  -var 'fail_on_non_compliance=true' \
  -var 'vpc_id=vpc-xxxxx' \
  -var 'subnet_id=subnet-xxxxx' \
  -var 'iam_instance_profile=your-profile' \
  amazonlinux2023-golden-image.pkr.hcl
```

### Using Community CIS Roles

You can also use community-maintained CIS roles from Ansible Galaxy. Update `ansible/requirements.yml`:

```yaml
roles:
  - name: devsec.cis_ubuntu_22_04
    src: https://github.com/dev-sec/cis-ubuntu-22.04-ansible
```

Then include the role in your playbook instead of manual tasks.

### Disabling CIS Hardening

If you need to disable CIS hardening:

1. Comment out or remove the CIS provisioning blocks in the Packer template:
   - `ubuntu-golden-image.pkr.hcl` (for Ubuntu)
   - `amazonlinux2023-golden-image.pkr.hcl` (for Amazon Linux 2023)
   
   ```hcl
   # Provisioning: CIS Benchmark Hardening
   # (comment out or remove these provisioner blocks)
   ```

2. Rebuild the image

### CIS Benchmark Documentation

For detailed information about CIS benchmarks, see:
- [CIS Benchmarks](https://www.cisecurity.org/cis-benchmarks/)
- [CIS Ubuntu 22.04 LTS Benchmark](https://www.cisecurity.org/benchmark/ubuntu_linux)
- [CIS Amazon Linux 2023 Benchmark](https://www.cisecurity.org/benchmark/amazon_linux)

## Customization

### Modify Image Contents

**For Ubuntu**, edit `ubuntu-golden-image.pkr.hcl`:

```hcl
# Add packages in the provisioning section
provisioner "shell" {
  inline = [
    "sudo apt-get install -y your-package-name"
  ]
}
```

**For Amazon Linux 2023**, edit `amazonlinux2023-golden-image.pkr.hcl`:

```hcl
# Add packages in the provisioning section
provisioner "shell" {
  inline = [
    "sudo dnf install -y your-package-name"
  ]
}
```

### Change Build Parameters

Modify workflow inputs or environment variables:

- **Region**: Change `PKR_VAR_aws_region` in workflow
- **Instance Type**: Modify `instance_type` variable in template
- **Ubuntu Version**: Change `PKR_VAR_ubuntu_version` (note: AMI filter is currently hardcoded to 22.04)
- **VPC Configuration** (Amazon Linux 2023): Update GitHub Variables/Secrets for VPC ID, subnet ID, IAM instance profile

### Add Custom Provisioning

Add new provisioner blocks in the `build` section:

```hcl
provisioner "shell" {
  script = "path/to/your/script.sh"
}
```

## Troubleshooting

### Build Fails: "Access Denied"

**Cause**: IAM role doesn't have required permissions

**Solution**:
1. Check IAM role permissions
2. Verify role ARN in GitHub Secrets
3. Ensure OIDC identity provider is configured correctly
4. Check role trust policy includes your repository

### Build Fails: "AMI Not Found"

**Cause**: Source AMI doesn't exist in target region

**Solution**:
1. Verify Ubuntu 22.04 AMI exists in your target region
2. Check AMI filter in template matches available AMIs
3. Try a different region

### Build Fails: "Package Installation Error"

**Cause**: Package dependency issues or network problems

**Solution**:
1. Check provisioning logs in GitHub Actions
2. Verify package names are correct
3. Check if packages are available in Ubuntu repositories
4. Review error messages for specific package issues

### Build Fails: "AWS CLI Installation Error"

**Cause**: Network issues downloading AWS CLI installer

**Solution**:
1. Check network connectivity in build logs
2. Verify the AWS CLI download URL is accessible
3. Check if unzip is installed (required for AWS CLI installation)
4. Review error messages for specific download issues

### AMI Stuck in "Pending"

**Cause**: Snapshot still being created

**Solution**:
1. **Normal**: AMIs can take 10-30 minutes to become available
2. Check snapshot status in EC2 → Snapshots
3. Wait for snapshot to complete
4. If stuck >30 minutes, check AWS Service Health Dashboard

### Workflow Doesn't Trigger

**Cause**: Workflow file issues or branch name

**Solution**:
1. Verify workflow file is in `.github/workflows/` directory
2. Check workflow triggers match your actions
3. Ensure you're pushing to `main` branch (or configured branch)
4. Check file paths in workflow match your repository structure

## Security Best Practices

1. **OIDC Authentication**: Always use OIDC instead of access keys
2. **Least Privilege**: IAM role should have minimum required permissions
3. **Secrets Management**: Never commit secrets to repository
4. **Role Conditions**: Use OIDC conditions to restrict which repositories can assume the role
5. **Regular Updates**: Keep Packer and plugins updated
6. **Image Hardening**: Review and customize provisioning scripts
7. **Encryption**: AMIs are encrypted by default
8. **AMI Lifecycle**: Implement a process to track and manage AMI versions

## Project Structure

```
packer/
├── .github/
│   └── workflows/
│       ├── build-image.yml                    # Ubuntu CI/CD workflow
│       └── build-amazonlinux2023.yml          # Amazon Linux 2023 CI/CD workflow
├── .gitignore                                  # Git ignore rules
├── README.md                                   # Main project documentation
├── README-AMAZONLINUX2023.md                  # Amazon Linux 2023 quick start
├── docs/                                       # Documentation
│   ├── AMAZONLINUX2023-VPC-SETUP.md           # Amazon Linux 2023 VPC setup
│   ├── AMI-DISTRIBUTION.md                     # AMI distribution guide
│   ├── AWS-OIDC-SETUP.md                       # AWS OIDC setup (Ubuntu)
│   ├── CIS-IMPLEMENTATION-COMPARISON.md        # CIS implementation comparison
│   ├── GITHUB-SECRETS-SETUP.md                 # GitHub secrets setup
│   ├── PIPELINE-TIMING.md                      # Pipeline timing documentation
│   └── VALIDATION.md                           # Validation documentation
├── ansible/                                    # Ansible playbooks and tasks
│   ├── cis-hardening-playbook.yml              # CIS hardening (multi-OS)
│   ├── cis-compliance-check.yml                # CIS compliance check (multi-OS)
│   ├── ami-validation-playbook.yml             # AMI validation (functional + security)
│   ├── tasks/                                  # Modular task files
│   │   ├── cis/                                # CIS hardening tasks (multi-OS)
│   │   ├── compliance/                         # Compliance check tasks (multi-OS)
│   │   ├── validation/                         # Validation test tasks
│   │   └── common/                              # Common reusable tasks
│   └── vars/                                   # Variable files
├── config/                                     # Configuration files
│   ├── build-config.yml                        # Build and distribution configuration
│   └── README.md                               # Config documentation
├── ubuntu-golden-image.pkr.hcl                # Ubuntu Packer template
├── amazonlinux2023-golden-image.pkr.hcl       # Amazon Linux 2023 Packer template
└── variables.example.pkrvars.hcl              # Example variables (for reference)
```

## Contributing

1. Create a feature branch from `main`
2. Make your changes
3. Create a pull request
4. The workflow will automatically validate your changes
5. After review and approval, merge to `main`
6. The workflow will automatically build the new AMI


## Resources

- [Packer Documentation](https://www.packer.io/docs)
- [AWS AMI Documentation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [AWS OIDC with GitHub Actions](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)

## Support

For issues or questions:
1. Check the [Troubleshooting](#troubleshooting) section
2. Review GitHub Actions logs for error details
3. Check AWS CloudWatch logs (if applicable)
4. Review Packer documentation

---

**Last Updated**: December 2024


