# Self-Hosted Runner Setup Guide

This guide provides instructions for setting up a RHEL 9.6 self-hosted GitHub Actions runner with all required dependencies pre-installed.

## Overview

Pre-installing dependencies on the self-hosted runner:
- ✅ Reduces workflow execution time
- ✅ Eliminates sudo requirements during workflow runs
- ✅ Improves reliability and consistency
- ✅ Reduces network dependencies during builds

## Prerequisites

- RHEL 9.6 system with sudo access
- Internet connectivity for downloading packages
- Root or sudo privileges for installation
- **IMPORTANT:** Know which user runs your GitHub Actions runner (typically `github-runner`, `runner`, or check with `ps aux | grep actions-runner`)

## Required Tools

The following tools are required for the Packer AMI build workflow:

| Tool | Purpose | Priority |
|------|---------|----------|
| **yq** | YAML configuration parsing | Critical |
| **jq** | JSON processing | Critical |
| **AWS CLI v2** | AWS API interactions | Critical |
| **Ansible** | Configuration management | Critical |
| **Python 3** | Runtime for Ansible and scripts | Critical |
| **pip3** | Python package manager | Critical |
| **curl** | Downloading files | Critical |
| **wget** | Downloading files | Critical |
| **unzip** | Extracting archives | Critical |
| **git** | Code checkout (usually pre-installed) | Critical |
| **pyyaml** | Python YAML library | Recommended |

## Installation Steps

### Step 1: Update System Packages

```bash
sudo dnf update -y
```

### Step 2: Install Core System Packages

```bash
sudo dnf install -y \
    curl \
    wget \
    unzip \
    git \
    jq \
    python3 \
    python3-pip
```

### Step 3: Install AWS CLI v2

```bash
# Download AWS CLI v2 installer
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"

# Extract installer
unzip -q /tmp/awscliv2.zip -d /tmp

# Install AWS CLI
sudo /tmp/aws/install

# Clean up
rm -rf /tmp/aws /tmp/awscliv2.zip
rm -f /tmp/awscliv2.zip

# Verify installation
aws --version
```

**Expected output:**
```
aws-cli/2.x.x Python/3.x.x Linux/x.x.x source/x86_64
```

### Step 4: Install yq

```bash
# Download yq binary
sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64

# Make executable
sudo chmod +x /usr/local/bin/yq

# Verify installation
yq --version
```

**Expected output:**
```
yq (https://github.com/mikefarah/yq) version v4.x.x
```

### Step 5: Install Ansible

**IMPORTANT:** Install Ansible as the same user that runs the GitHub Actions runner (typically `github-runner` or `runner`). If you install it as a different user, it won't be in the PATH.

```bash
# Option 1: Install as the runner user (RECOMMENDED)
# Switch to the runner user first
sudo su - github-runner  # or whatever user runs the runner

# Install Ansible via pip (will install to ~/.local/bin)
pip3 install ansible

# Verify installation
ansible --version

# Exit back to your user
exit

# Option 2: Install system-wide (requires sudo, accessible to all users)
sudo pip3 install ansible

# Option 3: Install to a specific location in PATH
# Create the directory if it doesn't exist
sudo mkdir -p /usr/local/bin

# Install Ansible
sudo pip3 install ansible

# Verify it's in PATH
which ansible
```

**Expected output:**
```
ansible [core 2.x.x]
  config file = None
  configured module search path = ['/home/github-runner/.ansible/plugins/modules', '/usr/share/ansible/plugins/modules']
  ansible python module location = /home/github-runner/.local/lib/python3.x/site-packages/ansible
  executable location = /home/github-runner/.local/bin/ansible  # or /usr/local/bin/ansible
  python version = 3.x.x
```

**Note:** The executable location should be in one of these PATH directories:
- `/home/github-runner/.local/bin` (user-specific, if installed as runner user)
- `/usr/local/bin` (system-wide, if installed with sudo)
- `/usr/bin` (system-wide, if installed via package manager)

### Step 6: Install Python Packages

```bash
# Install pyyaml (used in copy-ami job)
pip3 install pyyaml

# Verify installation
python3 -c "import yaml; print('pyyaml installed successfully')"
```

### Step 7: Verify All Installations

Run the following command to verify all tools are installed correctly:

```bash
echo "=== Verification ===" && \
echo "yq: $(yq --version)" && \
echo "jq: $(jq --version)" && \
echo "AWS CLI: $(aws --version)" && \
echo "Ansible: $(ansible --version | head -1)" && \
echo "Python: $(python3 --version)" && \
echo "pip: $(pip3 --version)" && \
echo "curl: $(curl --version | head -1)" && \
echo "wget: $(wget --version | head -1)" && \
echo "unzip: $(unzip -v | head -1)" && \
echo "git: $(git --version)" && \
python3 -c "import yaml; print('pyyaml: OK')"
```

## Complete Installation Script

For convenience, here's a complete installation script that you can run:

```bash
#!/bin/bash
set -e

echo "=========================================="
echo "Installing Dependencies for Self-Hosted Runner"
echo "=========================================="

# Update system
echo "Step 1: Updating system packages..."
sudo dnf update -y

# Install core packages
echo "Step 2: Installing core packages..."
sudo dnf install -y \
    curl \
    wget \
    unzip \
    git \
    jq \
    python3 \
    python3-pip

# Install AWS CLI v2
echo "Step 3: Installing AWS CLI v2..."
if ! command -v aws &> /dev/null; then
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
    unzip -q /tmp/awscliv2.zip -d /tmp
    sudo /tmp/aws/install
    rm -rf /tmp/aws /tmp/awscliv2.zip
    rm -f /tmp/awscliv2.zip
else
    echo "AWS CLI already installed: $(aws --version)"
fi

# Install yq
echo "Step 4: Installing yq..."
if ! command -v yq &> /dev/null; then
    sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
    sudo chmod +x /usr/local/bin/yq
else
    echo "yq already installed: $(yq --version)"
fi

# Install Ansible
echo "Step 5: Installing Ansible..."
if ! command -v ansible &> /dev/null; then
    pip3 install ansible
else
    echo "Ansible already installed: $(ansible --version | head -1)"
fi

# Install Python packages
echo "Step 6: Installing Python packages..."
pip3 install pyyaml

# Verify installations
echo ""
echo "=========================================="
echo "Verification"
echo "=========================================="
echo "yq: $(yq --version)"
echo "jq: $(jq --version)"
echo "AWS CLI: $(aws --version)"
echo "Ansible: $(ansible --version | head -1)"
echo "Python: $(python3 --version)"
echo "pip: $(pip3 --version)"
echo "curl: $(curl --version | head -1)"
echo "wget: $(wget --version | head -1)"
echo "unzip: $(unzip -v | head -1)"
echo "git: $(git --version)"
python3 -c "import yaml; print('pyyaml: OK')"

echo ""
echo "=========================================="
echo "Installation Complete!"
echo "=========================================="
```

**To use the script:**

```bash
# Save the script
cat > install-dependencies.sh << 'SCRIPT_EOF'
[paste the script above]
SCRIPT_EOF

# Make executable
chmod +x install-dependencies.sh

# Run it
./install-dependencies.sh
```

## Workflow Compatibility Notes

### Current Workflow Status

The workflow currently uses `apt-get` commands (Debian/Ubuntu syntax). With pre-installed dependencies, these steps will be skipped, but you may want to update the workflow for better compatibility.

### Steps That Will Be Skipped

With pre-installed dependencies, the following workflow steps will either:
- Skip installation (if tools are already present)
- Fail gracefully (if conditional checks are added)

**Steps affected:**
1. `Install yq for config parsing` (Lines 62-66, 137-141, 497-501, 1045-1049)
2. `Install Ansible` (Lines 207-211)
3. `Install dependencies for validation` (Lines 472-476)
4. `Verify AWS CLI is available` (Lines 478-485)
5. `Verify AWS CLI and install dependencies` (Lines 888-899)

### Recommended Workflow Updates

Consider updating the workflow to:
1. Check if tools exist before installing
2. Use `dnf` instead of `apt-get` for RHEL compatibility
3. Add OS detection for cross-platform support

Example update for yq installation:

```yaml
- name: Install yq for config parsing
  run: |
    if ! command -v yq &> /dev/null; then
      echo "Installing yq..."
      sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
      sudo chmod +x /usr/local/bin/yq
    else
      echo "yq already installed: $(yq --version)"
    fi
```

## Troubleshooting

### Issue: yq command not found

**Solution:**
```bash
# Check if yq exists
which yq

# If not found, reinstall
sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq

# Verify PATH includes /usr/local/bin
echo $PATH | grep -q /usr/local/bin || export PATH=$PATH:/usr/local/bin
```

### Issue: AWS CLI not found

**Solution:**
```bash
# Check installation
which aws

# Reinstall if needed
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
unzip -q /tmp/awscliv2.zip -d /tmp
sudo /tmp/aws/install --update
```

### Issue: Ansible not found

**Solution:**
```bash
# Check if pip3 is available
pip3 --version

# Reinstall Ansible
pip3 install --upgrade ansible

# Verify installation
ansible --version
```

### Issue: Permission denied for /usr/local/bin

**Solution:**
```bash
# Ensure /usr/local/bin exists and is writable
sudo mkdir -p /usr/local/bin
sudo chmod 755 /usr/local/bin

# Verify sudo access
sudo -v
```

## Maintenance

### Updating Tools

**Update yq:**
```bash
sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq
```

**Update AWS CLI:**
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
unzip -q /tmp/awscliv2.zip -d /tmp
sudo /tmp/aws/install --update
rm -rf /tmp/aws /tmp/awscliv2.zip
```

**Update Ansible:**
```bash
pip3 install --upgrade ansible
```

**Update Python packages:**
```bash
pip3 install --upgrade pyyaml
```

### Checking Versions

Run this command periodically to check tool versions:

```bash
echo "Tool Versions:" && \
echo "  yq: $(yq --version 2>/dev/null || echo 'Not installed')" && \
echo "  jq: $(jq --version 2>/dev/null || echo 'Not installed')" && \
echo "  AWS CLI: $(aws --version 2>/dev/null || echo 'Not installed')" && \
echo "  Ansible: $(ansible --version 2>/dev/null | head -1 || echo 'Not installed')" && \
echo "  Python: $(python3 --version 2>/dev/null || echo 'Not installed')"
```

## Security Considerations

1. **Sudo Access**: The runner user should have passwordless sudo configured for these specific commands, or run the installation as root.

2. **Binary Verification**: Consider verifying checksums for downloaded binaries:
   ```bash
   # Example for yq (check GitHub releases for actual checksum)
   echo "CHECKSUM" yq | sha256sum -c
   ```

3. **Network Security**: Ensure the runner can access:
   - GitHub releases (for yq)
   - AWS endpoints (for AWS CLI)
   - PyPI (for Python packages)

4. **File Permissions**: Ensure `/usr/local/bin` has appropriate permissions:
   ```bash
   sudo chmod 755 /usr/local/bin
   ```

## Additional Resources

- [GitHub Actions Self-Hosted Runners](https://docs.github.com/en/actions/hosting-your-own-runners)
- [yq Documentation](https://github.com/mikefarah/yq)
- [AWS CLI Documentation](https://docs.aws.amazon.com/cli/latest/userguide/)
- [Ansible Documentation](https://docs.ansible.com/)
- [RHEL 9 Documentation](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/)

## Support

If you encounter issues during installation or setup, please:
1. Check the troubleshooting section above
2. Verify system requirements
3. Review workflow logs for specific error messages
4. Ensure all prerequisites are met

