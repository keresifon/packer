# AWS OIDC Setup for GitHub Actions

This guide explains how to configure OpenID Connect (OIDC) authentication between GitHub Actions and AWS, eliminating the need to store AWS access keys as secrets.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Step 1: Create OIDC Identity Provider](#step-1-create-oidc-identity-provider)
4. [Step 2: Create IAM Role](#step-2-create-iam-role)
5. [Step 3: Configure Trust Policy](#step-3-configure-trust-policy)
6. [Step 4: Attach Permissions Policy](#step-4-attach-permissions-policy)
7. [Step 5: Configure GitHub Secret](#step-5-configure-github-secret)
8. [Step 6: Verify Setup](#step-6-verify-setup)
9. [Required IAM Permissions](#required-iam-permissions)
10. [Troubleshooting](#troubleshooting)

## Overview

OIDC allows GitHub Actions to assume an AWS IAM role without storing long-lived credentials. The workflow uses short-lived credentials that are automatically rotated.

**Benefits:**
- ✅ No AWS access keys stored in GitHub Secrets
- ✅ Automatic credential rotation
- ✅ Fine-grained access control via IAM roles
- ✅ Audit trail via CloudTrail
- ✅ Can restrict access by repository, branch, or environment

## Prerequisites

- AWS Account with appropriate permissions to create IAM resources
- GitHub repository with Actions enabled
- AWS CLI installed (optional, for verification)

## Step 1: Create OIDC Identity Provider

### Option A: Using AWS Console

1. Navigate to **IAM** → **Identity providers**
2. Click **Add provider**
3. Select **OpenID Connect**
4. Configure:
   - **Provider URL**: `https://token.actions.githubusercontent.com`
   - **Audience**: `sts.amazonaws.com`
5. Click **Add provider**

### Option B: Using AWS CLI

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

**Note:** The thumbprint may need to be updated. See [AWS Documentation](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc_verify-thumbprint.html) for current thumbprints.

## Step 2: Create IAM Role

### Using AWS Console

1. Navigate to **IAM** → **Roles**
2. Click **Create role**
3. Select **Web identity**
4. Choose the identity provider created in Step 1:
   - **Identity provider**: `token.actions.githubusercontent.com`
   - **Audience**: `sts.amazonaws.com`
5. Click **Next**

### Using AWS CLI

```bash
aws iam create-role \
  --role-name GitHubActionsPackerRole \
  --assume-role-policy-document file://trust-policy.json
```

## Step 3: Configure Trust Policy

The trust policy defines which GitHub repositories can assume the role.

### Basic Trust Policy (Single Repository)

Create a file `trust-policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_ORG/YOUR_REPO_NAME:*"
        }
      }
    }
  ]
}
```

**Replace:**
- `ACCOUNT_ID`: Your AWS Account ID
- `YOUR_GITHUB_ORG`: Your GitHub organization or username
- `YOUR_REPO_NAME`: Your repository name

### Advanced Trust Policy (Multiple Repositories)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": [
            "repo:YOUR_GITHUB_ORG/packer:*",
            "repo:YOUR_GITHUB_ORG/other-repo:*"
          ]
        }
      }
    }
  ]
}
```

### Restrict by Branch (Optional)

To restrict access to specific branches:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_ORG/YOUR_REPO_NAME:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

### Restrict by Environment (Optional)

For GitHub Environments:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:env": "production"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_ORG/YOUR_REPO_NAME:*"
        }
      }
    }
  ]
}
```

### Apply Trust Policy

**Using AWS Console:**
1. Go to the role created in Step 2
2. Click **Trust relationships** tab
3. Click **Edit trust policy**
4. Paste the JSON policy
5. Click **Update policy**

**Using AWS CLI:**
```bash
aws iam update-assume-role-policy \
  --role-name GitHubActionsPackerRole \
  --policy-document file://trust-policy.json
```

## Step 4: Attach Permissions Policy

The IAM role needs permissions to perform all actions required by the Packer pipeline.

### Required Permissions Policy

Create a file `permissions-policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "EC2InstanceManagement",
      "Effect": "Allow",
      "Action": [
        "ec2:RunInstances",
        "ec2:DescribeInstances",
        "ec2:DescribeInstanceStatus",
        "ec2:DescribeInstanceAttribute",
        "ec2:TerminateInstances",
        "ec2:StopInstances",
        "ec2:StartInstances",
        "ec2:RebootInstances",
        "ec2:GetConsoleOutput",
        "ec2:GetConsoleScreenshot"
      ],
      "Resource": "*"
    },
    {
      "Sid": "EC2ImageManagement",
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeImages",
        "ec2:DescribeImageAttribute",
        "ec2:CreateImage",
        "ec2:CopyImage",
        "ec2:DeregisterImage",
        "ec2:ModifyImageAttribute",
        "ec2:DescribeSnapshots",
        "ec2:CreateSnapshot",
        "ec2:DeleteSnapshot",
        "ec2:ModifySnapshotAttribute",
        "ec2:DescribeSnapshotAttribute"
      ],
      "Resource": "*"
    },
    {
      "Sid": "EC2SecurityGroupManagement",
      "Effect": "Allow",
      "Action": [
        "ec2:CreateSecurityGroup",
        "ec2:DeleteSecurityGroup",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeSecurityGroupRules",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:AuthorizeSecurityGroupEgress",
        "ec2:RevokeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupEgress",
        "ec2:UpdateSecurityGroupRuleDescriptionsIngress",
        "ec2:UpdateSecurityGroupRuleDescriptionsEgress"
      ],
      "Resource": "*"
    },
    {
      "Sid": "EC2KeyPairManagement",
      "Effect": "Allow",
      "Action": [
        "ec2:CreateKeyPair",
        "ec2:DeleteKeyPair",
        "ec2:DescribeKeyPairs",
        "ec2:ImportKeyPair"
      ],
      "Resource": "*"
    },
    {
      "Sid": "EC2TagManagement",
      "Effect": "Allow",
      "Action": [
        "ec2:CreateTags",
        "ec2:DeleteTags",
        "ec2:DescribeTags"
      ],
      "Resource": "*"
    },
    {
      "Sid": "EC2VolumeManagement",
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeVolumes",
        "ec2:DescribeVolumeStatus",
        "ec2:DescribeVolumeAttribute",
        "ec2:AttachVolume",
        "ec2:DetachVolume",
        "ec2:ModifyVolume",
        "ec2:ModifyVolumeAttribute"
      ],
      "Resource": "*"
    },
    {
      "Sid": "EC2NetworkManagement",
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeVpcs",
        "ec2:DescribeSubnets",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DescribeNetworkAcls",
        "ec2:DescribeRouteTables",
        "ec2:DescribeInternetGateways",
        "ec2:DescribeVpcAttribute",
        "ec2:DescribeSubnetAttribute",
        "ec2:AllocateAddress",
        "ec2:ReleaseAddress",
        "ec2:AssociateAddress",
        "ec2:DisassociateAddress",
        "ec2:DescribeAddresses"
      ],
      "Resource": "*"
    },
    {
      "Sid": "EC2WaitActions",
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeInstances",
        "ec2:DescribeImages",
        "ec2:DescribeSnapshots"
      ],
      "Resource": "*"
    },
    {
      "Sid": "SystemsManagerParameterStore",
      "Effect": "Allow",
      "Action": [
        "ssm:PutParameter",
        "ssm:GetParameter",
        "ssm:GetParameters",
        "ssm:GetParametersByPath",
        "ssm:DeleteParameter",
        "ssm:DeleteParameters",
        "ssm:DescribeParameters",
        "ssm:AddTagsToResource",
        "ssm:RemoveTagsFromResource",
        "ssm:ListTagsForResource"
      ],
      "Resource": [
        "arn:aws:ssm:*:*:parameter/packer/ubuntu-golden-image/*"
      ]
    },
    {
      "Sid": "IAMPassRoleForEC2",
      "Effect": "Allow",
      "Action": [
        "iam:PassRole"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "iam:PassedToService": "ec2.amazonaws.com"
        }
      }
    }
  ]
}
```

**Note:** Replace `packer/ubuntu-golden-image` with your Parameter Store base path from `config/build-config.yml` if different.

### Apply Permissions Policy

**Using AWS Console:**
1. Go to the role created in Step 2
2. Click **Add permissions** → **Create inline policy**
3. Click **JSON** tab
4. Paste the permissions policy JSON
5. Click **Review policy**
6. Name: `GitHubActionsPackerPermissions`
7. Click **Create policy**

**Using AWS CLI:**
```bash
aws iam put-role-policy \
  --role-name GitHubActionsPackerRole \
  --policy-name GitHubActionsPackerPermissions \
  --policy-document file://permissions-policy.json
```

### Alternative: Use AWS Managed Policies (Less Secure)

If you prefer managed policies (less granular but easier):

```bash
aws iam attach-role-policy \
  --role-name GitHubActionsPackerRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess

aws iam attach-role-policy \
  --role-name GitHubActionsPackerRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonSSMFullAccess
```

**⚠️ Warning:** Managed policies grant broader permissions than necessary. Use the custom policy above for better security.

## Step 5: Configure GitHub Secret

1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Configure:
   - **Name**: `AWS_ROLE_ARN`
   - **Value**: `arn:aws:iam::ACCOUNT_ID:role/GitHubActionsPackerRole`
5. Click **Add secret**

**Replace `ACCOUNT_ID`** with your AWS Account ID.

### Finding Your Role ARN

**Using AWS Console:**
1. Go to **IAM** → **Roles**
2. Click on `GitHubActionsPackerRole`
3. Copy the **ARN** from the role summary

**Using AWS CLI:**
```bash
aws iam get-role --role-name GitHubActionsPackerRole --query 'Role.Arn' --output text
```

## Step 6: Verify Setup

### Test the Connection

1. Trigger a workflow run manually:
   - Go to **Actions** → **Build Ubuntu Golden Image** → **Run workflow**
2. Check the workflow logs for:
   - ✅ "Successfully assumed role"
   - ✅ No authentication errors

### Verify with AWS CLI (Optional)

Test the role assumption manually:

```bash
# Get GitHub OIDC token (requires GitHub CLI)
gh auth refresh -s read:packages

# Assume the role
aws sts assume-role-with-web-identity \
  --role-arn arn:aws:iam::ACCOUNT_ID:role/GitHubActionsPackerRole \
  --role-session-name github-actions-test \
  --web-identity-token YOUR_GITHUB_TOKEN
```

## Required IAM Permissions

### Summary of Required Actions

The IAM role needs permissions for the following AWS services:

#### EC2 (Elastic Compute Cloud)
- **Instance Management**: Launch, describe, terminate instances
- **Image Management**: Describe, create, copy, deregister AMIs
- **Snapshot Management**: Create, describe, delete snapshots
- **Security Groups**: Create, delete, authorize ingress/egress
- **Key Pairs**: Create, delete, describe key pairs
- **Tags**: Create and manage tags on resources
- **Volumes**: Describe and manage EBS volumes
- **Network**: Describe VPCs, subnets, network interfaces

#### Systems Manager Parameter Store
- **Parameters**: Put, get, delete parameters
- **Tags**: Add/remove tags on parameters

#### IAM
- **PassRole**: Allow passing IAM roles to EC2 instances (if needed)

### Permission Breakdown by Workflow Step

| Workflow Step | Required Permissions |
|--------------|---------------------|
| **Packer Build** | `ec2:RunInstances`, `ec2:CreateImage`, `ec2:CreateSnapshot`, `ec2:CreateTags`, `ec2:Describe*` |
| **AMI Validation** | `ec2:RunInstances`, `ec2:CreateSecurityGroup`, `ec2:CreateKeyPair`, `ec2:AuthorizeSecurityGroupIngress`, `ec2:DescribeInstances`, `ec2:TerminateInstances`, `ec2:DeleteSecurityGroup`, `ec2:DeleteKeyPair` |
| **AMI Copy** | `ec2:CopyImage`, `ec2:CreateTags`, `ec2:DescribeImages`, `ec2:WaitImageAvailable` |
| **Parameter Store** | `ssm:PutParameter`, `ssm:GetParameter`, `ssm:DescribeParameters` |

## Troubleshooting

### Common Issues

#### 1. "Access Denied" Errors

**Problem:** Role doesn't have sufficient permissions.

**Solution:**
- Verify the permissions policy is attached correctly
- Check CloudTrail logs for specific denied actions
- Ensure all required actions are included in the policy

#### 2. "Not authorized to perform sts:AssumeRoleWithWebIdentity"

**Problem:** Trust policy is incorrect or identity provider not configured.

**Solution:**
- Verify the OIDC identity provider exists
- Check the trust policy matches your repository name exactly
- Ensure the audience is `sts.amazonaws.com`

#### 3. "Invalid identity token"

**Problem:** GitHub token format or audience mismatch.

**Solution:**
- Verify `id-token: write` permission is set in workflow
- Check the audience in trust policy matches `sts.amazonaws.com`
- Ensure using `aws-actions/configure-aws-credentials@v4` or later

#### 4. "Repository not authorized"

**Problem:** Trust policy doesn't match repository name.

**Solution:**
- Verify repository name in trust policy: `repo:ORG/REPO:*`
- Check for typos or case sensitivity issues
- Use `StringLike` for wildcard matching

#### 5. Parameter Store Access Denied

**Problem:** Parameter Store path doesn't match policy.

**Solution:**
- Verify Parameter Store path in `config/build-config.yml`
- Update IAM policy resource ARN to match: `arn:aws:ssm:*:*:parameter/packer/ubuntu-golden-image/*`
- Ensure path starts with `/packer/ubuntu-golden-image/`

### Debugging Steps

1. **Check CloudTrail Logs:**
   ```bash
   aws cloudtrail lookup-events \
     --lookup-attributes AttributeKey=EventName,AttributeValue=AssumeRoleWithWebIdentity \
     --max-results 10
   ```

2. **Verify Role Trust Policy:**
   ```bash
   aws iam get-role --role-name GitHubActionsPackerRole \
     --query 'Role.AssumeRolePolicyDocument'
   ```

3. **Check Role Permissions:**
   ```bash
   aws iam list-role-policies --role-name GitHubActionsPackerRole
   aws iam get-role-policy --role-name GitHubActionsPackerRole \
     --policy-name GitHubActionsPackerPermissions
   ```

4. **Test Permissions:**
   ```bash
   # After assuming the role, test specific permissions
   aws ec2 describe-images --owners self
   aws ssm get-parameter --name /packer/ubuntu-golden-image/us-east-1/latest
   ```

### Security Best Practices

1. **Principle of Least Privilege:**
   - Only grant permissions needed for the pipeline
   - Use resource-level permissions where possible
   - Regularly review and audit permissions

2. **Restrict by Repository:**
   - Use specific repository names in trust policy
   - Avoid wildcards (`*`) unless necessary
   - Consider using GitHub Environments for production

3. **Restrict by Branch (Optional):**
   - Limit role assumption to specific branches
   - Use separate roles for different environments

4. **Monitor Access:**
   - Enable CloudTrail logging
   - Set up CloudWatch alarms for failed assumptions
   - Review access logs regularly

5. **Rotate Credentials:**
   - OIDC tokens are short-lived (1 hour)
   - No manual rotation needed
   - Consider rotating the role ARN secret periodically

## Additional Resources

- [AWS IAM OIDC Identity Providers](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)
- [GitHub Actions OIDC Documentation](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [AWS configure-aws-credentials Action](https://github.com/aws-actions/configure-aws-credentials)
- [AWS IAM Policy Reference](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_actions-resources-contextkeys.html)

## Quick Reference

### Trust Policy Template
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
      },
      "StringLike": {
        "token.actions.githubusercontent.com:sub": "repo:ORG/REPO:*"
      }
    }
  }]
}
```

### GitHub Secret
- **Name**: `AWS_ROLE_ARN`
- **Value**: `arn:aws:iam::ACCOUNT_ID:role/GitHubActionsPackerRole`

### Workflow Configuration
```yaml
permissions:
  id-token: write  # Required for OIDC
  contents: read

steps:
  - uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
      aws-region: us-east-1
```

