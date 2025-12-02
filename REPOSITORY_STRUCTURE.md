# Repository Structure

This document provides an overview of the repository structure and workflow.

## 📁 Directory Structure

```
packer/
├── .github/
│   └── workflows/
│       └── build-image.yml          # GitHub Actions CI/CD workflow
├── .gitignore                        # Git ignore rules
├── README.md                         # Main documentation
├── QUICKSTART.md                     # Quick start guide
├── REPOSITORY_STRUCTURE.md          # This file
├── ubuntu-golden-image.pkr.hcl      # Main Packer template
└── variables.example.pkrvars.hcl    # Example variables file
```

## 📄 File Descriptions

### Core Files

- **`ubuntu-golden-image.pkr.hcl`**
  - Main Packer template for building Ubuntu golden images
  - Configures AWS AMI creation, provisioning, and HCP Packer integration
  - Auto-creates HCP Packer bucket on first build

- **`.github/workflows/build-image.yml`**
  - GitHub Actions workflow for automated builds
  - Validates templates on PRs
  - Builds AMIs on push to main or manual trigger
  - Uses OIDC for AWS authentication (no access keys needed)

- **`variables.example.pkrvars.hcl`**
  - Example variables file for local development
  - Copy to `variables.pkrvars.hcl` (not committed) for local use
  - Contains example values for all required variables

### Documentation

- **`README.md`**
  - Comprehensive documentation
  - Setup instructions
  - Usage guide
  - AWS OIDC configuration
  - Troubleshooting

- **`QUICKSTART.md`**
  - Step-by-step quick start guide
  - Prerequisites checklist
  - Setup instructions
  - Testing guide

- **`.gitignore`**
  - Excludes sensitive files (variables.pkrvars.hcl, secrets, etc.)
  - Excludes Packer cache and temporary files

## 🔄 Workflow

### Build Process Flow

```
1. Developer pushes code or triggers workflow manually
   ↓
2. GitHub Actions workflow starts
   ↓
3. Validate job:
   - Checks out code
   - Initializes Packer plugins
   - Validates template syntax
   ↓
4. Build job (if validation passes):
   - Configures AWS credentials (OIDC)
   - Initializes Packer plugins
   - Builds AMI:
     * Launches EC2 instance
     * Provisions with updates and packages
     * Creates AMI snapshot
     * Publishes to HCP Packer
   ↓
5. AMI available in AWS
   HCP Packer metadata published
```

### HCP Packer Integration

- **Bucket**: `ubuntu-golden-image` (auto-created on first build)
- **Metadata**: Automatically published with each build
- **Labels**: OS, version, region, managed-by
- **Tracking**: Build fingerprint tracked in HCP Packer

### AWS Integration

- **Authentication**: OIDC (no access keys)
- **Region**: Configurable (default: us-east-1)
- **Instance Type**: t3.micro (configurable)
- **Encryption**: Enabled by default
- **Tags**: Applied to AMI and snapshots

## 🚀 Getting Started

1. **Clone the repository**
   ```bash
   git clone https://github.com/keresifon/packer.git
   cd packer
   ```

2. **Configure GitHub Secrets**
   - `AWS_ROLE_ARN`: IAM role ARN for OIDC
   - `HCP_CLIENT_ID`: HCP client ID
   - `HCP_CLIENT_SECRET`: HCP client secret
   - `HCP_ORGANIZATION_ID`: HCP organization ID
   - `HCP_PROJECT_ID`: HCP project ID

3. **Set up AWS OIDC** (see README.md for details)

4. **Run the workflow**
   - Go to Actions tab
   - Select "Build Ubuntu Golden Image"
   - Click "Run workflow"

## 📊 Build Output

After a successful build:

- **AWS**: AMI created in specified region
- **HCP Packer**: Build iteration published with metadata
- **GitHub Actions**: Workflow shows success status

## 🔧 Customization

### Modify Image Contents

Edit `ubuntu-golden-image.pkr.hcl`:
- Add/remove packages in provisioning scripts
- Modify hardening steps
- Add custom configuration

### Change Build Parameters

- **Region**: Set `aws_region` variable
- **Ubuntu Version**: Set `ubuntu_version` variable (currently hardcoded to 22.04)
- **Instance Type**: Set `instance_type` variable
- **Bucket Name**: Set `hcp_bucket_name` variable

## 📚 Additional Resources

- [Packer Documentation](https://www.packer.io/docs)
- [HCP Packer Documentation](https://developer.hashicorp.com/packer/docs/hcp)
- [AWS OIDC with GitHub Actions](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)

## 🎯 Key Features

- ✅ Automated builds via GitHub Actions
- ✅ OIDC authentication (no access keys)
- ✅ HCP Packer integration (auto-bucket creation)
- ✅ Encrypted AMIs
- ✅ Tagged resources
- ✅ Version tracking
- ✅ Clean, maintainable structure

