# Amazon Linux 2023 Golden Image Build

This branch contains the configuration to build hardened Amazon Linux 2023 AMIs using Packer in a VPC private subnet environment.

## What's New

- ✅ Amazon Linux 2023 Packer template (`amazonlinux2023-golden-image.pkr.hcl`)
- ✅ SSM Session Manager support (no SSH keys required)
- ✅ VPC and private subnet configuration
- ✅ GitHub Actions workflow for CI/CD
- ✅ Parameter Store integration for AMI distribution
- ✅ CIS Level 2 hardening support

## Quick Start

### 1. Configure Your Infrastructure

Update `config/build-config.yml` with your VPC details:

```yaml
vpc:
  vpc_id: "vpc-xxxxxxxxxxxxxxxxx"
  subnet_id: "subnet-xxxxxxxxxxxxxxxxx"
  iam_instance_profile: "packer-build-instance-profile"
```

### 2. Set Up VPC Endpoints (Required for Private Subnet)

Your private subnet needs VPC endpoints for:
- SSM (Systems Manager)
- S3 (for package downloads)
- EC2 (for API calls)

See [AMAZONLINUX2023-VPC-SETUP.md](docs/AMAZONLINUX2023-VPC-SETUP.md) for detailed setup instructions.

### 3. Create IAM Instance Profile

The instance profile must have the `AmazonSSMManagedInstanceCore` managed policy attached.

### 4. Run the Build

#### Via GitHub Actions:
1. Go to Actions → "Build Amazon Linux 2023 Golden Image"
2. Click "Run workflow"
3. Fill in VPC ID, Subnet ID, and IAM Instance Profile
4. Click "Run workflow"

#### Via Command Line:
```bash
packer build \
  -var="vpc_id=vpc-xxxxxxxxx" \
  -var="subnet_id=subnet-xxxxxxxxx" \
  -var="iam_instance_profile=your-profile-name" \
  amazonlinux2023-golden-image.pkr.hcl
```

## Files Structure

```
.
├── amazonlinux2023-golden-image.pkr.hcl  # Packer template
├── config/
│   └── build-config.yml                  # Build configuration
├── .github/workflows/
│   └── build-amazonlinux2023.yml         # CI/CD workflow
├── docs/
│   └── AMAZONLINUX2023-VPC-SETUP.md      # Setup guide
└── ansible/                               # CIS hardening playbooks
```

## Key Features

### SSM Session Manager
- No SSH keys required
- Secure connection via AWS Systems Manager
- Works in private subnets without direct internet access

### VPC Private Subnet
- Build instances launched in isolated private subnet
- Uses VPC endpoints or NAT Gateway for outbound access
- Enhanced security posture

### CIS Hardening
- CIS Level 2 benchmarks applied via Ansible
- Compliance reporting
- Configurable thresholds

### Parameter Store Integration
- AMI IDs automatically stored in Parameter Store
- Multi-region support
- Easy integration with Terraform/CloudFormation

## Differences from Ubuntu Build

1. **OS**: Amazon Linux 2023 instead of Ubuntu
2. **Package Manager**: DNF instead of APT
3. **SSH User**: `ec2-user` instead of `ubuntu`
4. **Block Device**: `/dev/xvda` instead of `/dev/sda1`
5. **SSM**: Uses Session Manager instead of SSH keys

## Configuration Options

### Build Configuration (`config/build-config.yml`)

- **VPC Settings**: VPC ID, subnet ID, security groups, IAM instance profile
- **Instance Settings**: Instance type, volume configuration
- **CIS Settings**: Compliance level, thresholds
- **Parameter Store**: Base path, enabled/disabled
- **Distribution**: Target regions for AMI copying

### Workflow Inputs

- `vpc_id`: Override VPC ID from config
- `subnet_id`: Override subnet ID from config
- `iam_instance_profile`: Override IAM instance profile
- `target_regions`: Override target regions for copying
- `store_in_parameter_store`: Enable/disable Parameter Store

## Troubleshooting

See [AMAZONLINUX2023-VPC-SETUP.md](docs/AMAZONLINUX2023-VPC-SETUP.md) for troubleshooting guide.

Common issues:
- **SSM Connection Failed**: Check IAM instance profile permissions
- **Package Download Failed**: Verify VPC endpoints or NAT Gateway
- **Build Timeout**: Check security groups and network routes

## Next Steps

1. Review and update `config/build-config.yml` with your VPC details
2. Ensure VPC endpoints are configured
3. Create IAM instance profile with SSM permissions
4. Test the build workflow
5. Review CIS compliance reports

## References

- [Packer Documentation](https://www.packer.io/docs)
- [AWS Systems Manager Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)
- [VPC Endpoints](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints.html)
- [CIS Amazon Linux 2023 Benchmark](https://www.cisecurity.org/benchmark/amazon_linux)


