# CIS Level 2 Hardening for Amazon Linux 2023

This document describes how to implement CIS (Center for Internet Security) Level 2 hardening for Amazon Linux 2023 golden images using Packer.

## Overview

The CIS hardening implementation includes:
- **CIS Level 2 Hardening Scripts**: Automated implementation of CIS benchmark controls
- **S3-based CIS Tools**: Download and run CIS assessment tools from S3
- **Compliance Verification**: Automated assessment to verify hardening compliance

## Prerequisites

1. **S3 Bucket**: An S3 bucket to store CIS tools
2. **VPC Endpoints**: S3 Gateway Endpoint configured for private subnet access
3. **IAM Permissions**: Instance profile with S3 read permissions for CIS tools bucket
4. **CIS Tools**: CIS assessment tools (CIS-CAT, CIS Workbench, etc.) uploaded to S3

## S3 Bucket Structure

Upload CIS tools to your S3 bucket with the following structure:

```
s3://your-cis-bucket/
└── cis-tools/
    ├── cis-cat-full/
    │   ├── CIS-CAT.sh
    │   ├── Assessor-CLI.sh
    │   └── ... (other CIS-CAT files)
    ├── cis-workbench/
    │   ├── assess.sh
    │   └── ... (other workbench files)
    └── ... (other CIS tools)
```

### Required S3 Permissions

The EC2 instance profile needs the following S3 permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::your-cis-bucket",
        "arn:aws:s3:::your-cis-bucket/cis-tools/*"
      ]
    }
  ]
}
```

## Configuration

### Packer Variables

Add the following variables to your Packer build:

```hcl
cis_s3_bucket      = "your-cis-bucket-name"
cis_s3_prefix      = "cis-tools"  # Optional, defaults to "cis-tools"
enable_cis_hardening = true        # Optional, defaults to true
```

### GitHub Actions Workflow

Set the following GitHub repository variables:

- `CIS_S3_BUCKET`: S3 bucket name containing CIS tools
- `CIS_S3_PREFIX`: S3 prefix/path (default: `cis-tools`)

Or pass them as Packer variables:

```yaml
PKR_VAR_cis_s3_bucket: ${{ vars.CIS_S3_BUCKET || '' }}
PKR_VAR_cis_s3_prefix: ${{ vars.CIS_S3_PREFIX || 'cis-tools' }}
PKR_VAR_enable_cis_hardening: true
```

## CIS Tools Setup

### Option 1: Download CIS-CAT (Recommended)

1. **Download CIS-CAT**:
   - Visit: https://www.cisecurity.org/cybersecurity-tools/cis-cat-pro/
   - Download CIS-CAT Full (requires CIS Workbench account)
   - Extract the archive

2. **Upload to S3**:
   ```bash
   aws s3 sync ./cis-cat-full/ s3://your-cis-bucket/cis-tools/cis-cat-full/
   ```

### Option 2: Use CIS Workbench Scripts

1. **Download CIS Workbench**:
   - Visit: https://www.cisecurity.org/cybersecurity-tools/cis-workbench/
   - Download Amazon Linux 2023 benchmark scripts
   - Extract the archive

2. **Upload to S3**:
   ```bash
   aws s3 sync ./cis-workbench/ s3://your-cis-bucket/cis-tools/cis-workbench/
   ```

### Option 3: Manual Hardening Only

If you don't want to use CIS assessment tools, you can skip S3 bucket configuration. The hardening scripts will still run, but assessment will be skipped.

## Hardening Process

The Packer build process includes the following steps:

1. **System Updates**: Update and upgrade system packages
2. **Common Packages**: Install common utilities (curl, wget, git, etc.)
3. **SSM Agent**: Install and configure SSM Agent
4. **AWS CLI**: Install AWS CLI (required for S3 access)
5. **CIS Tools Download**: Download CIS tools from S3 (if bucket configured)
6. **CIS Hardening**: Apply CIS Level 2 hardening controls
7. **CIS Assessment**: Run CIS assessment tools (if available)
8. **SSH Configuration**: Configure SSH hardening
9. **Cleanup**: Clean up temporary files and caches

## CIS Level 2 Controls Implemented

The hardening script implements the following CIS Level 2 controls:

### 1. Initial Setup
- Filesystem configuration
- Filesystem integrity checking (AIDE)
- Secure boot settings
- Additional process hardening
- Mandatory Access Control (SELinux)
- Command line warning banners

### 2. Services
- inetd services removal
- Special purpose services configuration
- Service clients removal

### 3. Network Configuration
- Network parameters (IPv4/IPv6)
- Firewall configuration (firewalld)
- Logging and auditing

### 4. Logging and Auditing
- System accounting (auditd)
- Logging configuration (rsyslog)

### 5. Access, Authentication and Authorization
- Configure cron
- SSH server configuration (comprehensive)
- Configure PAM
- User accounts and environment

### 6. System Maintenance
- System file permissions
- Local user and group settings

## Verification

### Manual Verification

After building the AMI, you can verify CIS compliance:

1. **Launch an instance** from the hardened AMI
2. **Connect via SSM Session Manager**
3. **Check hardening status**:
   ```bash
   # Check SELinux status
   sestatus
   
   # Check firewall status
   sudo firewall-cmd --state
   
   # Check auditd status
   sudo systemctl status auditd
   
   # Review CIS assessment reports
   sudo ls -lah /var/log/cis-assessment/
   ```

### Automated Assessment

If CIS tools were downloaded from S3, assessment reports will be available at:
- `/var/log/cis-assessment/` - Assessment output directory

## Troubleshooting

### CIS Tools Not Downloaded

**Issue**: CIS tools download fails

**Solutions**:
1. Verify S3 bucket name and prefix are correct
2. Check IAM instance profile has S3 read permissions
3. Verify S3 Gateway Endpoint is configured for private subnet
4. Check security group allows outbound HTTPS (443) to S3

### Hardening Script Fails

**Issue**: Some CIS controls fail to apply

**Solutions**:
1. Review Packer build logs for specific control failures
2. Some controls may require manual configuration (e.g., bootloader password)
3. Some controls may conflict with application requirements
4. Review and adjust hardening script as needed

### Assessment Tools Not Found

**Issue**: CIS assessment tools not found after download

**Solutions**:
1. Verify CIS tools are uploaded to correct S3 path
2. Check S3 bucket structure matches expected format
3. Review download script logs for errors
4. Ensure CIS tools are compatible with Amazon Linux 2023

## Customization

### Skip Specific Controls

To skip specific CIS controls, edit `scripts/cis/cis-level2-hardening.sh` and comment out or remove the relevant `apply_cis_control` calls.

### Add Custom Hardening

Add custom hardening steps by creating additional scripts in `scripts/cis/` and adding provisioner blocks to the Packer template.

### Adjust Compliance Level

To implement CIS Level 1 (less restrictive), modify the hardening script to only apply Level 1 controls.

## References

- [CIS Amazon Linux 2023 Benchmark](https://www.cisecurity.org/benchmark/amazon_linux)
- [CIS-CAT Pro](https://www.cisecurity.org/cybersecurity-tools/cis-cat-pro/)
- [CIS Workbench](https://www.cisecurity.org/cybersecurity-tools/cis-workbench/)

## Support

For issues or questions:
1. Review Packer build logs
2. Check CIS assessment reports
3. Consult CIS benchmark documentation
4. Review hardening script comments

