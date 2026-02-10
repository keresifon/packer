# Terraform VPC with SSM Support

This Terraform configuration creates a VPC in `us-east-1` with public and private subnets, configured for an image pipeline (e.g., Packer). Private instances get outbound internet via NAT Gateway for package installs and downloads, while SSM Session Manager access is provided via VPC endpoints (no bastion required).

## Architecture

```
Internet
    |
    v
Internet Gateway
    |
    v
Public Subnet (10.0.0.0/24) - NAT Gateway
    |
    v (0.0.0.0/0 -> NAT Gateway)
Private Subnet (10.0.1.0/24) - Packer/build instances
```

- **VPC**: `10.0.0.0/16` (configurable)
- **Public Subnet**: `10.0.0.0/24` - hosts NAT Gateway only
- **Private Subnet**: `10.0.1.0/24` - Packer EC2 instances (image pipeline)
- **NAT Gateway**: Enables outbound internet for package installs, updates, downloads
- **VPC Endpoints** (interface): SSM, SSM Messages, EC2 Messages (no bastion for access)
- **VPC Endpoint** (gateway): S3 for CIS tools and reports
- **Security Groups**:
  - VPC Endpoints SG (HTTPS from VPC)
  - Private Instances SG (outbound to VPC endpoints + internet via NAT)

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **Terraform** >= 1.0 installed locally (or use GitHub Actions)
3. **AWS Credentials** (for initial/bootstrap apply): Configure via `aws configure` or environment variables

## Local Usage

### Initialize Terraform

```bash
terraform init
```

### Plan Changes

```bash
terraform plan
```

### Apply Changes

```bash
terraform apply
```

### Destroy Infrastructure

```bash
terraform destroy
```

### Customize Variables

Create a `terraform.tfvars` file:

```hcl
aws_region          = "us-east-1"
project_name        = "my-vpc-ssm"
vpc_cidr            = "10.0.0.0/16"
public_subnet_cidr  = "10.0.0.0/24"
private_subnet_cidr = "10.0.1.0/24"
cis_tools_bucket    = "cis-tools-kere"
```

Or use command-line flags:

```bash
terraform apply -var="project_name=my-vpc-ssm" -var="vpc_cidr=10.0.0.0/16"
```

## GitHub Actions Usage

Authentication uses **OIDC** (no long-lived credentials). The workflow assumes an IAM role via `token.actions.githubusercontent.com`.

### OIDC Setup (Required First)

OIDC must be created **manually** before the pipeline can run, since the pipeline needs it for auth.

1. Create the OIDC provider and IAM role — see **`oidc/README.md`** for step-by-step AWS Console and CLI instructions.

2. Add repository variable:
   - Go to Repository → Settings → Secrets and variables → Actions → Variables
   - Add `AWS_ROLE_ARN` with the role ARN (e.g. `arn:aws:iam::123456789012:role/packer-vpc-ssm-github-actions-role`)

3. **(Optional) Remove secrets**: After OIDC works, remove `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` from Secrets.

### Run Workflow
   - Go to Actions → "Terraform VPC with SSM Support"
   - Click "Run workflow"
   - Select action: `plan`, `apply`, or `destroy`
   - Optionally set AWS region (default: `us-east-1`)
   - Click "Run workflow"

### Workflow Triggers

- **Manual**: `workflow_dispatch` - Run manually with action selection
- **Push**: Automatically runs `plan` on push to `terraform-vpc-ssm` branch
- **Pull Request**: Automatically runs `plan` on PRs

## Outputs

After applying, Terraform outputs:

- `vpc_id`: VPC ID
- `subnet_id`: Private Subnet ID (for Packer builds)
- `public_subnet_id`: Public Subnet ID (NAT Gateway)
- `security_group_ids`: Security Group ID for EC2 instances
- `iam_instance_profile`: IAM Instance Profile name
- `nat_gateway_id`: NAT Gateway ID
- `vpc_endpoints_security_group_id`: Security Group ID for VPC endpoints
- `ssm_endpoint_id`, `ssm_messages_endpoint_id`, `ec2_messages_endpoint_id`: VPC endpoint IDs
- `s3_endpoint_id`: S3 VPC Gateway Endpoint ID

## Using with Packer

After creating the VPC, use the outputs in your Packer build:

```bash
# Get outputs
VPC_ID=$(terraform output -raw vpc_id)
SUBNET_ID=$(terraform output -raw subnet_id)
SG_ID=$(terraform output -raw security_group_ids)

# Use in Packer
packer build \
  -var="vpc_id=$VPC_ID" \
  -var="subnet_id=$SUBNET_ID" \
  -var="security_group_ids=[\"$SG_ID\"]" \
  aws-golden-image.pkr.hcl
```

Or set GitHub repository variables:
- `VPC_ID`: Output from `terraform output -raw vpc_id`
- `SUBNET_ID`: Output from `terraform output -raw subnet_id`
- `SECURITY_GROUP_IDS`: Output from `terraform output -raw security_group_ids`
- `IAM_INSTANCE_PROFILE`: Output from `terraform output -raw iam_instance_profile`

## Cost Considerations

**NAT Gateway**:
- **Hourly**: ~$0.045/hour (~$32/month)
- **Data Processing**: $0.045 per GB processed

**VPC Endpoints (Interface)**:
- **Hourly**: ~$0.01 per endpoint per AZ (~$0.03/hour for 3 endpoints × 1 AZ = ~$22/month)
- **Data Processing**: $0.01 per GB processed

**VPC / Security Groups**: Free

**Total Estimated Cost**: ~$54-70/month (NAT + interface endpoints, depends on data transfer)

## Verification

After deployment, verify VPC endpoints:

```bash
# List VPC endpoints
aws ec2 describe-vpc-endpoints \
  --filters "Name=vpc-id,Values=$(terraform output -raw vpc_id)" \
  --region us-east-1 \
  --query 'VpcEndpoints[*].[VpcEndpointId,ServiceName,State]' \
  --output table

# Test SSM connectivity (launch an EC2 instance in private subnet first)
aws ssm start-session --target i-xxxxxxxxx --region us-east-1
```

## Troubleshooting

### VPC Endpoints Not Available

- Check VPC endpoint state: `aws ec2 describe-vpc-endpoints --vpc-endpoint-ids <endpoint-id>`
- Verify security group allows HTTPS (443) from VPC CIDR
- Check route tables have routes to VPC endpoints (automatically added by AWS)

### SSM Not Working

1. Verify VPC endpoints are in "available" state
2. Check EC2 instance has IAM role with `AmazonSSMManagedInstanceCore` policy
3. Verify security group allows outbound HTTPS (443)
4. Check VPC endpoint security groups allow inbound HTTPS from instance security group

### Terraform Apply Fails

- Verify AWS credentials are configured
- Check IAM permissions for VPC, Subnets, Route Tables, Security Groups, VPC Endpoints
- Ensure region is correct (`us-east-1`)

## Files

- `main.tf`: Data sources
- `vpc.tf`: VPC, subnets, route tables, Internet Gateway, NAT Gateway
- `security_groups.tf`: Security groups for VPC endpoints and private instances
- `vpc_endpoints.tf`: SSM, SSM Messages, EC2 Messages, and S3 VPC endpoints
- `iam.tf`: IAM role, policies, instance profile (for EC2/SSM)
- `oidc/README.md`: **Manual setup guide** for GitHub OIDC provider and IAM role (create before pipeline runs)
- `variables.tf`: Input variables
- `outputs.tf`: Output values
- `versions.tf`: Provider and Terraform version requirements
- `.github/workflows/infra.yml`: GitHub Actions workflow

## Next Steps

1. Apply Terraform configuration
2. Note the outputs (VPC ID, Subnet IDs, Security Group IDs)
3. Update Packer build with these values
4. Test Packer build with SSM Session Manager

