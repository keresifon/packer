# AMI Distribution Documentation

## Overview

This document describes the multi-region AMI distribution process implemented in the GitHub Actions workflow. After an AMI is successfully built and validated, it is automatically copied to target regions and stored in AWS Systems Manager Parameter Store for easy reference.

## Distribution Process

### Workflow Steps

1. **Build Job** (`build`)
   - Builds the AMI in the primary region (default: `us-east-1`)
   - Extracts AMI ID from Packer output

2. **Validation Job** (`validate-ami`)
   - Validates the AMI in the primary region
   - Ensures AMI is ready for distribution

3. **Copy AMI Job** (`copy-ami`)
   - Runs automatically after successful validation
   - Copies AMI to target regions in parallel
   - Stores AMI IDs in Parameter Store
   - Tags copied AMIs with metadata

## Configuration

### Workflow Inputs

When triggering the workflow manually, you can configure:

- **`target_regions`**: Comma-separated list of target regions (default: `us-west-2,eu-west-1`)
- **`store_in_parameter_store`**: Whether to store AMI IDs in Parameter Store (default: `true`)

### Target Regions Configuration

Target regions are configured in `config/build-config.yml` under the `distribution` section. The workflow reads from this file unless overridden by manual input.

**Regions are configured in** `config/build-config.yml` under `distribution.target_regions` (no defaults).

### Changing Target Regions

#### Option 1: Edit Config File (Recommended)

Edit `config/build-config.yml` under the `distribution` section:

```yaml
distribution:
  target_regions:
    - us-west-2
    - eu-west-1
    - ap-southeast-1  # Add new region here
```

#### Option 2: Workflow Input (Manual Override)

When manually triggering the workflow:
1. Go to Actions → Build Ubuntu Golden Image → Run workflow
2. Set `target_regions` field (e.g., `us-west-2,eu-west-1,ap-southeast-1`)
3. This overrides the config file for that run only

**Important**: The config file is required. If `config/build-config.yml` is missing or the `distribution.target_regions` section is empty, the AMI copy job will be skipped.

See `config/README.md` for detailed configuration options.

## Parameter Store Structure

AMI IDs are stored in AWS Systems Manager Parameter Store with the following structure:

```
/packer/ubuntu-golden-image/<region>/latest
/packer/ubuntu-golden-image/<region>/<ami-name>
```

### Examples

- `/packer/ubuntu-golden-image/us-east-1/latest`
- `/packer/ubuntu-golden-image/us-east-1/ubuntu-golden-image-2025-01-15-1430`
- `/packer/ubuntu-golden-image/us-west-2/latest`
- `/packer/ubuntu-golden-image/eu-west-1/latest`

### Retrieving AMI IDs

#### AWS CLI

```bash
# Get latest AMI in us-west-2
aws ssm get-parameter \
  --name "/packer/ubuntu-golden-image/us-west-2/latest" \
  --query 'Parameter.Value' \
  --output text

# Get specific AMI by name
aws ssm get-parameter \
  --name "/packer/ubuntu-golden-image/us-west-2/ubuntu-golden-image-2025-01-15-1430" \
  --query 'Parameter.Value' \
  --output text
```

#### Terraform

```hcl
# Get latest AMI ID from Parameter Store
data "aws_ssm_parameter" "ami_us_west_2" {
  name = "/packer/ubuntu-golden-image/us-west-2/latest"
}

resource "aws_instance" "example" {
  ami           = data.aws_ssm_parameter.ami_us_west_2.value
  instance_type = "t3.micro"
}
```

#### CloudFormation

```yaml
Parameters:
  LatestAMI:
    Type: AWS::SSM::Parameter::Value<String>
    Default: /packer/ubuntu-golden-image/us-west-2/latest

Resources:
  MyInstance:
    Type: AWS::EC2::Instance
    Properties:
      ImageId: !Ref LatestAMI
      InstanceType: t3.micro
```

## AMI Copy Process

### What Happens

1. **Extract Source AMI Info**
   - Gets AMI ID and name from build job
   - Retrieves AMI metadata from source region

2. **Copy to Target Regions**
   - For each target region:
     - Calls `aws ec2 copy-image`
     - Creates new AMI in target region
     - Tags AMI with metadata (source region, source AMI ID, copy timestamp)

3. **Wait for Availability**
   - Waits for copied AMIs to become `available`
   - Uses `aws ec2 wait image-available`
   - Maximum wait: 60 attempts × 10 seconds = 10 minutes per region

4. **Store in Parameter Store**
   - Creates/updates parameters for each region
   - Stores both `latest` and named AMI IDs
   - Updates parameters in each region's Parameter Store

### Copy Duration

- **Copy Initiation**: ~1-2 seconds per region
- **AMI Availability**: ~5-15 minutes per region (depends on AMI size)
- **Total**: ~5-15 minutes for all regions (parallel execution)

### Cost Considerations

**AMI Copy Costs:**
- **Data Transfer**: ~$0.02 per GB transferred between regions
- **Storage**: Standard EBS snapshot costs apply
- **Example**: 20GB AMI copied to 2 regions = ~$0.80

**Parameter Store Costs:**
- **Standard Parameters**: Free (up to 10,000 parameters)
- **Advanced Parameters**: $0.05 per parameter per month (if using encryption)

## AMI Tags

Copied AMIs are automatically tagged with:

- **Name**: Original AMI name
- **SourceRegion**: Region where AMI was originally built
- **SourceAMI**: Source AMI ID
- **ManagedBy**: "Packer"
- **CopiedAt**: ISO 8601 timestamp of copy operation

## IAM Permissions Required

The GitHub Actions IAM role needs the following permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CopyImage",
        "ec2:DescribeImages",
        "ec2:CreateTags",
        "ec2:DescribeImageAttribute"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ssm:PutParameter",
        "ssm:GetParameter",
        "ssm:DeleteParameter"
      ],
      "Resource": "arn:aws:ssm:*:*:parameter/packer/ubuntu-golden-image/*"
    }
  ]
}
```

## Troubleshooting

### AMI Copy Fails

**Symptom**: Copy job fails with permission error

**Possible Causes**:
- Missing `ec2:CopyImage` permission
- Source AMI not available
- Target region not accessible

**Solution**: Check IAM permissions and verify source AMI status

### Parameter Store Update Fails

**Symptom**: AMI copied but Parameter Store update fails

**Possible Causes**:
- Missing `ssm:PutParameter` permission
- Parameter Store encryption key not accessible
- Parameter name too long

**Solution**: Check SSM permissions and parameter name length

### AMI Not Available After Copy

**Symptom**: Copy completes but AMI shows as "pending"

**Possible Causes**:
- Copy still in progress (normal)
- Snapshot copy taking longer than expected

**Solution**: Wait for AMI to become available (can take 10-15 minutes)

## Best Practices

1. **Region Selection**
   - Choose regions based on your actual usage
   - Consider data residency requirements
   - Balance cost vs. availability

2. **Parameter Store**
   - Use `/latest` for current AMI
   - Use named parameters for version tracking
   - Clean up old parameters periodically

3. **Cost Optimization**
   - Only copy to regions you actually use
   - Consider copying on-demand vs. every build
   - Monitor Parameter Store usage

4. **Version Tracking**
   - Use AMI names with timestamps
   - Keep Parameter Store parameters for version history
   - Document AMI versions in release notes

## Related Files

- `.github/workflows/build-image.yml` - GitHub Actions workflow
- `ubuntu-golden-image.pkr.hcl` - Packer template

