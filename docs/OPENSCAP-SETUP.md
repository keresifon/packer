# OpenSCAP Setup Guide for CIS Assessment

This guide explains how to set up OpenSCAP for CIS Level 2 compliance assessment.

## Overview

OpenSCAP is an open-source security compliance framework that uses SCAP (Security Content Automation Protocol) content to assess system compliance. It's ideal for closed network environments as it doesn't require internet connectivity after initial setup.

**Important**: In this implementation, OpenSCAP itself is stored in S3 and downloaded during the Packer build, rather than being installed via package manager. This allows the build to work in private subnets without internet access.

## What is OpenSCAP?

- **Open Source**: Free and open-source compliance assessment tool
- **SCAP Support**: Uses standard SCAP content (XCCDF, OVAL)
- **Offline Capable**: Works in closed networks after initial setup
- **Automated**: Can assess compliance and generate reports automatically
- **CIS Compatible**: Supports CIS benchmark SCAP content

## Installation

OpenSCAP is downloaded from S3 during the Packer build process. You need to upload OpenSCAP to your S3 bucket before running the build.

### Downloading OpenSCAP for S3

On a system with internet access (e.g., your local machine or a build server):

```bash
# Download OpenSCAP RPM for Amazon Linux 2023
dnf download openscap-scanner --downloaddir=./openscap-rpm

# Upload to S3
aws s3 cp ./openscap-rpm/openscap-scanner-*.rpm s3://your-cis-bucket/cis-tools/
```

**Alternative formats**: You can also provide OpenSCAP as:
- A tar.gz/tar.bz2 archive containing the extracted OpenSCAP directory
- A pre-extracted directory structure uploaded to `s3://your-cis-bucket/cis-tools/openscap/`

## SCAP Content Sources

### Option 1: CIS Official SCAP Content (Recommended)

1. **Download from CIS Workbench**:
   - Visit: https://workbench.cisecurity.org/benchmarks
   - Login (free registration required)
   - Navigate to Amazon Linux 2023 benchmark
   - Download SCAP content files:
     - `CIS_Amazon_Linux_2023_Benchmark_v1.0.0-xccdf.xml`
     - `CIS_Amazon_Linux_2023_Benchmark_v1.0.0-oval.xml`

2. **Upload to S3**:
   ```bash
   mkdir -p scap-content
   # Copy downloaded SCAP files
   cp CIS_Amazon_Linux_2023_Benchmark_v*.xml scap-content/
   
   # Upload to S3
   aws s3 sync ./scap-content/ s3://your-cis-bucket/cis-tools/scap-content/
   ```

### Option 2: ComplianceAsCode (SCAP Security Guide)

1. **Download from GitHub**:
   ```bash
   git clone https://github.com/ComplianceAsCode/content.git
   cd content
   ```

2. **Build SCAP content** (requires build tools):
   ```bash
   # Build Amazon Linux 2023 content
   cmake .
   make -j4 al2023
   ```

3. **Find built content**:
   ```bash
   find build/ -name "*al2023*.xml" -path "*/products/al2023/*"
   ```

4. **Upload to S3**:
   ```bash
   # Copy XCCDF file
   cp build/ssg-al2023-xccdf.xml s3://your-cis-bucket/cis-tools/scap-content/
   ```

### Option 3: Use Pre-built Content

Some organizations maintain pre-built SCAP content repositories. Check with your security team for approved SCAP content sources.

## S3 Bucket Structure

Your S3 bucket should have this structure:

```
s3://your-cis-bucket/
└── cis-tools/
    └── scap-content/
        ├── CIS_Amazon_Linux_2023_Benchmark_v1.0.0-xccdf.xml
        ├── CIS_Amazon_Linux_2023_Benchmark_v1.0.0-oval.xml
        └── (optional) other SCAP files
```

**Alternative**: You can also place SCAP files directly in `cis-tools/` as `.xml` files.

## Running Assessment

The assessment runs automatically during Packer build. To run manually:

```bash
# Ensure OpenSCAP is downloaded from S3 (runs automatically during build)
# OpenSCAP will be available at /opt/openscap/oscap

# Run assessment
sudo /opt/openscap/oscap xccdf eval \
  --profile xccdf_org.cisecurity.benchmarks_profile_Level_2-Server \
  --results /var/log/cis-assessment/results.xml \
  --report /var/log/cis-assessment/report.html \
  /opt/scap-content/CIS_Amazon_Linux_2023_Benchmark_v1.0.0-xccdf.xml
```

**Note**: The assessment script automatically finds OpenSCAP at `/opt/openscap/oscap` or `/opt/openscap/bin/oscap` after downloading from S3.

## Available Profiles

List available profiles in SCAP content:

```bash
oscap xccdf eval --profiles /opt/scap-content/CIS_Amazon_Linux_2023_Benchmark_v1.0.0-xccdf.xml
```

Common profiles:
- `xccdf_org.cisecurity.benchmarks_profile_Level_1-Server` - CIS Level 1
- `xccdf_org.cisecurity.benchmarks_profile_Level_2-Server` - CIS Level 2 (default)

## Assessment Output

OpenSCAP generates three types of output:

1. **XML Results** (`results.xml`):
   - Machine-readable results
   - Contains detailed rule results
   - Can be processed by other tools

2. **HTML Report** (`report.html`):
   - Human-readable report
   - Color-coded pass/fail indicators
   - Detailed explanations for each rule
   - **Best for manual review**

3. **Text Output** (stdout):
   - Console output during assessment
   - Shows progress and summary

## Viewing Reports

### HTML Report

1. **Download from instance**:
   ```bash
   # Via SSM Session Manager
   aws ssm start-session --target i-xxxxx
   
   # Copy report
   sudo cat /var/log/cis-assessment/oscap-assessment-*.html > report.html
   ```

2. **Open in browser**:
   - Download the HTML file to your local machine
   - Open in any web browser
   - Review compliance status for each CIS control

### XML Results

Process XML results programmatically:

```bash
# Extract pass/fail counts
oscap xccdf generate report results.xml > report.html

# Query specific results
xmllint --xpath "//*[local-name()='rule-result']" results.xml
```

## Customizing Assessment

### Change Profile

Set the `SCAP_PROFILE` environment variable in Packer:

```hcl
provisioner "shell" {
  environment_vars = [
    "SCAP_PROFILE=xccdf_org.cisecurity.benchmarks_profile_Level_1-Server"
  ]
  script = "scripts/cis/run-cis-assessment.sh"
}
```

### Custom SCAP Content Location

Modify `SCAP_CONTENT_DIR` in `run-cis-assessment.sh` if you want to use a different location.

## Troubleshooting

### OpenSCAP Not Found

**Error**: `OpenSCAP not found` or `oscap: command not found`

**Solutions**:
1. Verify OpenSCAP is uploaded to S3 at `s3://bucket/cis-tools/openscap*`
2. Check file format (RPM, tar.gz, or pre-extracted directory)
3. Review download script logs to verify extraction succeeded
4. Ensure OpenSCAP binary exists at `/opt/openscap/oscap` or `/opt/openscap/bin/oscap`
5. Check file permissions: `ls -la /opt/openscap/oscap`
6. Verify S3 bucket permissions allow download
7. Check that AWS CLI is available and configured

### No SCAP Content Found

**Error**: `No SCAP content found for assessment`

**Solutions**:
1. Verify SCAP files are uploaded to S3
2. Check file names match expected patterns
3. Ensure files have `.xml` extension
4. Review download script logs

### Assessment Fails

**Error**: Assessment exits with non-zero code

**Note**: This is often expected! OpenSCAP returns non-zero if any rules fail, which is normal during initial hardening. Check the HTML report to see which controls passed/failed.

### Profile Not Found

**Error**: `Profile 'xccdf_org.cisecurity.benchmarks_profile_Level_2-Server' not found`

**Solutions**:
1. List available profiles: `oscap xccdf eval --profiles <scap-file>`
2. Use the correct profile name from the list
3. Some SCAP content may use different profile naming

## Integration with CI/CD

The assessment runs automatically during Packer build. To integrate results into CI/CD:

1. **Extract results**:
   ```bash
   # Get pass/fail count
   PASS_COUNT=$(oscap xccdf generate report results.xml | grep -c "pass")
   FAIL_COUNT=$(oscap xccdf generate report results.xml | grep -c "fail")
   ```

2. **Set thresholds**:
   ```bash
   # Fail build if more than 10% of controls fail
   if [ $FAIL_COUNT -gt $((TOTAL_COUNT / 10)) ]; then
     echo "Too many controls failed"
     exit 1
   fi
   ```

3. **Upload reports**:
   ```bash
   # Upload HTML report to S3 for review
   aws s3 cp report.html s3://reports-bucket/cis-assessment-$(date +%Y%m%d).html
   ```

## Best Practices

1. **Use Official CIS SCAP Content**: Download from CIS Workbench for official benchmarks
2. **Version Control**: Track SCAP content versions in your S3 bucket
3. **Regular Updates**: Update SCAP content when new CIS benchmarks are released
4. **Review Reports**: Always review HTML reports to understand compliance status
5. **Remediate Failures**: Use assessment results to identify and fix non-compliant controls
6. **Baseline First**: Run assessment before hardening to establish baseline
7. **Re-assess After**: Run assessment after hardening to verify improvements

## Additional Resources

- [OpenSCAP Documentation](https://www.open-scap.org/documentation/)
- [SCAP Security Guide](https://github.com/ComplianceAsCode/content)
- [CIS Benchmarks](https://www.cisecurity.org/benchmarks)
- [NIST SCAP](https://csrc.nist.gov/projects/security-content-automation-protocol)

