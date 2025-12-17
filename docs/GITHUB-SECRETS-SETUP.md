# GitHub Secrets and Variables Setup

This guide explains how to configure GitHub secrets and variables for the Amazon Linux 2023 build pipeline.

## Required GitHub Secrets

The following secrets must be configured in your GitHub repository:

### AWS Credentials

1. **`AWS_ACCESS_KEY_ID`** (Required)
   - Your AWS access key ID
   - Go to: Settings → Secrets and variables → Actions → New repository secret

2. **`AWS_SECRET_ACCESS_KEY`** (Required)
   - Your AWS secret access key
   - Go to: Settings → Secrets and variables → Actions → New repository secret

3. **`AWS_SESSION_TOKEN`** (Optional)
   - AWS session token (required only if using temporary credentials)
   - Leave empty if using permanent IAM user credentials
   - Go to: Settings → Secrets and variables → Actions → New repository secret

## Required GitHub Variables

The following variables can be configured as either **Variables** (visible) or **Secrets** (hidden):

### VPC Configuration

1. **`VPC_ID`** (Required)
   - Your VPC ID (e.g., `vpc-027970a88dd594869`)
   - Can be set as Variable or Secret
   - Go to: Settings → Secrets and variables → Actions → Variables tab → New repository variable

2. **`SUBNET_ID`** (Required)
   - Your private subnet ID (e.g., `subnet-0a5f62548c271cf0f`)
   - Can be set as Variable or Secret
   - Go to: Settings → Secrets and variables → Actions → Variables tab → New repository variable

3. **`SECURITY_GROUP_IDS`** (Optional)
   - Comma-separated list of security group IDs (e.g., `sg-015ad465f0003045a`)
   - Or JSON array format: `["sg-015ad465f0003045a"]`
   - Can be set as Variable or Secret
   - Go to: Settings → Secrets and variables → Actions → Variables tab → New repository variable

4. **`IAM_INSTANCE_PROFILE`** (Required)
   - IAM instance profile name (e.g., `packer-ssm-instance-profile`)
   - Must have `AmazonSSMManagedInstanceCore` policy attached
   - Can be set as Variable or Secret
   - Go to: Settings → Secrets and variables → Actions → Variables tab → New repository variable

## Priority Order

The pipeline uses the following priority order for configuration:

1. **GitHub Variables/Secrets** (highest priority)
2. **GitHub Workflow Inputs** (if provided)
3. **Config File** (`config/build-config.yml`) (fallback)

## Setup Instructions

### Step 1: Configure AWS Credentials

1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add the following secrets:
   - Name: `AWS_ACCESS_KEY_ID`, Value: `your-access-key-id`
   - Name: `AWS_SECRET_ACCESS_KEY`, Value: `your-secret-access-key`
   - Name: `AWS_SESSION_TOKEN`, Value: `your-session-token` (optional, only if using temporary credentials)

### Step 2: Configure VPC Variables

1. In the same **Secrets and variables** → **Actions** page
2. Click on the **Variables** tab
3. Click **New repository variable**
4. Add the following variables:
   - Name: `VPC_ID`, Value: `vpc-xxxxxxxxxxxxxxxxx`
   - Name: `SUBNET_ID`, Value: `subnet-xxxxxxxxxxxxxxxxx`
   - Name: `SECURITY_GROUP_IDS`, Value: `sg-xxxxxxxxxxxxxxxxx` (or comma-separated: `sg-xxx,sg-yyy`)
   - Name: `IAM_INSTANCE_PROFILE`, Value: `your-instance-profile-name`

### Step 3: Verify Configuration

After setting up secrets and variables, you can verify by:

1. Running the workflow manually
2. Checking the workflow logs for:
   - `✅ AWS credentials configured`
   - `✅ Using VPC: vpc-xxx`
   - `✅ Using subnet: subnet-xxx`
   - `✅ Using IAM instance profile: xxx`

## Security Best Practices

1. **Use Secrets for Sensitive Data**: Always use Secrets (not Variables) for:
   - AWS credentials
   - Any sensitive configuration

2. **Use Variables for Non-Sensitive Data**: Use Variables for:
   - VPC IDs (if not sensitive)
   - Subnet IDs (if not sensitive)
   - Instance profile names (if not sensitive)

3. **Rotate Credentials Regularly**: Regularly rotate your AWS access keys

4. **Use IAM Roles When Possible**: Consider using OIDC with IAM roles instead of access keys for better security

5. **Limit Permissions**: Ensure your AWS credentials have only the minimum required permissions:
   - EC2: Launch, describe, terminate instances
   - SSM: Session Manager access
   - S3: Read access for packages (if using VPC endpoints)
   - Parameter Store: Read/Write access (if using Parameter Store)

## Example IAM Policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeImages",
        "ec2:DescribeInstances",
        "ec2:RunInstances",
        "ec2:TerminateInstances",
        "ec2:CreateTags",
        "ec2:CreateImage",
        "ec2:CopyImage",
        "ec2:DescribeSnapshots",
        "ec2:CreateSnapshot",
        "ec2:ModifyImageAttribute",
        "ec2:DescribeSecurityGroups",
        "ssm:StartSession",
        "ssm:DescribeInstanceInformation",
        "ssm:GetCommandInvocation",
        "ssm:SendCommand",
        "ssm:ListCommandInvocations",
        "ssm:PutParameter",
        "ssm:GetParameter",
        "ssm:GetParameters"
      ],
      "Resource": "*"
    }
  ]
}
```

## Troubleshooting

### Error: AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY must be set

**Solution**: Ensure both secrets are configured in GitHub repository settings.

### Error: Failed to authenticate with AWS

**Solution**: 
- Verify your AWS credentials are correct
- Check if your credentials have expired (if using temporary credentials)
- Ensure `AWS_SESSION_TOKEN` is set if using temporary credentials

### Error: VPC_ID not set

**Solution**: 
- Set `VPC_ID` as a GitHub variable or secret
- Or configure it in `config/build-config.yml` as a fallback

### Error: iam_instance_profile is required

**Solution**: 
- Set `IAM_INSTANCE_PROFILE` as a GitHub variable or secret
- Ensure the instance profile exists and has `AmazonSSMManagedInstanceCore` policy

## References

- [GitHub Secrets Documentation](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [GitHub Variables Documentation](https://docs.github.com/en/actions/learn-github-actions/variables)
- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)


