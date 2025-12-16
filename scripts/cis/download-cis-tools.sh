#!/bin/bash
# Download CIS tools from S3 for CIS Level 2 compliance
# This script downloads CIS assessment and remediation tools from S3

set -euo pipefail

# Configuration
CIS_S3_BUCKET="${CIS_S3_BUCKET:-}"
CIS_S3_PREFIX="${CIS_S3_PREFIX:-cis-tools}"
CIS_TOOLS_DIR="/opt/cis-tools"
AWS_REGION="${AWS_REGION:-us-east-1}"

if [ -z "$CIS_S3_BUCKET" ]; then
    echo "⚠️  WARNING: CIS_S3_BUCKET not set, skipping CIS tools download"
    exit 0
fi

echo "=== Downloading CIS Tools from S3 ==="
echo "S3 Bucket: $CIS_S3_BUCKET"
echo "S3 Prefix: $CIS_S3_PREFIX"
echo "Destination: $CIS_TOOLS_DIR"

# Create directory for CIS tools
sudo mkdir -p "$CIS_TOOLS_DIR"
sudo chmod 755 "$CIS_TOOLS_DIR"

# Check if AWS CLI is available
if ! command -v aws >/dev/null 2>&1; then
    echo "❌ ERROR: AWS CLI not found. Cannot download CIS tools from S3."
    exit 1
fi

# Set AWS region
export AWS_DEFAULT_REGION="$AWS_REGION"

# Download CIS tools from S3
echo "Downloading CIS tools from s3://${CIS_S3_BUCKET}/${CIS_S3_PREFIX}/..."

# Download all files from S3 prefix
if aws s3 sync "s3://${CIS_S3_BUCKET}/${CIS_S3_PREFIX}/" "$CIS_TOOLS_DIR/" --region "$AWS_REGION" 2>&1; then
    echo "✅ CIS tools downloaded successfully"
    
    # Set permissions on downloaded tools
    sudo chmod -R 755 "$CIS_TOOLS_DIR"
    
    # List downloaded files
    echo "Downloaded CIS tools:"
    ls -lah "$CIS_TOOLS_DIR" || true
    
    # Make scripts executable
    find "$CIS_TOOLS_DIR" -type f -name "*.sh" -exec sudo chmod +x {} \;
    
    echo "✅ CIS tools setup complete"
else
    echo "⚠️  WARNING: Failed to download CIS tools from S3"
    echo "   This may be expected if CIS tools are not yet uploaded to S3"
    echo "   Continuing with manual CIS hardening scripts..."
fi

