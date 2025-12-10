# Ansible Playbooks and Tasks

This directory contains modular Ansible playbooks and tasks for CIS Ubuntu 22.04 LTS Benchmark hardening, compliance checking, and AMI validation.

## Directory Structure

```
ansible/
├── playbooks/              # Main playbook orchestrators
│   └── cis-hardening.yml   # Alternative location for CIS hardening playbook
├── tasks/                  # Modular task files
│   ├── cis/                # CIS benchmark hardening tasks
│   │   ├── 1.1-filesystem.yml
│   │   ├── 1.4-boot-settings.yml
│   │   ├── 1.5-process-hardening.yml
│   │   ├── 1.6-mac.yml
│   │   ├── 1.7-warning-banners.yml
│   │   ├── 2.1-services.yml
│   │   ├── 2.2-special-services.yml
│   │   ├── 3.1-network.yml
│   │   ├── 4.1-logging.yml
│   │   ├── 5.1-time-sync.yml
│   │   ├── 5.2-ssh.yml
│   │   ├── 6.1-file-permissions.yml
│   │   ├── 6.2-user-group.yml
│   │   └── 6.3-maintenance.yml
│   ├── compliance/          # Compliance check tasks (future)
│   ├── validation/         # Validation test tasks (future)
│   └── common/             # Reusable common tasks
│       └── disable-filesystem.yml
├── vars/                   # Variable files
│   └── cis-defaults.yml    # Default CIS variables
├── cis-hardening-playbook.yml      # Main CIS hardening playbook (uses tasks/)
├── cis-compliance-check.yml         # CIS compliance check playbook
├── ami-validation-playbook.yml     # AMI validation playbook
└── requirements.yml                # Ansible Galaxy requirements
```

## Main Playbooks

### `cis-hardening-playbook.yml`

Main playbook for applying CIS Ubuntu 22.04 LTS Benchmark hardening. Uses modular task files from `tasks/cis/`.

**Usage:**
```bash
ansible-playbook -i inventory ansible/cis-hardening-playbook.yml \
  -e "cis_level=2" \
  -e "cis_skip_sections=[]"
```

**Variables:**
- `cis_level`: CIS Benchmark Level (1 or 2, default: 2)
- `cis_skip_sections`: List of sections to skip (e.g., `['1.1', '2.2']`)
- `cis_compliance_threshold`: Minimum compliance percentage (default: 80)

### `cis-compliance-check.yml`

Validates CIS benchmark compliance after hardening.

### `ami-validation-playbook.yml`

Runs comprehensive validation tests on newly created AMIs.

## Modular Task Files

Each CIS section is broken down into its own task file in `tasks/cis/`:

- **1.1-filesystem.yml**: Disables unnecessary filesystem modules
- **1.4-boot-settings.yml**: Configures bootloader security
- **1.5-process-hardening.yml**: Process hardening settings
- **1.6-mac.yml**: Mandatory Access Control (AppArmor)
- **1.7-warning-banners.yml**: Login warning banners
- **2.1-services.yml**: Removes unnecessary services
- **2.2-special-services.yml**: Removes special purpose services
- **3.1-network.yml**: Network security parameters
- **4.1-logging.yml**: Logging configuration
- **5.1-time-sync.yml**: Time synchronization
- **5.2-ssh.yml**: SSH server configuration (Level 2)
- **6.1-file-permissions.yml**: System file permissions
- **6.2-user-group.yml**: User and group settings (Level 2)
- **6.3-maintenance.yml**: System maintenance (Level 2)

## Benefits of Modular Structure

1. **Maintainability**: Each CIS section is in its own file, making updates easier
2. **Reusability**: Task files can be included in other playbooks
3. **Testability**: Individual sections can be tested independently
4. **Readability**: Smaller, focused files are easier to understand
5. **Flexibility**: Sections can be skipped or conditionally included

## Using Individual Task Files

You can include individual CIS sections in your own playbooks:

```yaml
- name: Apply specific CIS sections
  hosts: all
  become: yes
  tasks:
    - name: Apply filesystem hardening
      include_tasks: tasks/cis/1.1-filesystem.yml
    
    - name: Apply network hardening
      include_tasks: tasks/cis/3.1-network.yml
      vars:
        cis_level: 2
```

## Common Tasks

Reusable tasks are in `tasks/common/`:

- **disable-filesystem.yml**: Common pattern for disabling filesystem modules

## Variables

Default variables are defined in `vars/cis-defaults.yml` and can be overridden:

```yaml
cis_level_default: 2
cis_skip_sections: []
cis_compliance_threshold: 80
```

## Compliance Task Files

Each CIS compliance check section is in `tasks/compliance/`:

- **1.1-filesystem.yml**: Filesystem compliance checks
- **1.4-boot.yml**: Bootloader compliance checks
- **1.5-process.yml**: Process hardening compliance checks
- **1.6-mac.yml**: MAC compliance checks
- **3.1-network.yml**: Network compliance checks
- **4.1-logging.yml**: Logging compliance checks
- **5.1-time-sync.yml**: Time sync compliance checks
- **5.2-ssh.yml**: SSH compliance checks (Level 2)
- **6.1-file-permissions.yml**: File permissions compliance checks
- **6.2-user-group.yml**: User/group compliance checks (Level 2)
- **6.3-maintenance.yml**: Maintenance compliance checks (Level 2)
- **calculate-compliance.yml**: Calculates compliance statistics

## Validation Task Files

AMI validation tests are in `tasks/validation/`:

- **functional-tests.yml**: Functional validation tests (SSH, services, utilities, etc.)
- **security-tests.yml**: Security validation tests (passwords, file permissions, etc.)

## Future Enhancements

- Create more common reusable tasks
- Add role-based structure if needed for sharing across projects
- Add more granular validation tests

