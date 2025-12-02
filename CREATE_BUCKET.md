# How to Create HCP Packer Bucket

**Good News!** Your Packer template is now configured to **auto-create** the bucket on first build. You don't need to create it manually!

However, if you prefer to create it manually first, here are the options:

## Method 1: HCP Packer Console (Easiest)

1. **Log into HCP Packer**
   - Go to: https://portal.cloud.hashicorp.com
   - Sign in with your HashiCorp account

2. **Navigate to Packer**
   - Select your **Organization** (if you have multiple)
   - Select your **Project** (or create one if needed)
   - Click on **Packer** in the left sidebar
   - Click on **Buckets** tab

3. **Create New Bucket**
   - Click the **"Create bucket"** or **"+"** button
   - Fill in the details:
     - **Name**: `ubuntu-golden-image` (must match exactly)
     - **Description**: "Ubuntu Golden Image for AWS" (optional)
     - **Labels** (optional):
       - `os`: `ubuntu`
       - `managed-by`: `packer`
   - Click **Create**

4. **Verify**
   - You should now see `ubuntu-golden-image` in your buckets list
   - The bucket will be empty until your first build completes

## Method 2: HCP CLI (Advanced)

If you have HCP CLI installed:

```bash
# Authenticate first
hcp auth login

# Create the bucket
hcp packer buckets create ubuntu-golden-image \
  --description "Ubuntu Golden Image for AWS" \
  --labels os=ubuntu,managed-by=packer
```

## Method 3: Terraform (If using Infrastructure as Code)

```hcl
resource "hcp_packer_bucket" "ubuntu_golden_image" {
  name        = "ubuntu-golden-image"
  description = "Ubuntu Golden Image for AWS"
  
  labels = {
    os         = "ubuntu"
    managed-by = "packer"
  }
}
```

## Verify Bucket Creation

After creating the bucket:

1. Go back to HCP Packer → Buckets
2. You should see `ubuntu-golden-image` listed
3. Click on it to see details (it will be empty until first build)

## Important Notes

- **Bucket name must match exactly**: `ubuntu-golden-image` (case-sensitive)
- **Bucket must exist before building**: Packer cannot create buckets automatically
- **Organization/Project**: Make sure you're creating the bucket in the correct organization and project that matches your `HCP_ORGANIZATION_ID` and `HCP_PROJECT_ID` secrets

## After Creating the Bucket

Once the bucket is created, you can:

1. **Test locally** (if you have AWS credentials configured):
   ```bash
   packer init ubuntu-golden-image.pkr.hcl
   packer build -var-file=variables.pkrvars.hcl ubuntu-golden-image.pkr.hcl
   ```

2. **Run GitHub Actions workflow**:
   - Go to your repository → Actions
   - Run the "Build Ubuntu Golden Image" workflow
   - The build will publish metadata to your HCP Packer bucket

## Troubleshooting

**"Bucket not found" error:**
- Verify the bucket name matches exactly: `ubuntu-golden-image`
- Check you're in the correct organization/project
- Ensure your `HCP_PROJECT_ID` secret matches the project where you created the bucket

**"Access denied" error:**
- Verify your HCP credentials are correct
- Check your service principal has permissions to write to the bucket
- Ensure `HCP_ORGANIZATION_ID` and `HCP_PROJECT_ID` are correct

## Next Steps

After creating the bucket:
1. ✅ Bucket created in HCP Packer
2. ⏭️ Configure GitHub Secrets (if not done already)
3. ⏭️ Set up AWS OIDC (if not done already)
4. ⏭️ Run your first build!

