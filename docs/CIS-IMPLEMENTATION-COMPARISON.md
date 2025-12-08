# CIS Benchmark Implementation - Current Approach

This document describes the current Ansible-based implementation for applying CIS benchmarks in Packer builds.

## Current Implementation: Ansible

### Overview
The project uses Ansible playbooks and modular task files to apply and validate CIS Ubuntu 22.04 LTS benchmarks. This approach provides maintainability, idempotency, and structured compliance reporting.

### Architecture

The implementation consists of:

1. **Main Playbooks**:
   - `ansible/cis-hardening-playbook.yml` - Applies CIS benchmark hardening
   - `ansible/cis-compliance-check.yml` - Validates compliance after hardening
   - `ansible/ami-validation-playbook.yml` - Post-build validation tests

2. **Modular Task Files** (`ansible/tasks/cis/`):
   - Organized by CIS benchmark sections (1.1, 1.4, 1.5, etc.)
   - Each section has its own task file for easy maintenance
   - Tasks can be selectively enabled/disabled via `cis_skip_sections` variable

3. **Compliance Tasks** (`ansible/tasks/compliance/`):
   - Reusable compliance check tasks
   - Calculates compliance percentage
   - Provides structured reporting

### File Structure

```
ansible/
├── cis-hardening-playbook.yml    # Main hardening playbook
├── cis-compliance-check.yml      # Compliance validation playbook
├── ami-validation-playbook.yml   # Post-build validation
├── requirements.yml              # Ansible Galaxy dependencies (if any)
├── vars/
│   └── cis-defaults.yml         # Default CIS configuration variables
└── tasks/
    ├── cis/                      # CIS hardening tasks (by section)
    │   ├── 1.1-filesystem.yml
    │   ├── 1.4-boot-settings.yml
    │   ├── 1.5-process-hardening.yml
    │   ├── 1.6-mac.yml
    │   ├── 1.7-warning-banners.yml
    │   ├── 2.1-services.yml
    │   ├── 2.2-special-services.yml
    │   ├── 3.1-network.yml
    │   ├── 4.1-logging.yml
    │   ├── 5.1-time-sync.yml
    │   ├── 5.2-ssh.yml
    │   ├── 6.1-file-permissions.yml
    │   ├── 6.2-user-group.yml
    │   └── 6.3-maintenance.yml
    ├── compliance/               # Compliance check tasks
    │   ├── calculate-compliance.yml
    │   └── [section-specific checks]
    ├── validation/               # Post-build validation tests
    │   ├── functional-tests.yml
    │   └── security-tests.yml
    └── common/                   # Common reusable tasks
        └── disable-filesystem.yml
```

### Key Features

- ✅ **Modular Design**: Each CIS section is in its own task file
- ✅ **Idempotent**: Can run multiple times safely
- ✅ **Configurable**: CIS level (1 or 2) and compliance threshold configurable
- ✅ **Selective Application**: Skip specific sections via `cis_skip_sections`
- ✅ **Compliance Reporting**: Structured compliance percentage calculation
- ✅ **Validation**: Post-build validation ensures AMI is functional and secure

### Configuration

CIS hardening is configured via variables in `ansible/vars/cis-defaults.yml`:

```yaml
cis_level_default: 2                    # CIS Benchmark Level (1 or 2)
cis_skip_sections: []                   # Sections to skip (e.g., ['1.1', '2.2'])
cis_compliance_threshold: 80            # Minimum compliance percentage
fail_build_on_non_compliance: false     # Fail build if below threshold
```

These can be overridden via Packer variables or workflow inputs.

### How It Works

1. **During Packer Build**:
   - Ansible directory is copied to `/tmp/ansible` on the build instance
   - `cis-hardening-playbook.yml` runs to apply CIS benchmarks
   - `cis-compliance-check.yml` runs to validate compliance
   - Build fails if compliance is below threshold (if enabled)

2. **Post-Build Validation**:
   - GitHub Actions launches a test instance from the AMI
   - `ami-validation-playbook.yml` runs functional and security tests
   - Ensures AMI is bootable, secure, and functional

### CIS Sections Implemented

- **1.1** - Filesystem Configuration
- **1.4** - Secure Boot Settings
- **1.5** - Additional Process Hardening
- **1.6** - Mandatory Access Control (AppArmor)
- **1.7** - Command Line Warning Banners
- **2.1** - Services (disable unnecessary services)
- **2.2** - Special Purpose Services
- **3.1** - Network Parameters
- **4.1** - Configure Logging (rsyslog)
- **5.1** - Configure Time Synchronization (chronyd)
- **5.2** - SSH Server Configuration (Level 2)
- **6.1** - System File Permissions
- **6.2** - User and Group Settings (Level 2)
- **6.3** - System Maintenance (Level 2)

### Benefits of Ansible Approach

- ✅ **Maintainable**: Structured playbooks, easier to read and modify
- ✅ **Idempotent**: Can run multiple times safely
- ✅ **Reusable**: Task files can be shared across projects
- ✅ **Better error handling**: Comprehensive error handling and reporting
- ✅ **Testable**: Easy to test individual tasks
- ✅ **Flexible**: Easy to enable/disable specific CIS sections
- ✅ **Compliance reporting**: Structured compliance reports with percentages
- ✅ **CI/CD Integration**: Works seamlessly with GitHub Actions

### Usage in Packer Template

The Packer template (`ubuntu-golden-image.pkr.hcl`) uses shell provisioners to run Ansible:

```hcl
# Copy Ansible directory to remote instance
provisioner "file" {
  source      = "ansible"
  destination = "/tmp"
}

# Run CIS hardening
provisioner "shell" {
  inline = [
    "cd /tmp/ansible && ansible-playbook cis-hardening-playbook.yml -e cis_level=${var.cis_level} -e cis_compliance_threshold=${var.cis_compliance_threshold} -v -c local -i localhost,"
  ]
}

# Run compliance check
provisioner "shell" {
  inline = [
    "cd /tmp/ansible && ansible-playbook cis-compliance-check.yml -e cis_compliance_threshold=${var.cis_compliance_threshold} -v -c local -i localhost,"
  ]
}
```

### Customization

#### Skip Specific Sections

To skip specific CIS sections, set `cis_skip_sections`:

```yaml
# In ansible/vars/cis-defaults.yml or via Packer variable
cis_skip_sections: ['1.1', '2.2']  # Skip filesystem and special services
```

#### Change CIS Level

Set `cis_level` to 1 or 2:

```hcl
# In Packer template or workflow
cis_level = 1  # Level 1 (basic) or 2 (advanced)
```

#### Adjust Compliance Threshold

```yaml
cis_compliance_threshold: 90  # Require 90% compliance
```

### Compliance Reporting

The compliance check provides:
- **Overall compliance percentage**
- **Per-section compliance status**
- **Failed checks with details**
- **Option to fail build** if below threshold

### Resources

- [Ansible Documentation](https://docs.ansible.com/)
- [CIS Ubuntu 22.04 LTS Benchmark](https://www.cisecurity.org/benchmark/ubuntu_linux)
- [Packer Documentation](https://www.packer.io/docs)

---

**Note**: This implementation replaces the previous shell script approach for better maintainability and structure.
