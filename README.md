# Ubuntu Golden Image Builder with Packer

This repository contains Packer configurations to build Ubuntu golden images on AWS, integrated with GitHub Actions for CI/CD and HCP Packer for image lifecycle management.

## Overview

This project automates the creation of Ubuntu golden images (AMIs) on AWS using:
- **Packer**: Infrastructure as Code tool for creating machine images
- **AWS**: Cloud platform for building and storing AMIs
- **GitHub Actions**: CI/CD pipeline for automated builds
- **HCP Packer**: HashiCorp Cloud Platform for image versioning and metadata management

## Prerequisites

1. **AWS Account**
   - IAM role configured for OIDC (OpenID Connect) with GitHub Actions
   - IAM permissions to create EC2 instances, AMIs, and snapshots
   - VPC and subnet configuration (optional, uses default if not specified)

2. **HCP Packer Account**
   - HCP account with Packer enabled
   - Client ID and Client Secret
   - Organization ID and Project ID

3. **GitHub Repository**
   - Repository with GitHub Actions enabled
   - Required secrets configured (see below)

## Setup

### 1. Clone the Repository

```bash
git clone <your-repo-url>
cd packer
```

### 2. Configure AWS OIDC Identity Provider

Set up OIDC authentication between GitHub Actions and AWS:

1. **Create OIDC Identity Provider in AWS:**
   ```bash
   # Provider URL: https://token.actions.githubusercontent.com
   # Audience: sts.amazonaws.com
   ```

2. **Create IAM Role for GitHub Actions:**
   - Trust policy allowing GitHub Actions to assume the role
   - Attach policies with permissions for EC2, AMI, and snapshot operations

3. **Add GitHub Secrets:**
   Add the following secrets to your GitHub repository (`Settings > Secrets and variables > Actions`):

   **AWS Secrets:**
   - `AWS_ROLE_ARN`: ARN of the IAM role (e.g., `arn:aws:iam::123456789012:role/github-actions-packer`)

   **HCP Packer Secrets:**
   - `HCP_CLIENT_ID`: Your HCP client ID
   - `HCP_CLIENT_SECRET`: Your HCP client secret
   - `HCP_ORGANIZATION_ID`: Your HCP organization ID
   - `HCP_PROJECT_ID`: Your HCP project ID

   See [AWS OIDC Setup Guide](#aws-oidc-setup) below for detailed instructions.

### 3. Local Development Setup

#### Install Packer

Download and install Packer from [hashicorp.com/packer](https://www.hashicorp.com/packer)

#### Configure AWS Credentials (Local Development)

For local development, configure AWS credentials using one of these methods:

```bash
# Option 1: AWS CLI (recommended)
aws configure

# Option 2: Environment variables
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"

# Option 3: IAM Role (if running on EC2)
# Credentials are automatically provided by the instance role
```

**Note:** GitHub Actions uses OIDC (no access keys needed). See [AWS OIDC Setup](#aws-oidc-setup) section.

#### Configure HCP Packer

```bash
# Authenticate with HCP
packer hcp auth login

# Or set environment variables
export HCP_CLIENT_ID="your-client-id"
export HCP_CLIENT_SECRET="your-client-secret"
export HCP_ORGANIZATION_ID="your-org-id"
export HCP_PROJECT_ID="your-project-id"
```

### 4. Create HCP Packer Bucket

Before building, create a bucket in HCP Packer:

1. Log into HCP Packer
2. Navigate to your project
3. Create a new bucket named `ubuntu-golden-image` (or update the name in the template)

## Usage

### Build Locally

For local development, configure AWS credentials using AWS CLI or environment variables first:

```bash
# Configure AWS credentials (if not already configured)
aws configure
# OR set environment variables:
# export AWS_ACCESS_KEY_ID="your-access-key"
# export AWS_SECRET_ACCESS_KEY="your-secret-key"
# export AWS_DEFAULT_REGION="us-east-1"

# Initialize Packer plugins (first time only)
packer init ubuntu-golden-image.pkr.hcl

# Validate the template
packer validate \
  -var="hcp_client_id=YOUR_CLIENT_ID" \
  -var="hcp_client_secret=YOUR_CLIENT_SECRET" \
  -var="hcp_organization_id=YOUR_ORG_ID" \
  -var="hcp_project_id=YOUR_PROJECT_ID" \
  ubuntu-golden-image.pkr.hcl

# Build the image
packer build \
  -var="hcp_client_id=YOUR_CLIENT_ID" \
  -var="hcp_client_secret=YOUR_CLIENT_SECRET" \
  -var="hcp_organization_id=YOUR_ORG_ID" \
  -var="hcp_project_id=YOUR_PROJECT_ID" \
  ubuntu-golden-image.pkr.hcl
```

**Tip:** For easier local development, you can use a variables file:
```bash
# Create variables.pkrvars.hcl from variables.example.pkrvars.hcl
# Then use:
packer build -var-file=variables.pkrvars.hcl ubuntu-golden-image.pkr.hcl
```

### Build with GitHub Actions

1. **Manual Trigger**: Go to Actions tab > "Build Ubuntu Golden Image" > Run workflow
2. **Automatic Trigger**: Push changes to `main` branch or create a pull request

### Customize Variables

You can override default variables:

```bash
packer build \
  -var="aws_region=us-west-2" \
  -var="ubuntu_version=20.04" \
  -var="instance_type=t3.small" \
  -var="image_name=my-custom-ubuntu" \
  ubuntu-golden-image.pkr.hcl
```

## Project Structure

```
packer/
├── .github/
│   └── workflows/
│       └── build-image.yml      # GitHub Actions CI/CD workflow
├── .gitignore                    # Git ignore rules
├── README.md                     # Main documentation
├── QUICKSTART.md                 # Quick start guide
├── ubuntu-golden-image.pkr.hcl   # Main Packer template
└── variables.example.pkrvars.hcl # Example variables file
```

## Configuration Files

- `ubuntu-golden-image.pkr.hcl`: Main Packer template for building Ubuntu golden images
- `variables.example.pkrvars.hcl`: Example variables file (copy to `variables.pkrvars.hcl` for local use)
- `.github/workflows/build-image.yml`: GitHub Actions workflow for automated builds
- `README.md`: Main documentation
- `QUICKSTART.md`: Step-by-step quick start guide

## Image Contents

The golden image includes:
- Latest Ubuntu LTS updates
- Common utilities: curl, wget, git, unzip, jq
- AWS CLI
- System monitoring tools: htop, net-tools
- Hardened SSH configuration
- Cleaned cloud-init logs and temporary files

## HCP Packer Integration

Images are automatically published to HCP Packer with:
- Version metadata
- Build timestamps
- Labels for filtering (OS, version, region)
- AMI IDs and regions

Query images using HCP Packer API or Terraform:

```hcl
data "hcp-packer-image" "ubuntu" {
  bucket_name  = "ubuntu-golden-image"
  channel_name = "latest"
  region      = "us-east-1"
}
```

## Security Best Practices

1. **OIDC Authentication**: Use OIDC with GitHub Actions instead of access keys
2. **IAM Roles**: Use IAM roles with least privilege
3. **Secrets Management**: Never commit credentials to the repository
4. **Image Hardening**: Review and customize provisioning scripts
5. **Encryption**: AMIs are encrypted by default (can be configured)
6. **Access Control**: Limit HCP Packer bucket access
7. **Local Development**: Use AWS CLI or temporary credentials for local builds

## Troubleshooting

### Build Failures

- Check AWS credentials and permissions
- Verify HCP Packer authentication
- Review Packer logs for specific errors
- Ensure the source AMI exists in the target region

### HCP Packer Issues

- Verify bucket exists before building
- Check HCP credentials are correct
- Ensure organization and project IDs are valid

## Contributing

1. Create a feature branch
2. Make your changes
3. Test locally with `packer validate` and `packer build`
4. Submit a pull request

## License

[Specify your license here]

## Resources

- [Packer Documentation](https://www.packer.io/docs)
- [HCP Packer Documentation](https://developer.hashicorp.com/packer/docs/hcp)
- [AWS AMI Documentation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)

