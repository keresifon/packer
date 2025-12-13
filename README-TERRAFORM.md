# Terraform VPC with SSM Support

This Terraform configuration creates a VPC in `us-east-1` with a single private subnet configured to support AWS Systems Manager (SSM) Session Manager via VPC endpoints.

## Architecture

- **VPC**: `10.0.0.0/16` (configurable)
- **Private Subnet**: `10.0.1.0/24` in Availability Zone 1
- **VPC Endpoints**:
  - SSM (`com.amazonaws.us-east-1.ssm`)
  - SSM Messages (`com.amazonaws.us-east-1.ssmmessages`)
  - EC2 Messages (`com.amazonaws.us-east-1.ec2messages`)
- **Security Groups**:
  - VPC Endpoints Security Group (allows HTTPS from VPC)
  - Private Instances Security Group (allows outbound HTTPS to VPC endpoints)

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **Terraform** >= 1.0 installed locally (or use GitHub Actions)
3. **AWS Credentials** configured (via `aws configure` or environment variables)
4. **GitHub Secrets** (for GitHub Actions):
   - `AWS_ACCESS_KEY_ID`: AWS access key ID
   - `AWS_SECRET_ACCESS_KEY`: AWS secret access key
   - `AWS_SESSION_TOKEN`: AWS session token (optional, for temporary credentials)

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
private_subnet_cidr = "10.0.1.0/24"
```

Or use command-line flags:

```bash
terraform apply -var="project_name=my-vpc-ssm" -var="vpc_cidr=10.0.0.0/16"
```

## GitHub Actions Usage

### Setup

1. **Configure GitHub Secrets**:
   - Go to Repository → Settings → Secrets and variables → Actions
   - Add secrets:
     - `AWS_ACCESS_KEY_ID`: Your AWS access key ID
     - `AWS_SECRET_ACCESS_KEY`: Your AWS secret access key
     - `AWS_SESSION_TOKEN`: (Optional) AWS session token if using temporary credentials

2. **Run Workflow**:
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

- `VPC_ID`: VPC ID
- `SUBNET_ID`: Private Subnet ID
- `SECURITY_GROUP_IDS`: Security Group ID for EC2 instances
- `IAM_INSTANCE_PROFILE`: IAM Instance Profile name
- `vpc_endpoints_security_group_id`: Security Group ID for VPC endpoints
- `ssm_endpoint_id`: SSM VPC Endpoint ID
- `ssm_messages_endpoint_id`: SSM Messages VPC Endpoint ID
- `ec2_messages_endpoint_id`: EC2 Messages VPC Endpoint ID

## Using with Packer

After creating the VPC, use the outputs in your Packer build:

```bash
# Get outputs
VPC_ID=$(terraform output -raw VPC_ID)
SUBNET_ID=$(terraform output -raw SUBNET_ID)
SG_ID=$(terraform output -raw SECURITY_GROUP_IDS)

# Use in Packer
packer build \
  -var="vpc_id=$VPC_ID" \
  -var="subnet_id=$SUBNET_ID" \
  -var="security_group_ids=[\"$SG_ID\"]" \
  aws-golden-image.pkr.hcl
```

Or set GitHub repository variables:
- `VPC_ID`: Output from `terraform output -raw VPC_ID`
- `SUBNET_ID`: Output from `terraform output -raw SUBNET_ID`
- `SECURITY_GROUP_IDS`: Output from `terraform output -raw SECURITY_GROUP_IDS`
- `IAM_INSTANCE_PROFILE`: Output from `terraform output -raw IAM_INSTANCE_PROFILE`

## Cost Considerations

**VPC Endpoints (Interface)**:
- **Hourly**: ~$0.01 per endpoint per AZ (~$0.06/hour for 3 endpoints × 2 AZs = ~$43/month)
- **Data Processing**: $0.01 per GB processed

**VPC**:
- Free (no additional charges)

**Security Groups**:
- Free

**Total Estimated Cost**: ~$43-50/month (depending on data transfer)

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

- `main.tf`: Main Terraform configuration
- `variables.tf`: Input variables
- `outputs.tf`: Output values
- `versions.tf`: Provider and Terraform version requirements
- `.github/workflows/terraform-vpc.yml`: GitHub Actions workflow

## Next Steps

1. Apply Terraform configuration
2. Note the outputs (VPC ID, Subnet IDs, Security Group IDs)
3. Update Packer build with these values
4. Test Packer build with SSM Session Manager

