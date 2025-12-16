#!/bin/bash
# Run CIS assessment tools after hardening
# This script runs CIS assessment tools downloaded from S3

set -euo pipefail

CIS_TOOLS_DIR="/opt/cis-tools"
ASSESSMENT_OUTPUT_DIR="/var/log/cis-assessment"

echo "=== Running CIS Assessment ==="

# Create assessment output directory
sudo mkdir -p "$ASSESSMENT_OUTPUT_DIR"
sudo chmod 755 "$ASSESSMENT_OUTPUT_DIR"

# Check if CIS tools directory exists
if [ ! -d "$CIS_TOOLS_DIR" ]; then
    echo "⚠️  WARNING: CIS tools directory not found at $CIS_TOOLS_DIR"
    echo "   Run download-cis-tools.sh first or ensure CIS tools are available"
    exit 0
fi

# Check for CIS-CAT (CIS Configuration Assessment Tool)
if [ -f "$CIS_TOOLS_DIR/cis-cat-full/CIS-CAT.sh" ]; then
    echo "Found CIS-CAT, running assessment..."
    cd "$CIS_TOOLS_DIR/cis-cat-full"
    
    # Run CIS-CAT assessment for Amazon Linux 2023
    if [ -f "Assessor-CLI.sh" ]; then
        sudo bash Assessor-CLI.sh -b "Amazon Linux 2023 Benchmark" -p "$ASSESSMENT_OUTPUT_DIR" || {
            echo "⚠️  CIS-CAT assessment completed with warnings"
        }
    else
        echo "⚠️  CIS-CAT Assessor-CLI.sh not found"
    fi
fi

# Check for CIS Workbench scripts
if [ -d "$CIS_TOOLS_DIR/cis-workbench" ]; then
    echo "Found CIS Workbench scripts..."
    cd "$CIS_TOOLS_DIR/cis-workbench"
    
    # Run CIS Workbench assessment if available
    if [ -f "assess.sh" ]; then
        sudo bash assess.sh > "$ASSESSMENT_OUTPUT_DIR/workbench-assessment.txt" 2>&1 || {
            echo "⚠️  CIS Workbench assessment completed with warnings"
        }
    fi
fi

# Generate summary report
echo ""
echo "=== CIS Assessment Summary ==="
echo "Assessment output directory: $ASSESSMENT_OUTPUT_DIR"
echo ""
echo "Assessment files:"
ls -lah "$ASSESSMENT_OUTPUT_DIR" || true

echo ""
echo "✅ CIS Assessment Complete"
echo "Review assessment reports in: $ASSESSMENT_OUTPUT_DIR"

