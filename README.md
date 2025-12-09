# Ubuntu Golden Image Builder with Packer

This repository automates the creation of Ubuntu golden images (AMIs) on AWS using Packer and GitHub Actions for CI/CD. All builds run automatically through GitHub Actions - no local setup required. The project includes CIS benchmark hardening, automated validation, and multi-region AMI distribution.

## Overview

This project provides a fully automated pipeline for building Ubuntu golden images:

- **Packer**: Infrastructure as Code tool for creating machine images
- **AWS**: Cloud platform for building and storing AMIs
- **GitHub Actions**: CI/CD pipeline that handles all builds automatically

### Key Features

- ✅ **Fully Automated**: All builds run through GitHub Actions - no local setup needed
- ✅ **Secure Authentication**: Uses AWS OIDC (no access keys required)
- ✅ **CIS Hardening**: Automated CIS Ubuntu 22.04 LTS Level 2 benchmark compliance
- ✅ **Encrypted AMIs**: All AMIs are encrypted by default
- ✅ **Tagged Resources**: AMIs and snapshots are automatically tagged
- ✅ **Post-Build Validation**: Automated AMI validation with functional and security tests
- ✅ **Multi-Region Distribution**: Automatically copies AMIs to target regions
- ✅ **Parameter Store Integration**: Stores AMI IDs in Systems Manager for easy lookup

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
│    b) Wait for SSH availability                             │
│    c) Provision instance:                                   │
│       - Update system packages                              │
│       - Install common utilities                            │
│       - Install AWS CLI v2                                  │
│       - Install Ansible                                     │
│       - Apply CIS benchmark hardening (via Ansible)         │
│       - Run CIS compliance check                            │
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
│    - Run functional and security tests                       │
│    - Verify CIS compliance                                  │
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

The GitHub Actions workflow (`build-image.yml`) triggers on:

1. **Push to `main` branch** (when Packer files change)
   - Validates the template
   - Builds the AMI automatically

2. **Manual workflow dispatch**
   - Go to Actions tab → "Build Ubuntu Golden Image" → "Run workflow"
   - Can specify:
     - Ubuntu version (22.04 or 20.04)
     - AWS region (default: us-east-1)

3. **Pull request to `main`**
   - Only validates the template (does not build)
   - Prevents broken templates from being merged

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

### Step 2: Configure AWS OIDC Authentication

This project uses AWS OIDC (OpenID Connect) for secure authentication between GitHub Actions and AWS. This eliminates the need to store AWS access keys as secrets.

**📖 For detailed step-by-step instructions, see [AWS OIDC Setup Guide](docs/AWS-OIDC-SETUP.md)**

The guide includes:
- Creating OIDC Identity Provider in AWS
- Creating IAM Role with proper trust policy
- Configuring all required IAM permissions
- Setting up GitHub Secrets
- Troubleshooting common issues

**Quick Summary:**
1. Create OIDC Identity Provider in AWS IAM (`https://token.actions.githubusercontent.com`)
2. Create IAM Role with trust policy allowing your GitHub repository
3. Attach permissions policy with required EC2 and SSM permissions (see [AWS-OIDC-SETUP.md](docs/AWS-OIDC-SETUP.md) for complete list)
4. Add `AWS_ROLE_ARN` secret to GitHub repository

**Required IAM Permissions:**
- EC2: Run instances, create images, manage snapshots, security groups, key pairs
- SSM Parameter Store: Put/get parameters for AMI ID storage
- See [AWS-OIDC-SETUP.md](docs/AWS-OIDC-SETUP.md#required-iam-permissions) for the complete permissions list

### Step 3: Configure Build Settings (Optional)

Edit `config/build-config.yml` to customize:
- Default AWS region and Ubuntu version
- Instance types for build and validation
- CIS compliance thresholds
- Target regions for AMI distribution
- Parameter Store settings

See [Configuration Guide](config/README.md) for details.

### Step 4: Verify Setup

1. **Check GitHub Secrets**: Ensure `AWS_ROLE_ARN` secret is configured
2. **Check AWS Role**: Verify the IAM role exists and has correct permissions
3. **Verify Workflow File**: Ensure `.github/workflows/build-image.yml` exists
4. **Test Build**: Run a manual workflow dispatch to verify everything works

## Usage

### Triggering a Build

#### Method 1: Manual Trigger (Recommended for First Build)

1. Go to your GitHub repository
2. Click on the **Actions** tab
3. Select **"Build Ubuntu Golden Image"** workflow from the left sidebar
4. Click **"Run workflow"** button (top right)
5. Configure options:
   - **Ubuntu version**: Choose `22.04` (default) or `20.04`
   - **AWS region**: Enter region (default: `us-east-1`)
6. Click **"Run workflow"**

#### Method 2: Automatic Trigger (Push to Main)

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
- ✅ Final step shows "AMI build completed successfully!"
- ✅ Build output displays the AMI ID:
  ```
  ==> Builds finished. The artifacts of successful builds are:
  --> amazon-ebs.ubuntu: AMIs were created:
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
   - **Name**: `ubuntu-golden-image-*`
   - **Owner**: Your AWS account ID
3. The AMI will show:
   - **Status**: `available` (after snapshot completes)
   - **Name**: `ubuntu-golden-image-YYYY-MM-DD-HHMM`
   - **Creation Date**: When the build completed
   - **AMI ID**: e.g., `ami-xxxxxxxxxxxxxxxxx`

#### From Build Output

The AMI ID is displayed at the end of a successful build in the GitHub Actions logs:

```
==> Builds finished. The artifacts of successful builds are:
--> amazon-ebs.ubuntu: AMIs were created:
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
# Get latest AMI ID from Parameter Store
data "aws_ssm_parameter" "ami_us_west_2" {
  name = "/packer/ubuntu-golden-image/us-west-2/latest"
}

resource "aws_instance" "example" {
  ami           = data.aws_ssm_parameter.ami_us_west_2.value
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

The workflow sets these environment variables:

- `PKR_VAR_aws_region`: AWS region (default: `us-east-1`)
- `PKR_VAR_ubuntu_version`: Ubuntu version (default: `22.04`)

These are passed to Packer as variables during the build.

## Image Contents

The golden image includes:

### System Updates
- Latest Ubuntu LTS security updates
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
- **CIS Ubuntu 22.04 LTS Benchmark compliance** (see CIS Benchmarking section below)

### CIS Benchmarking
The image includes automated CIS (Center for Internet Security) Ubuntu 22.04 LTS benchmark hardening at **Level 2** (includes all Level 1 controls plus additional hardening):

**Level 1 Controls:**
- **Filesystem Configuration**: Disables unnecessary filesystem types (cramfs, squashfs, udf)
- **Process Hardening**: Core dumps restricted, ASLR enabled
- **Mandatory Access Control**: AppArmor installed and configured
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

A CIS compliance check runs during the build process to verify compliance. The audit is non-blocking by default but can be configured to fail the build if compliance is below threshold.

### Cleanup
- Cloud-init logs cleared
- Temporary files removed
- System cache cleaned

## CIS Benchmarking

### Overview

This project includes automated CIS (Center for Internet Security) Ubuntu 22.04 LTS benchmark hardening. The CIS benchmarks provide a set of security configuration guidelines to help organizations secure their systems.

### Implementation

The CIS hardening is implemented using **Ansible playbooks** for better maintainability and idempotency:

1. **`ansible/cis-hardening-playbook.yml`**: Applies CIS benchmark recommendations during image build
2. **`ansible/cis-compliance-check.yml`**: Performs compliance checks and generates an audit report

**Why Ansible?**
- ✅ **Idempotent**: Safe to run multiple times
- ✅ **Maintainable**: Structured playbooks, easier to read and modify
- ✅ **Flexible**: Easy to customize which CIS sections to apply
- ✅ **Better reporting**: Structured compliance reports
- ✅ **Reusable**: Can leverage community CIS roles from Ansible Galaxy

### What Gets Hardened

The hardening playbook implements **CIS Level 2** recommendations (includes all Level 1 plus additional controls):

**Level 1 Controls:**
- **Filesystem Security**: Disables unnecessary filesystem types (cramfs, squashfs, udf)
- **Process Hardening**: Restricts core dumps, enables ASLR
- **Network Security**: Configures secure network parameters (IP forwarding disabled, SYN cookies enabled)
- **Access Control**: Sets up AppArmor mandatory access control
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

### Audit Report

During the build process, the CIS audit script runs automatically and generates a compliance report. The audit checks include:

- Filesystem configuration compliance
- Boot settings security
- Process hardening verification
- Network parameter validation
- System file permission checks
- Service configuration verification

The audit is **non-blocking** - the build will continue even if some checks fail, but failures will be reported in the build logs for review.

### Customizing CIS Hardening

To modify the CIS hardening:

1. Edit `ansible/cis-hardening-playbook.yml` to add or remove hardening tasks
2. Edit `ansible/cis-compliance-check.yml` to add or modify compliance checks
3. Adjust variables in the Packer template:
   - `cis_level`: Set to 1 (Level 1) or 2 (Level 2)
   - `cis_compliance_threshold`: Minimum compliance percentage (default: 80)
   - `fail_on_non_compliance`: Set to `true` to fail build on non-compliance

**Example:**
```hcl
packer build \
  -var 'cis_level=2' \
  -var 'cis_compliance_threshold=90' \
  -var 'fail_on_non_compliance=true' \
  ubuntu-golden-image.pkr.hcl
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

1. Comment out or remove the CIS provisioning blocks in `ubuntu-golden-image.pkr.hcl`:
   ```hcl
   # Provisioning: CIS Benchmark Hardening
   # (comment out or remove these provisioner blocks)
   ```

2. Rebuild the image

### CIS Benchmark Documentation

For detailed information about CIS Ubuntu 22.04 LTS benchmarks, see:
- [CIS Benchmarks](https://www.cisecurity.org/benchmark/ubuntu_linux)
- [CIS Ubuntu 22.04 LTS Benchmark](https://www.cisecurity.org/cis-benchmarks/)

## Customization

### Modify Image Contents

Edit `ubuntu-golden-image.pkr.hcl`:

```hcl
# Add packages in the provisioning section
provisioner "shell" {
  inline = [
    "sudo apt-get install -y your-package-name"
  ]
}
```

### Change Build Parameters

Modify workflow inputs or environment variables:

- **Region**: Change `PKR_VAR_aws_region` in workflow
- **Instance Type**: Modify `instance_type` variable in template
- **Ubuntu Version**: Change `PKR_VAR_ubuntu_version` (note: AMI filter is currently hardcoded to 22.04)

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
│       └── build-image.yml          # GitHub Actions CI/CD workflow
├── .gitignore                        # Git ignore rules
├── README.md                         # Main project documentation
├── docs/                             # Documentation
│   ├── AMI-DISTRIBUTION.md           # AMI distribution guide
│   ├── CIS-IMPLEMENTATION-COMPARISON.md  # CIS implementation comparison
│   ├── PIPELINE-TIMING.md            # Pipeline timing documentation
│   └── VALIDATION.md                 # Validation documentation
├── ansible/                          # Ansible playbooks and tasks
│   ├── cis-hardening-playbook.yml    # Main CIS hardening playbook
│   ├── cis-compliance-check.yml     # CIS compliance check playbook
│   ├── ami-validation-playbook.yml  # AMI validation playbook
│   ├── tasks/                        # Modular task files
│   │   ├── cis/                      # CIS hardening tasks
│   │   ├── compliance/               # Compliance check tasks
│   │   ├── validation/               # Validation test tasks
│   │   └── common/                   # Common reusable tasks
│   └── vars/                         # Variable files
├── config/                           # Configuration files
│   ├── build-config.yml              # Build and distribution configuration
│   └── README.md                     # Config documentation
├── ubuntu-golden-image.pkr.hcl      # Main Packer template
└── variables.example.pkrvars.hcl    # Example variables (for reference)
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


