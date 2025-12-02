# Example variables file
# Copy this to variables.pkrvars.hcl and fill in your values
# DO NOT commit variables.pkrvars.hcl to git

# AWS Configuration
# Note: AWS credentials are provided via environment/role (OIDC in GitHub Actions)
# For local development, configure AWS CLI or set environment variables:
#   export AWS_ACCESS_KEY_ID="your-access-key"
#   export AWS_SECRET_ACCESS_KEY="your-secret-key"
#   export AWS_DEFAULT_REGION="us-east-1"
aws_region         = "us-east-1"

# HCP Packer Configuration
hcp_client_id       = "YOUR_HCP_CLIENT_ID"
hcp_client_secret   = "YOUR_HCP_CLIENT_SECRET"
hcp_organization_id = "YOUR_HCP_ORG_ID"
hcp_project_id      = "YOUR_HCP_PROJECT_ID"

# Image Configuration
ubuntu_version   = "22.04"
instance_type    = "t3.micro"
image_name       = "ubuntu-golden-image"
hcp_bucket_name  = "ubuntu-golden-image"

