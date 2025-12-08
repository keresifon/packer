# AMI Validation Documentation

## Overview

This document describes the post-build AMI validation process implemented in the GitHub Actions workflow. After an AMI is successfully built, a validation job automatically launches a test instance from the new AMI and runs comprehensive validation tests.

## Validation Process

### Workflow Steps

1. **Build Job** (`build`)
   - Builds the AMI using Packer
   - Extracts AMI ID from Packer output
   - Uploads build logs as artifacts

2. **Validation Job** (`validate-ami`)
   - Runs automatically after successful build
   - Only runs if AMI ID was successfully extracted
   - Performs the following steps:
     - Waits for AMI to be available
     - Creates temporary security group
     - Launches test instance (t3.micro)
     - Waits for SSH to be available
     - Runs validation playbook
     - Cleans up resources (terminates instance, deletes security group)

### Validation Tests

The validation playbook (`ansible/ami-validation-playbook.yml`) performs three categories of tests:

#### 1. Functional Tests
- ✅ SSH connectivity
- ✅ System boot and uptime
- ✅ Critical services running (SSH, rsyslog, chronyd)
- ✅ AWS CLI installation and functionality
- ✅ Network connectivity
- ✅ Common utilities installed (curl, wget, git, unzip)
- ✅ Disk space availability
- ✅ SSH security (root login disabled, password auth disabled)
- ✅ DNS resolution

#### 2. CIS Compliance Re-check
Validates that CIS Level 2 controls are properly applied:
- Filesystem restrictions (cramfs disabled)
- Bootloader permissions
- Core dump restrictions
- ASLR enabled
- AppArmor installed
- Network security (IP forwarding disabled, SYN cookies enabled)
- Logging (rsyslog installed and enabled)
- Time synchronization (chronyd configured)
- System file permissions
- SSH hardening (Level 2):
  - Protocol 2 only
  - LogLevel INFO
  - X11Forwarding disabled
  - Password policies
  - Cron permissions

#### 3. Security Validation
- No default/empty passwords
- Critical file permissions verification

## Configuration

### Variables

The validation playbook accepts the following variables:

- `cis_level`: CIS Benchmark Level (default: 2)
- `cis_compliance_threshold`: Minimum compliance percentage (default: 80)
- `fail_on_validation_failure`: Whether to fail build on validation failure (default: false)

### Current Settings

- **CIS Level**: 2 (Level 2 benchmarks)
- **Compliance Threshold**: 80%
- **Fail on Failure**: false (non-blocking, logs only)

## Validation Report

The validation job generates a comprehensive report including:

```
==========================================
AMI Validation Summary
==========================================
Functional Tests: PASS
CIS Compliance: XX%
Security Checks: PASS
Overall Status: PASS/FAIL
==========================================
```

## Artifacts

The workflow generates the following artifacts:

1. **Packer Build Log** (`packer-build-log`)
   - Contains full Packer build output
   - Includes AMI ID and build details
   - Retained for 7 days

2. **Validation Report** (`validation-report`)
   - Contains validation playbook and results
   - Retained for 30 days

## Cost Considerations

The validation process incurs minimal AWS costs:

- **Test Instance**: t3.micro instance running for ~5-10 minutes
- **Security Group**: Temporary, deleted after validation
- **Data Transfer**: Minimal (SSH and Ansible connections)

**Estimated Cost**: ~$0.01-0.02 per validation run

## Failure Handling

### Validation Failures

Currently, validation failures are **non-blocking**:
- Validation job completes with exit code
- Results are logged and available in artifacts
- Build job is not affected
- AMI is still created and available

### To Enable Blocking Validation

To make validation failures block the workflow, update the workflow:

```yaml
- name: Run AMI validation tests
  run: |
    # ... validation commands ...
    -e "fail_on_validation_failure=true"
```

Or update the playbook variable in the workflow to `true`.

## Troubleshooting

### AMI ID Not Extracted

**Symptom**: Validation job doesn't run

**Possible Causes**:
- Packer build output format changed
- Build failed before AMI creation

**Solution**: Check Packer build logs in artifacts

### SSH Connection Timeout

**Symptom**: Validation fails at SSH wait step

**Possible Causes**:
- Instance not fully booted
- Security group not configured correctly
- Network connectivity issues

**Solution**: Check AWS Console for instance status and security group rules

### Validation Tests Fail

**Symptom**: Validation reports failures

**Possible Causes**:
- CIS hardening not applied correctly
- Services not starting
- Configuration issues

**Solution**: Review validation report in artifacts, check CIS hardening playbook

## Manual Validation

You can also run validation manually:

```bash
# Launch test instance
aws ec2 run-instances \
  --image-id ami-xxxxxxxxxxxxxxxxx \
  --instance-type t3.micro \
  --security-group-ids sg-xxxxxxxxx

# Run validation playbook
ansible-playbook \
  -i <instance-ip>, \
  -u ubuntu \
  ansible/ami-validation-playbook.yml \
  -e "cis_level=2" \
  -e "cis_compliance_threshold=80"
```

## Future Enhancements

Potential improvements to the validation process:

1. **Automated Security Scanning**
   - Integrate AWS Inspector
   - Run vulnerability scans
   - Check for known CVEs

2. **Performance Testing**
   - Measure boot time
   - Test resource usage
   - Network performance benchmarks

3. **Integration Testing**
   - Test with actual application workloads
   - Verify compatibility with common tools
   - Test upgrade paths

4. **Compliance Reporting**
   - Generate detailed compliance reports
   - Export to compliance tools
   - Track compliance over time

5. **Multi-Region Validation**
   - Validate AMI in multiple regions
   - Test cross-region compatibility

## Related Files

- `.github/workflows/build-image.yml` - GitHub Actions workflow
- `ansible/ami-validation-playbook.yml` - Validation playbook
- `ansible/cis-compliance-check.yml` - CIS compliance check (used during build)

