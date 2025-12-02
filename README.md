# Ubuntu Golden Image Builder with Packer

This repository automates the creation of Ubuntu golden images (AMIs) on AWS using Packer, GitHub Actions for CI/CD, and HCP Packer for image lifecycle management. All builds run automatically through GitHub Actions - no local setup required.

## Overview

This project provides a fully automated pipeline for building Ubuntu golden images:

- **Packer**: Infrastructure as Code tool for creating machine images
- **AWS**: Cloud platform for building and storing AMIs
- **GitHub Actions**: CI/CD pipeline that handles all builds automatically
- **HCP Packer**: HashiCorp Cloud Platform for image versioning and metadata management

### Key Features

- ✅ **Fully Automated**: All builds run through GitHub Actions - no local setup needed
- ✅ **Secure Authentication**: Uses AWS OIDC (no access keys required)
- ✅ **Auto-Bucket Creation**: HCP Packer bucket is created automatically on first build
- ✅ **Version Tracking**: Every build is tracked in HCP Packer with metadata
- ✅ **Encrypted AMIs**: All AMIs are encrypted by default
- ✅ **Tagged Resources**: AMIs and snapshots are automatically tagged

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
│       - Install AWS CLI                                     │
│       - Harden SSH configuration                            │
│       - Clean up temporary files                            │
│    d) Create AMI snapshot                                   │
│    e) Register AMI in AWS                                   │
│    f) Publish metadata to HCP Packer                       │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ 5. Output                                                   │
│    - AMI available in AWS EC2                               │
│    - Metadata published to HCP Packer                      │
│    - Build iteration tracked with fingerprint               │
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

### 2. HCP Packer Account

- **HCP Account** (sign up at https://portal.cloud.hashicorp.com)
- **Organization** created in HCP
- **Project** created in HCP
- **Service Principal** credentials:
  - Client ID
  - Client Secret

### 3. GitHub Repository

- **Repository** with GitHub Actions enabled
- **Access** to configure secrets and workflows

## Detailed Setup Instructions

### Step 1: Clone the Repository

```bash
git clone https://github.com/keresifon/packer.git
cd packer
```

### Step 2: Configure AWS OIDC Identity Provider

OIDC (OpenID Connect) allows GitHub Actions to authenticate with AWS without storing access keys. This is more secure than using access keys.

#### 2.1 Create OIDC Identity Provider in AWS

1. Log into AWS Console
2. Navigate to **IAM** → **Identity providers**
3. Click **Add provider**
4. Select **OpenID Connect**
5. Configure:
   - **Provider URL**: `https://token.actions.githubusercontent.com`
   - **Audience**: `sts.amazonaws.com`
6. Click **Add provider**

#### 2.2 Create IAM Role for GitHub Actions

1. Navigate to **IAM** → **Roles** → **Create role**
2. Select **Web identity**
3. Choose the identity provider you just created:
   - **Identity provider**: `token.actions.githubusercontent.com`
   - **Audience**: `sts.amazonaws.com`
4. Click **Next**
5. **Configure conditions** (optional but recommended):
   ```json
   {
     "StringEquals": {
       "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
     },
     "StringLike": {
       "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_USERNAME/YOUR_REPO_NAME:*"
     }
   }
   ```
   Replace `YOUR_GITHUB_USERNAME` and `YOUR_REPO_NAME` with your actual values.
6. Click **Next**
7. **Attach policies** with these permissions:
   - `AmazonEC2FullAccess` (or create a custom policy with least privilege)
   
   **Minimum required permissions:**
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": [
           "ec2:DescribeImages",
           "ec2:DescribeInstances",
           "ec2:RunInstances",
           "ec2:CreateImage",
           "ec2:CreateTags",
           "ec2:CreateSnapshot",
           "ec2:DescribeSnapshots",
           "ec2:DeleteSnapshot",
           "ec2:TerminateInstances",
           "ec2:DeregisterImage",
           "ec2:DescribeRegions",
           "ec2:DescribeAvailabilityZones",
           "ec2:CreateSecurityGroup",
           "ec2:DeleteSecurityGroup",
           "ec2:AuthorizeSecurityGroupIngress",
           "ec2:CreateKeyPair",
           "ec2:DeleteKeyPair",
           "ec2:DescribeKeyPairs"
         ],
         "Resource": "*"
       }
     ]
   }
   ```
8. Click **Next**
9. **Name the role**: e.g., `github-actions-packer`
10. **Add description**: "IAM role for GitHub Actions to build Packer AMIs"
11. Click **Create role**
12. **Copy the Role ARN** - you'll need this for GitHub Secrets
   - Format: `arn:aws:iam::ACCOUNT_ID:role/ROLE_NAME`

### Step 3: Set Up HCP Packer

#### 3.1 Create HCP Account and Project

1. Go to https://portal.cloud.hashicorp.com
2. Sign up or log in
3. Create or select an **Organization**
4. Create or select a **Project**

#### 3.2 Create Service Principal

1. Navigate to **Access Control** → **Service Principals**
2. Click **Create service principal**
3. Name it (e.g., `github-actions-packer`)
4. **Save the credentials**:
   - **Client ID** (you'll need this)
   - **Client Secret** (you'll need this - save it securely!)

#### 3.3 Get Organization and Project IDs

- **Organization ID**: Found in the URL or Settings
  - URL format: `https://portal.cloud.hashicorp.com/orgs/ORG_ID/...`
- **Project ID**: Found in the URL or Settings
  - URL format: `https://portal.cloud.hashicorp.com/orgs/ORG_ID/projects/PROJECT_ID/...`

**Note**: The HCP Packer bucket (`ubuntu-golden-image`) will be created automatically on the first build. You don't need to create it manually.

### Step 4: Configure GitHub Secrets

GitHub Secrets store sensitive information that the workflow needs to authenticate with AWS and HCP Packer.

1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret** for each of the following:

#### AWS Secrets

- **Name**: `AWS_ROLE_ARN`
- **Value**: The ARN of the IAM role you created (e.g., `arn:aws:iam::123456789012:role/github-actions-packer`)

#### HCP Packer Secrets

- **Name**: `HCP_CLIENT_ID`
- **Value**: Your HCP service principal Client ID

- **Name**: `HCP_CLIENT_SECRET`
- **Value**: Your HCP service principal Client Secret

- **Name**: `HCP_ORGANIZATION_ID`
- **Value**: Your HCP Organization ID

- **Name**: `HCP_PROJECT_ID`
- **Value**: Your HCP Project ID

### Step 5: Verify Setup

1. **Check GitHub Secrets**: Ensure all 5 secrets are configured
2. **Check AWS Role**: Verify the IAM role exists and has correct permissions
3. **Check HCP Project**: Verify you can access your HCP project

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
     - HCP Packer publishing

#### What to Look For

**Successful Build:**
- ✅ All steps show green checkmarks
- ✅ "Build AMI" job completes successfully
- ✅ Final step shows "AMI build completed successfully!"

**Failed Build:**
- ❌ Red X on failed step
- Click on the failed step to see error details
- Common issues:
  - AWS permissions
  - HCP authentication
  - Template syntax errors
  - Package installation failures

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

#### In HCP Packer

1. Go to https://portal.cloud.hashicorp.com
2. Navigate to your **Organization** → **Project** → **Packer**
3. Click on **Buckets** → `ubuntu-golden-image`
4. You'll see:
   - **Build iterations** with timestamps
   - **Build fingerprint** (e.g., `01KBEJ6TYB1YNR80F7W7KNED0B`)
   - **AMI IDs** per region
   - **Labels**: os, version, region, managed-by

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

#### Use with HCP Packer (Recommended)

```hcl
# Using HCP Packer data source
data "hcp-packer-image" "ubuntu" {
  bucket_name  = "ubuntu-golden-image"
  channel_name = "latest"  # or specific iteration
  region       = "us-east-1"
}

resource "aws_instance" "example" {
  ami           = data.hcp-packer-image.ubuntu.cloud_image_id
  instance_type = "t3.micro"
}
```

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
   - Registers AMI
   - Publishes to HCP Packer

**Duration**: ~8-15 minutes

**Failure Points**:
- AWS permissions issues
- HCP authentication failures
- Provisioning script errors
- Network connectivity issues

### Environment Variables

The workflow sets these environment variables:

- `PKR_VAR_aws_region`: AWS region (default: `us-east-1`)
- `PKR_VAR_ubuntu_version`: Ubuntu version (default: `22.04`)
- `PKR_VAR_hcp_bucket_name`: HCP bucket name (`ubuntu-golden-image`)

These are passed to Packer as variables during the build.

## Image Contents

The golden image includes:

### System Updates
- Latest Ubuntu LTS security updates
- System packages upgraded to latest versions

### Installed Packages
- **Utilities**: curl, wget, git, unzip
- **AWS Tools**: AWS CLI
- **Monitoring**: htop, net-tools
- **Optional**: jq (if dependencies available)

### Security Hardening
- SSH root login disabled
- Password authentication disabled
- SSH configuration hardened

### Cleanup
- Cloud-init logs cleared
- Temporary files removed
- System cache cleaned

## HCP Packer Integration

### Automatic Bucket Creation

The HCP Packer bucket (`ubuntu-golden-image`) is created automatically on the first build. You don't need to create it manually.

### Published Metadata

Each build publishes:
- **Build fingerprint**: Unique identifier for the build
- **AMI ID**: The created AMI ID
- **Region**: AWS region where AMI was created
- **Labels**:
  - `os`: ubuntu
  - `version`: Ubuntu version (22.04, 20.04, etc.)
  - `region`: AWS region
  - `managed-by`: packer

### Querying Images

#### Via HCP Packer UI

1. Go to HCP Packer → Buckets → `ubuntu-golden-image`
2. View build iterations
3. See AMI IDs per region

#### Via Terraform

```hcl
data "hcp-packer-image" "ubuntu" {
  bucket_name  = "ubuntu-golden-image"
  channel_name = "latest"
  region       = "us-east-1"
}

output "ami_id" {
  value = data.hcp-packer-image.ubuntu.cloud_image_id
}
```

#### Via HCP Packer API

```bash
curl -H "Authorization: Bearer $HCP_TOKEN" \
  https://api.cloud.hashicorp.com/packer/2023-01-01/organizations/{organization_id}/projects/{project_id}/images/{bucket_name}/iterations
```

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

### Build Fails: "HCP Authentication Error"

**Cause**: Invalid HCP credentials

**Solution**:
1. Verify all HCP secrets are correct:
   - `HCP_CLIENT_ID`
   - `HCP_CLIENT_SECRET`
   - `HCP_ORGANIZATION_ID`
   - `HCP_PROJECT_ID`
2. Check service principal is active in HCP
3. Verify organization/project IDs match your HCP setup

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
8. **Access Control**: Limit HCP Packer bucket access to authorized users

## Project Structure

```
packer/
├── .github/
│   └── workflows/
│       └── build-image.yml          # GitHub Actions CI/CD workflow
├── .gitignore                        # Git ignore rules
├── README.md                         # This file
├── QUICKSTART.md                     # Quick start guide
├── REPOSITORY_STRUCTURE.md          # Repository overview
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
- [HCP Packer Documentation](https://developer.hashicorp.com/packer/docs/hcp)
- [AWS AMI Documentation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [AWS OIDC with GitHub Actions](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)

## Support

For issues or questions:
1. Check the [Troubleshooting](#troubleshooting) section
2. Review GitHub Actions logs for error details
3. Check AWS CloudWatch logs (if applicable)
4. Review HCP Packer documentation

---

**Last Updated**: December 2024
