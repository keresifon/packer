# Amazon Linux 2023 VPC Private Subnet Setup

This guide explains how to configure the Packer build pipeline to create Amazon Linux 2023 AMIs in a private subnet without direct internet access.

## Overview

The Amazon Linux 2023 build uses:
- **SSM Session Manager** for remote access (no SSH keys required)
- **VPC and Private Subnet** for network isolation
- **VPC Endpoints** or **NAT Gateway** for outbound internet access
- **IAM Instance Profile** with SSM permissions

## Prerequisites

### 1. VPC Configuration

Your VPC must have:
- A **private subnet** (no direct internet gateway route)
- Route to **NAT Gateway** or **VPC Endpoints** for outbound internet access
- Proper security groups allowing SSM Session Manager traffic

### 2. VPC Endpoints (Recommended for Private Subnet)

For a truly airgapped private subnet, configure the following VPC endpoints:

#### Required VPC Endpoints:
- **com.amazonaws.region.ssm** - Systems Manager service
- **com.amazonaws.region.ssmmessages** - Systems Manager messages
- **com.amazonaws.region.ec2messages** - EC2 messages
- **com.amazonaws.region.ec2** - EC2 API calls
- **com.amazonaws.region.s3** - S3 access (for downloading packages/tools)
- **com.amazonaws.region.dynamodb** - DynamoDB (if using Parameter Store)

#### Optional VPC Endpoints (for package downloads):
- **com.amazonaws.region.ecr.dkr** - ECR Docker registry
- **com.amazonaws.region.ecr.api** - ECR API

### 3. IAM Instance Profile

Create an IAM instance profile with the following policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:UpdateInstanceInformation",
        "ssmmessages:CreateControlChannel",
        "ssmmessages:CreateDataChannel",
        "ssmmessages:OpenControlChannel",
        "ssmmessages:OpenDataChannel"
      ],
      "Resource": "*"
    }
  ]
}
```

Or attach the managed policy: **AmazonSSMManagedInstanceCore**

### 4. Security Group

The security group for the build instance must allow:
- **Outbound HTTPS (443)** to VPC endpoints or NAT Gateway
- **Outbound HTTP (80)** for package downloads (if not using VPC endpoints)

Note: SSM Session Manager doesn't require inbound rules - it uses AWS API calls.

## Configuration

### 1. Update `config/build-config.yml`

```yaml
vpc:
  # Your VPC ID
  vpc_id: "vpc-xxxxxxxxxxxxxxxxx"
  # Private subnet ID
  subnet_id: "subnet-xxxxxxxxxxxxxxxxx"
  # Security group IDs (optional - Packer will create one if not specified)
  security_group_ids: []
  # IAM instance profile name (required for SSM)
  iam_instance_profile: "packer-build-instance-profile"
```

### 2. Workflow Inputs

When running the workflow manually, you can override config values:

- **vpc_id**: VPC ID where build instance will be launched
- **subnet_id**: Private subnet ID
- **iam_instance_profile**: IAM instance profile name

### 3. Environment Variables

You can also set these via GitHub Actions secrets or environment variables:
- `PKR_VAR_vpc_id`
- `PKR_VAR_subnet_id`
- `PKR_VAR_iam_instance_profile`

## How It Works

1. **Packer launches instance** in your private subnet
2. **SSM Session Manager** establishes connection (no SSH keys)
3. **Instance downloads packages** via VPC endpoints or NAT Gateway
4. **Ansible runs** CIS hardening playbooks
5. **AMI is created** and stored in Parameter Store

## Troubleshooting

### Issue: Packer can't connect to instance

**Solution**: 
- Verify IAM instance profile has `AmazonSSMManagedInstanceCore` policy
- Check that VPC endpoints are configured (if using endpoints)
- Verify security group allows outbound HTTPS to VPC endpoints
- Ensure SSM agent is running: `sudo systemctl status amazon-ssm-agent`

### Issue: Instance can't download packages

**Solution**:
- Verify NAT Gateway route or VPC endpoints are configured
- Check security group allows outbound HTTPS (443)
- Test connectivity: `curl -I https://amazonlinux-2023-repos.s3.amazonaws.com`

### Issue: SSM Session Manager connection timeout

**Solution**:
- Ensure VPC endpoints for SSM are in the same VPC
- Verify DNS resolution works in private subnet
- Check that instance profile is attached correctly

## Network Architecture

```
┌─────────────────────────────────────────┐
│              VPC                         │
│  ┌───────────────────────────────────┐  │
│  │      Private Subnet               │  │
│  │  ┌─────────────────────────────┐ │  │
│  │  │  Packer Build Instance       │ │  │
│  │  │  - SSM Agent                 │ │  │
│  │  │  - IAM Instance Profile      │ │  │
│  │  └─────────────────────────────┘ │  │
│  │           │                       │  │
│  │           │ HTTPS (443)          │  │
│  └───────────┼───────────────────────┘  │
│              │                           │
│  ┌───────────▼───────────────────────┐  │
│  │  VPC Endpoints                    │  │
│  │  - SSM                            │  │
│  │  - S3                             │  │
│  │  - EC2                            │  │
│  └───────────────────────────────────┘  │
│                                           │
│  ┌───────────────────────────────────┐  │
│  │  NAT Gateway (Alternative)        │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

## Security Considerations

1. **No SSH Keys**: SSM Session Manager eliminates the need for SSH key management
2. **Private Subnet**: Build instances are not directly accessible from the internet
3. **IAM-Based Access**: Access is controlled via IAM roles and policies
4. **Audit Trail**: All SSM Session Manager sessions are logged in CloudTrail

## References

- [AWS Systems Manager Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)
- [VPC Endpoints](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints.html)
- [Packer SSM Session Manager](https://www.packer.io/docs/communicators/ssh#ssh_interface)


