# Installing Packer on WSL2 (Manual Installation)

## Step 1: Download Packer

```bash
# Set the version you want (check latest at https://www.packer.io/downloads)
PACKER_VERSION="1.10.0"

# Download Packer for Linux
cd ~/Downloads  # or any directory you prefer
wget https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip
```

## Step 2: Extract and Install

```bash
# Extract the ZIP file
unzip packer_${PACKER_VERSION}_linux_amd64.zip

# Move packer to a directory in your PATH
sudo mv packer /usr/local/bin/

# Make it executable (should already be, but ensure it)
sudo chmod +x /usr/local/bin/packer
```

## Step 3: Verify Installation

```bash
# Check version
packer version

# Should output something like:
# Packer v1.10.0
```

## Alternative: Install to User Directory

If you don't want to use `sudo`, you can install to your home directory:

```bash
# Create bin directory in your home
mkdir -p ~/bin

# Move packer there
mv packer ~/bin/

# Add to PATH (add this to your ~/.bashrc or ~/.zshrc)
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Verify
packer version
```

## Troubleshooting

### "command not found: packer"
- Packer is not in your PATH
- Check: `echo $PATH`
- Ensure `/usr/local/bin` is in PATH, or add `~/bin` to PATH

### "Permission denied"
- Make sure packer is executable: `chmod +x /usr/local/bin/packer`
- Or use `sudo` when moving the file

## Next Steps

Once Packer is installed, proceed to build the AMI:

```bash
# Navigate to your project directory
cd /mnt/c/Users/0B9947649/GHTest/packer

# Initialize Packer plugins (first time only)
packer init aws-golden-image.pkr.hcl

# Validate the template
packer validate aws-golden-image.pkr.hcl

# Build the AMI
packer build aws-golden-image.pkr.hcl
```
