# Next Steps: Getting Started

Your Packer project is ready! Follow these steps to complete the setup and start building golden images.

## ✅ Completed
- [x] Git repository initialized
- [x] All files committed
- [x] Project structure created

## 📋 Setup Checklist

### 1. Create GitHub Repository

**Option A: Create new repository on GitHub**
1. Go to https://github.com/new
2. Create a new repository (e.g., `ubuntu-golden-images`)
3. **DO NOT** initialize with README, .gitignore, or license (we already have these)
4. Copy the repository URL

**Option B: Use existing repository**
- If you already have a repository, use that URL

### 2. Push to GitHub

```bash
# Add your GitHub repository as remote (replace with your URL)
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git

# Rename branch to main (if needed)
git branch -M main

# Push to GitHub
git push -u origin main
```

### 3. Set Up AWS OIDC Identity Provider

**Create OIDC Identity Provider:**
1. Go to AWS IAM Console → Identity providers → Add provider
2. Select **OpenID Connect**
3. Provider URL: `https://token.actions.githubusercontent.com`
4. Audience: `sts.amazonaws.com`
5. Click **Add provider**

**Create IAM Role:**
1. Go to IAM → Roles → Create role
2. Select **Web identity**
3. Choose the GitHub Actions identity provider you just created
4. Audience: `sts.amazonaws.com`
5. Configure conditions:
   ```json
   {
     "StringEquals": {
       "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
     },
     "StringLike": {
       "token.actions.githubusercontent.com:sub": "repo:YOUR_USERNAME/YOUR_REPO:*"
     }
   }
   ```
6. Attach policies with these permissions:
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
7. Name the role (e.g., `github-actions-packer`)
8. **Copy the Role ARN** (you'll need it for GitHub Secrets)

### 4. Set Up HCP Packer

1. Log into HCP Packer: https://portal.cloud.hashicorp.com
2. Create or select an organization
3. Create or select a project
4. Create a new bucket named `ubuntu-golden-image`
5. Generate service principal credentials:
   - Go to Settings → Service Principals
   - Create a new service principal or use existing one
   - **Save the Client ID and Client Secret**

### 5. Configure GitHub Secrets

Go to your GitHub repository → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

Add these secrets:

**AWS Secrets:**
- `AWS_ROLE_ARN`: The ARN of your IAM role (e.g., `arn:aws:iam::123456789012:role/github-actions-packer`)

**HCP Packer Secrets:**
- `HCP_CLIENT_ID`: Your HCP client ID
- `HCP_CLIENT_SECRET`: Your HCP client secret
- `HCP_ORGANIZATION_ID`: Your HCP organization ID (found in HCP URL or settings)
- `HCP_PROJECT_ID`: Your HCP project ID (found in HCP URL or settings)

### 6. Test the Workflow

1. Go to your GitHub repository → **Actions** tab
2. Select **Build Ubuntu Golden Image** workflow
3. Click **Run workflow**
4. Choose options:
   - Ubuntu version: `22.04` (default)
   - AWS region: `us-east-1` (default)
5. Click **Run workflow**
6. Monitor the workflow execution

### 7. Verify the Build

**Check GitHub Actions:**
- Go to Actions tab → View workflow run
- Verify both `validate` and `build` jobs complete successfully

**Check AWS:**
- Go to EC2 → AMIs
- Find your new AMI (named `ubuntu-golden-image-YYYY-MM-DD-hhmm`)

**Check HCP Packer:**
- Log into HCP Packer
- Navigate to your bucket `ubuntu-golden-image`
- Verify the build iteration and metadata

## 🔧 Troubleshooting

### Workflow Fails with "Access Denied"
- Verify OIDC identity provider is configured correctly
- Check IAM role trust policy includes your repository
- Ensure role has all required EC2 permissions

### Workflow Fails with "HCP Authentication Error"
- Verify HCP secrets are correct
- Check HCP bucket exists before building
- Ensure HCP organization and project IDs are correct

### Build Fails with "AMI Not Found"
- Verify source AMI exists in the target region
- Check AWS region is correct

## 📚 Additional Resources

- [AWS OIDC Setup Guide](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [HCP Packer Documentation](https://developer.hashicorp.com/packer/docs/hcp)
- [Packer Documentation](https://www.packer.io/docs)

## 🎯 Quick Commands Reference

```bash
# Push to GitHub (after adding remote)
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git
git branch -M main
git push -u origin main

# Check git status
git status

# View commits
git log --oneline

# Pull latest changes
git pull origin main
```

## ✨ Next Steps After First Build

1. **Review the AMI** - Launch a test instance to verify it works
2. **Customize** - Modify provisioning scripts in `ubuntu-golden-image.pkr.hcl`
3. **Add More Versions** - Create templates for Ubuntu 20.04, 24.04, etc.
4. **Set Up Channels** - Configure HCP Packer channels for version management
5. **Integrate with Terraform** - Use HCP Packer data source in your infrastructure code

Good luck! 🚀

