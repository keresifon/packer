# HCP Packer Permissions Check

## The Issue

If you don't see the option to create a bucket, it's likely a **permissions issue**, not a payment issue.

## HCP Packer Free Tier

✅ **HCP Packer has a FREE tier** that includes:
- Up to 10 artifact versions
- Basic bucket management
- No payment setup required for basic use

## Required Permissions

To create buckets manually, you need one of these roles:
- **Contributor** (project level) - Can create and manage buckets
- **Admin** (project level) - Full access

**Viewer role** does NOT have permission to create buckets.

## How to Check Your Permissions

1. **Go to HCP Portal**: https://portal.cloud.hashicorp.com
2. **Select your Organization** → **Project**
3. **Go to Access Control** → **Members** or **Roles**
4. **Check your role** for the project

## Solutions

### Option 1: Auto-Create (Recommended - No Permissions Needed!)

**Good news!** Your Packer template is configured to **auto-create the bucket** when you run your first build. You don't need manual bucket creation!

Just run your GitHub Actions workflow or local build, and the bucket will be created automatically.

### Option 2: Request Permissions

If you want to create buckets manually:
1. Contact your HCP organization administrator
2. Request **Contributor** or **Admin** role for your project
3. Once granted, you'll see the "Create bucket" option

### Option 3: Use HCP CLI

If you have CLI access but not UI access:
```bash
hcp packer buckets create ubuntu-golden-image
```

## Verify Your Setup

To check if everything is ready:

1. **HCP Credentials**: Do you have `HCP_CLIENT_ID` and `HCP_CLIENT_SECRET`?
2. **HCP Project**: Do you have `HCP_PROJECT_ID`?
3. **Permissions**: Can you see the Packer section in HCP Portal?

## Next Steps

Since buckets auto-create, you can:

1. ✅ **Skip manual bucket creation** - Just run your build!
2. ✅ **Set up GitHub Secrets** with your HCP credentials
3. ✅ **Run the workflow** - The bucket will be created automatically

The first build will:
- Create the bucket `ubuntu-golden-image` automatically
- Build your AMI
- Publish metadata to HCP Packer

## Still Having Issues?

If you can't see Packer at all in HCP Portal:
- Verify you're in the correct organization/project
- Check if Packer is enabled for your project
- Contact HCP support or your organization admin

