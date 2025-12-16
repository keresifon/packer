# CIS Level 2 Hardening for Amazon Linux 2023

This document describes how to implement CIS (Center for Internet Security) Level 2 hardening for Amazon Linux 2023 golden images using Packer.

## Overview

The CIS hardening implementation includes:
- **CIS Level 2 Hardening Scripts**: Automated implementation of CIS benchmark controls
- **OpenSCAP Assessment**: Uses OpenSCAP scanner with SCAP content for compliance verification
- **S3-based SCAP Content**: Download SCAP content files from S3 for assessment
- **Compliance Verification**: Automated assessment to verify hardening compliance

## Prerequisites

1. **S3 Bucket**: An S3 bucket to store CIS tools
2. **VPC Endpoints**: S3 Gateway Endpoint configured for private subnet access
3. **IAM Permissions**: Instance profile with S3 read permissions for CIS tools bucket
4. **CIS Tools**: CIS assessment tools (CIS-CAT, CIS Workbench, etc.) uploaded to S3

## S3 Bucket Structure

Upload OpenSCAP and SCAP content to your S3 bucket with the following structure:

```
s3://your-cis-bucket/
└── cis-tools/
    ├── openscap-scanner-*.rpm          # OpenSCAP RPM package
    ├── openscap-*.tar.gz               # OR OpenSCAP archive (tar.gz/tar.bz2/zip)
    ├── openscap/                       # OR Pre-extracted OpenSCAP directory
    │   ├── bin/
    │   │   └── oscap
    │   └── lib/
    └── scap-content/
        ├── CIS_Amazon_Linux_2023_Benchmark_v1.0.0-xccdf.xml
        ├── CIS_Amazon_Linux_2023_Benchmark_v1.0.0-oval.xml
        └── ... (other SCAP content files)
```

**Note**: 
- OpenSCAP can be provided as RPM, archive (tar.gz/tar.bz2/zip), or pre-extracted directory
- SCAP content files can also be placed directly in the `cis-tools/` directory as `.xml` files

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

## OpenSCAP and SCAP Content Setup

### Step 1: Download OpenSCAP

You need to provide OpenSCAP in one of these formats:

#### Option A: OpenSCAP RPM (Recommended)

1. **Download OpenSCAP RPM**:
   ```bash
   # On a system with internet access (e.g., your local machine)
   # Download openscap-scanner RPM for Amazon Linux 2023
   dnf download openscap-scanner --downloaddir=./openscap-rpm
   ```

2. **Upload to S3**:
   ```bash
   aws s3 cp ./openscap-rpm/openscap-scanner-*.rpm s3://your-cis-bucket/cis-tools/
   ```

#### Option B: OpenSCAP Archive

1. **Download and extract OpenSCAP**:
   ```bash
   # Download OpenSCAP source or binary distribution
   # Extract it locally
   tar czf openscap.tar.gz openscap/
   ```

2. **Upload to S3**:
   ```bash
   aws s3 cp openscap.tar.gz s3://your-cis-bucket/cis-tools/
   ```

#### Option C: Pre-extracted OpenSCAP Directory

1. **Extract OpenSCAP** on a system with internet access
2. **Upload entire directory**:
   ```bash
   aws s3 sync ./openscap/ s3://your-cis-bucket/cis-tools/openscap/
   ```

### Step 2: Download SCAP Content

#### Option 1: CIS Official SCAP Content (Recommended)

1. **Download CIS SCAP Content**:
   - Visit: https://www.cisecurity.org/benchmark/amazon_linux
   - Download the SCAP content for Amazon Linux 2023
   - Look for files named `CIS_Amazon_Linux_2023_Benchmark_v*.xml`
   - Or download from: https://workbench.cisecurity.org/benchmarks

2. **Upload to S3**:
   ```bash
   # Create directory structure
   mkdir -p scap-content
   
   # Copy SCAP files (XCCDF and OVAL)
   cp CIS_Amazon_Linux_2023_Benchmark_v*.xml scap-content/
   
   # Upload to S3
   aws s3 sync ./scap-content/ s3://your-cis-bucket/cis-tools/scap-content/
   ```

#### Option 2: Use ComplianceAsCode (SCAP Security Guide)

1. **Download SCAP Security Guide**:
   - Visit: https://github.com/ComplianceAsCode/content
   - Download or clone the repository
   - Find Amazon Linux 2023 content in `rhel*/products/al2023/`

2. **Upload to S3**:
   ```bash
   # Extract SCAP content
   cd content
   find . -name "*al2023*.xml" -path "*/products/al2023/*" -exec cp {} ../scap-content/ \;
   
   # Upload to S3
   aws s3 sync ../scap-content/ s3://your-cis-bucket/cis-tools/scap-content/
   ```

### Option 3: Manual Hardening Only

If you don't want to use assessment tools, you can skip S3 bucket configuration. The hardening scripts will still run, but assessment will be skipped.

## Hardening Process

The Packer build process includes the following steps:

1. **System Updates**: Update and upgrade system packages
2. **Common Packages**: Install common utilities (curl, wget, git, etc.)
3. **SSM Agent**: Install and configure SSM Agent
4. **AWS CLI**: Install AWS CLI (required for S3 access)
5. **SCAP Content Download**: Download SCAP content from S3 (if bucket configured)
6. **CIS Hardening**: Apply CIS Level 2 hardening controls
7. **OpenSCAP Assessment**: Install OpenSCAP and run assessment with SCAP content
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

### Automated Assessment with OpenSCAP

OpenSCAP assessment reports will be available at:
- `/var/log/cis-assessment/oscap-assessment-*.xml` - XML results file
- `/var/log/cis-assessment/oscap-assessment-*.html` - HTML report (human-readable)
- `/var/log/cis-assessment/oscap-report-*.txt` - Text output

**To view the HTML report**:
1. Download the HTML file from `/var/log/cis-assessment/oscap-assessment-*.html`
2. Open it in a web browser to view detailed compliance results

**Assessment Profile**:
- Default profile: `xccdf_org.cisecurity.benchmarks_profile_Level_2-Server`
- You can change this by setting the `SCAP_PROFILE` environment variable

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

### OpenSCAP Not Found

**Issue**: OpenSCAP not found after download from S3

**Solutions**:
1. Verify OpenSCAP is uploaded to S3 at `s3://bucket/cis-tools/openscap*`
2. Check file format (RPM, tar.gz, or pre-extracted directory)
3. Review download script logs to verify extraction
4. Ensure OpenSCAP binary exists at `/opt/openscap/oscap` or `/opt/openscap/bin/oscap`
5. Check file permissions on OpenSCAP binary

### SCAP Content Not Found

**Issue**: No SCAP content found for assessment

**Solutions**:
1. Verify SCAP content is uploaded to S3 at `s3://bucket/cis-tools/scap-content/`
2. Ensure SCAP files have `.xml` extension
3. Check file names match expected patterns (CIS_Amazon_Linux_2023*.xml)
4. Review download script logs to verify files were downloaded
5. Assessment will be skipped if no SCAP content is found (non-fatal)

## Customization

### Skip Specific Controls

To skip specific CIS controls, edit `scripts/cis/cis-level2-hardening.sh` and comment out or remove the relevant `apply_cis_control` calls.

### Add Custom Hardening

Add custom hardening steps by creating additional scripts in `scripts/cis/` and adding provisioner blocks to the Packer template.

### Adjust Compliance Level

To implement CIS Level 1 (less restrictive), modify the hardening script to only apply Level 1 controls.

## References

- [CIS Amazon Linux 2023 Benchmark](https://www.cisecurity.org/benchmark/amazon_linux)
- [OpenSCAP Project](https://www.open-scap.org/)
- [SCAP Security Guide (ComplianceAsCode)](https://github.com/ComplianceAsCode/content)
- [CIS Workbench](https://www.cisecurity.org/cybersecurity-tools/cis-workbench/) - For downloading SCAP content

## Support

For issues or questions:
1. Review Packer build logs
2. Check CIS assessment reports
3. Consult CIS benchmark documentation
4. Review hardening script comments

