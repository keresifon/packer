#!/bin/bash
# Download CIS tools from S3 for CIS Level 2 compliance
# This script downloads OpenSCAP, SCAP content, and other CIS assessment tools from S3

set -euo pipefail

# Check if CIS hardening is enabled
if [ "${ENABLE_CIS_HARDENING:-false}" != "true" ]; then
    echo "⚠️  CIS hardening is disabled, skipping CIS tools download"
    exit 0
fi

# Configuration
CIS_S3_BUCKET="${CIS_S3_BUCKET:-}"
CIS_S3_PREFIX="${CIS_S3_PREFIX:-cis-tools}"
CIS_TOOLS_DIR="/opt/cis-tools"
OPENSCAP_DIR="/opt/openscap"
SCAP_CONTENT_DIR="/opt/scap-content"
AWS_REGION="${AWS_REGION:-us-east-1}"

if [ -z "$CIS_S3_BUCKET" ]; then
    echo "⚠️  WARNING: CIS_S3_BUCKET not set, skipping CIS tools download"
    exit 0
fi

echo "=== Downloading CIS Tools from S3 ==="
echo "S3 Bucket: $CIS_S3_BUCKET"
echo "S3 Prefix: $CIS_S3_PREFIX"
echo "Destination: $CIS_TOOLS_DIR"

# Create directories for CIS tools, OpenSCAP, and SCAP content
sudo mkdir -p "$CIS_TOOLS_DIR" "$OPENSCAP_DIR" "$SCAP_CONTENT_DIR"
sudo chmod 755 "$CIS_TOOLS_DIR" "$OPENSCAP_DIR" "$SCAP_CONTENT_DIR"

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
    
    # Extract/Install OpenSCAP from S3
    echo ""
    echo "=== Setting up OpenSCAP ==="
    
    # Check for OpenSCAP RPM
    if [ -f "$CIS_TOOLS_DIR/openscap-scanner*.rpm" ]; then
        OPENSCAP_RPM=$(find "$CIS_TOOLS_DIR" -name "openscap-scanner*.rpm" | head -1)
        echo "Found OpenSCAP RPM: $OPENSCAP_RPM"
        echo "Extracting OpenSCAP RPM..."
        
        # Extract RPM to OpenSCAP directory
        TEMP_DIR=$(mktemp -d)
        cd "$TEMP_DIR"
        
        # Extract RPM contents
        if command -v rpm2cpio >/dev/null 2>&1 && command -v cpio >/dev/null 2>&1; then
            rpm2cpio "$OPENSCAP_RPM" | cpio -idmv 2>/dev/null || true
        elif command -v ar >/dev/null 2>&1 && command -v tar >/dev/null 2>&1; then
            ar x "$OPENSCAP_RPM" 2>/dev/null || true
            tar xf *.tar.* 2>/dev/null || true
        fi
        
        # Copy extracted files to OpenSCAP directory
        if [ -d "usr/bin" ]; then
            sudo cp -r usr/bin/* "$OPENSCAP_DIR/" 2>/dev/null || true
        fi
        if [ -d "usr/lib" ]; then
            sudo cp -r usr/lib/* "$OPENSCAP_DIR/" 2>/dev/null || true
        fi
        if [ -d "usr/lib64" ]; then
            sudo cp -r usr/lib64/* "$OPENSCAP_DIR/" 2>/dev/null || true
        fi
        if [ -d "usr/share" ]; then
            sudo cp -r usr/share/* "$OPENSCAP_DIR/" 2>/dev/null || true
        fi
        
        cd - >/dev/null
        rm -rf "$TEMP_DIR"
        
        # Make oscap executable
        if [ -f "$OPENSCAP_DIR/oscap" ]; then
            sudo chmod +x "$OPENSCAP_DIR/oscap"
            echo "✅ OpenSCAP extracted to $OPENSCAP_DIR"
        fi
    fi
    
    # Check for OpenSCAP archive (tar.gz, tar.bz2, zip)
    if [ -f "$CIS_TOOLS_DIR/openscap*.tar.gz" ] || [ -f "$CIS_TOOLS_DIR/openscap*.tar.bz2" ] || [ -f "$CIS_TOOLS_DIR/openscap*.zip" ]; then
        OPENSCAP_ARCHIVE=$(find "$CIS_TOOLS_DIR" -name "openscap*.tar.gz" -o -name "openscap*.tar.bz2" -o -name "openscap*.zip" | head -1)
        echo "Found OpenSCAP archive: $OPENSCAP_ARCHIVE"
        echo "Extracting OpenSCAP archive..."
        
        cd "$OPENSCAP_DIR"
        if [[ "$OPENSCAP_ARCHIVE" == *.tar.gz ]]; then
            sudo tar xzf "$OPENSCAP_ARCHIVE" 2>/dev/null || true
        elif [[ "$OPENSCAP_ARCHIVE" == *.tar.bz2 ]]; then
            sudo tar xjf "$OPENSCAP_ARCHIVE" 2>/dev/null || true
        elif [[ "$OPENSCAP_ARCHIVE" == *.zip ]]; then
            sudo unzip -q "$OPENSCAP_ARCHIVE" 2>/dev/null || true
        fi
        
        # Find and make oscap executable
        if [ -f "$OPENSCAP_DIR/oscap" ]; then
            sudo chmod +x "$OPENSCAP_DIR/oscap"
        elif [ -f "$OPENSCAP_DIR/bin/oscap" ]; then
            sudo chmod +x "$OPENSCAP_DIR/bin/oscap"
        fi
        
        echo "✅ OpenSCAP extracted to $OPENSCAP_DIR"
    fi
    
    # Check for pre-extracted OpenSCAP directory
    if [ -d "$CIS_TOOLS_DIR/openscap" ]; then
        echo "Found pre-extracted OpenSCAP directory"
        sudo cp -r "$CIS_TOOLS_DIR/openscap"/* "$OPENSCAP_DIR/" 2>/dev/null || true
        sudo chmod +x "$OPENSCAP_DIR/oscap" 2>/dev/null || true
        sudo chmod +x "$OPENSCAP_DIR/bin/oscap" 2>/dev/null || true
        echo "✅ OpenSCAP copied to $OPENSCAP_DIR"
    fi
    
    # Check for SCAP content and organize it
    if [ -d "$CIS_TOOLS_DIR/scap-content" ]; then
        echo "Found SCAP content, organizing..."
        sudo cp -r "$CIS_TOOLS_DIR/scap-content"/* "$SCAP_CONTENT_DIR/" 2>/dev/null || true
        sudo chmod -R 644 "$SCAP_CONTENT_DIR"/*.xml 2>/dev/null || true
    fi
    
    # Check for individual SCAP files
    if ls "$CIS_TOOLS_DIR"/*.xml 1>/dev/null 2>&1; then
        echo "Found SCAP XML files, copying to SCAP content directory..."
        sudo cp "$CIS_TOOLS_DIR"/*.xml "$SCAP_CONTENT_DIR/" 2>/dev/null || true
    fi
    
    echo "✅ CIS tools setup complete"
else
    echo "⚠️  WARNING: Failed to download CIS tools from S3"
    echo "   This may be expected if CIS tools are not yet uploaded to S3"
    echo "   Continuing with manual CIS hardening scripts..."
fi

