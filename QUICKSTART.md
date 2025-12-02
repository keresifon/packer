# Quick Start Guide

This guide will help you get started building Ubuntu golden images with Packer, AWS, GitHub Actions, and HCP Packer.

## Prerequisites Checklist

- [ ] AWS account with programmatic access
- [ ] HCP Packer account (sign up at https://portal.cloud.hashicorp.com)
- [ ] GitHub repository
- [ ] Packer installed locally (for testing)

## Step 1: Set Up AWS OIDC Identity Provider

### Option A: OIDC (Recommended for GitHub Actions)

1. **Create OIDC Identity Provider in AWS:**
   - Go to IAM → Identity providers → Add provider
   - Provider URL: `https://token.actions.githubusercontent.com`
   - Audience: `sts.amazonaws.com`

2. **Create IAM Role:**
   - Go to IAM → Roles → Create role
   - Select "Web identity" → Choose GitHub Actions provider
   - Configure trust policy with your repository
   - Attach policies with EC2/AMI permissions (see README for full list)

3. **Note the Role ARN** (you'll need it for GitHub Secrets)

### Option B: Access Keys (For Local Development Only)

1. Create an IAM user in AWS with the following permissions:
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

2. Create an access key for the IAM user (for local testing only)

## Step 2: Set Up HCP Packer

1. Log into HCP Packer: https://portal.cloud.hashicorp.com
2. Create or select an organization
3. Create or select a project
4. Create a new bucket named `ubuntu-golden-image`
5. Generate a service principal or use your user credentials:
   - Go to Settings > Service Principals
   - Create a new service principal or note your Client ID and Secret

## Step 3: Configure GitHub Secrets

1. Go to your GitHub repository
2. Navigate to `Settings > Secrets and variables > Actions`
3. Add the following secrets:

### AWS Secrets (OIDC)
- `AWS_ROLE_ARN`: ARN of your IAM role (e.g., `arn:aws:iam::123456789012:role/github-actions-packer`)

**Note:** If using access keys for local development, you can set them as environment variables, but OIDC is required for GitHub Actions.

### HCP Packer Secrets
- `HCP_CLIENT_ID`: Your HCP client ID
- `HCP_CLIENT_SECRET`: Your HCP client secret
- `HCP_ORGANIZATION_ID`: Your HCP organization ID (found in URL or settings)
- `HCP_PROJECT_ID`: Your HCP project ID (found in URL or settings)

## Step 4: Test Locally (Optional)

1. Copy the example variables file:
   ```bash
   cp variables.example.pkrvars.hcl variables.pkrvars.hcl
   ```

2. Edit `variables.pkrvars.hcl` with your credentials

3. Authenticate with HCP:
   ```bash
   export HCP_CLIENT_ID="your-client-id"
   export HCP_CLIENT_SECRET="your-client-secret"
   packer hcp auth login
   ```

4. Initialize Packer plugins:
   ```bash
   packer init ubuntu-golden-image.pkr.hcl
   ```

5. Validate the template:
   ```bash
   packer validate -var-file=variables.pkrvars.hcl ubuntu-golden-image.pkr.hcl
   ```

6. Build the image:
   ```bash
   packer build -var-file=variables.pkrvars.hcl ubuntu-golden-image.pkr.hcl
   ```

## Step 5: Trigger GitHub Actions Build

1. **Manual Trigger:**
   - Go to the Actions tab in your GitHub repository
   - Select "Build Ubuntu Golden Image"
   - Click "Run workflow"
   - Choose your options (Ubuntu version, AWS region)
   - Click "Run workflow"

2. **Automatic Trigger:**
   - Push changes to the `main` branch
   - The workflow will automatically validate
   - To build, push to `main` or manually trigger

## Step 6: Verify the Build

1. **Check GitHub Actions:**
   - Go to Actions tab
   - View the workflow run logs
   - Verify the build completed successfully

2. **Check AWS:**
   - Go to EC2 > AMIs
   - Find your new AMI (named `ubuntu-golden-image-YYYY-MM-DD-hhmm`)

3. **Check HCP Packer:**
   - Log into HCP Packer
   - Navigate to your bucket `ubuntu-golden-image`
   - Verify the build iteration and metadata

## Using the Image

### With Terraform

```hcl
data "hcp-packer-image" "ubuntu" {
  bucket_name  = "ubuntu-golden-image"
  channel_name = "latest"
  region       = "us-east-1"
}

resource "aws_instance" "example" {
  ami           = data.hcp-packer-image.ubuntu.cloud_image_id
  instance_type = "t3.micro"
}
```

### Direct AMI ID

Find the AMI ID in:
- AWS Console: EC2 > AMIs
- HCP Packer: Bucket > Iterations > Latest

## Troubleshooting

### Build Fails in GitHub Actions

1. **Check Secrets:** Ensure all secrets are correctly set
2. **Check Permissions:** Verify AWS IAM permissions
3. **Check HCP Bucket:** Ensure bucket exists before building
4. **View Logs:** Check the Actions logs for specific errors

### Local Build Fails

1. **HCP Authentication:** Run `packer hcp auth login`
2. **AWS Credentials:** Verify `aws configure` or environment variables
3. **Packer Version:** Ensure Packer 1.10+ is installed
4. **Plugin Initialization:** Run `packer init` first

### HCP Packer Issues

1. **Bucket Not Found:** Create the bucket in HCP Packer first
2. **Authentication:** Verify HCP credentials are correct
3. **Organization/Project:** Double-check IDs match your HCP setup

## Next Steps

- Customize the provisioning scripts in `ubuntu-golden-image.pkr.hcl`
- Add additional build configurations for different regions
- Set up image channels in HCP Packer for version management
- Integrate with Terraform Cloud or other IaC tools

## Resources

- [Packer Documentation](https://www.packer.io/docs)
- [HCP Packer Documentation](https://developer.hashicorp.com/packer/docs/hcp)
- [AWS AMI Documentation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html)

