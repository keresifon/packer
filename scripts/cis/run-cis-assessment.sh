#!/bin/bash
# Run CIS assessment using OpenSCAP after hardening
# This script uses OpenSCAP to assess CIS Level 2 compliance

set -euo pipefail

# Check if CIS hardening is enabled
if [ "${ENABLE_CIS_HARDENING:-false}" != "true" ]; then
    echo "⚠️  CIS hardening is disabled, skipping CIS assessment"
    exit 0
fi

OPENSCAP_DIR="/opt/openscap"
SCAP_CONTENT_DIR="/opt/scap-content"
ASSESSMENT_OUTPUT_DIR="/var/log/cis-assessment"
SCAP_PROFILE="${SCAP_PROFILE:-xccdf_org.cisecurity.benchmarks_profile_Level_2-Server}"

echo "=== Running CIS Assessment with OpenSCAP ==="

# Create assessment output directory
sudo mkdir -p "$ASSESSMENT_OUTPUT_DIR"
sudo chmod 755 "$ASSESSMENT_OUTPUT_DIR"

# Find OpenSCAP binary
OSCAP_BIN=""
if [ -f "$OPENSCAP_DIR/oscap" ]; then
    OSCAP_BIN="$OPENSCAP_DIR/oscap"
elif [ -f "$OPENSCAP_DIR/bin/oscap" ]; then
    OSCAP_BIN="$OPENSCAP_DIR/bin/oscap"
elif command -v oscap >/dev/null 2>&1; then
    OSCAP_BIN="oscap"
else
    echo "❌ ERROR: OpenSCAP not found"
    echo "   Expected locations:"
    echo "   - $OPENSCAP_DIR/oscap"
    echo "   - $OPENSCAP_DIR/bin/oscap"
    echo "   - System PATH (oscap)"
    echo ""
    echo "   Please ensure OpenSCAP is downloaded from S3"
    echo "   Expected S3 location: s3://${CIS_S3_BUCKET:-your-bucket}/${CIS_S3_PREFIX:-cis-tools}/openscap*"
    exit 1
fi

# Add OpenSCAP directory to PATH and LD_LIBRARY_PATH if needed
if [ -d "$OPENSCAP_DIR" ]; then
    export PATH="$OPENSCAP_DIR:$OPENSCAP_DIR/bin:$PATH"
    if [ -d "$OPENSCAP_DIR/lib" ]; then
        export LD_LIBRARY_PATH="$OPENSCAP_DIR/lib:${LD_LIBRARY_PATH:-}"
    fi
    if [ -d "$OPENSCAP_DIR/lib64" ]; then
        export LD_LIBRARY_PATH="$OPENSCAP_DIR/lib64:${LD_LIBRARY_PATH:-}"
    fi
fi

echo "Using OpenSCAP: $OSCAP_BIN"
echo "OpenSCAP version:"
"$OSCAP_BIN" --version || true

# Check for SCAP content from S3
SCAP_XCCDF_FILE=""
if [ -n "${CIS_S3_BUCKET:-}" ] && [ -d "$SCAP_CONTENT_DIR" ]; then
    # Look for CIS benchmark SCAP content
    SCAP_XCCDF_FILE=$(find "$SCAP_CONTENT_DIR" -name "*CIS_Amazon_Linux_2023*" -o -name "*cis-amazon-linux-2023*" -o -name "*amazon-linux-2023*cis*.xml" | grep -i xccdf | head -1)
    
    if [ -z "$SCAP_XCCDF_FILE" ]; then
        # Try to find any XCCDF file
        SCAP_XCCDF_FILE=$(find "$SCAP_CONTENT_DIR" -name "*.xml" -type f | head -1)
    fi
fi

# If no SCAP content from S3, try to use system SCAP content
if [ -z "$SCAP_XCCDF_FILE" ]; then
    echo "⚠️  No SCAP content found in $SCAP_CONTENT_DIR"
    echo "   Checking for system SCAP content..."
    
    # Check common SCAP content locations
    if [ -d "/usr/share/xml/scap/ssg/content" ]; then
        SCAP_XCCDF_FILE=$(find /usr/share/xml/scap/ssg/content -name "*amazon*2023*.xml" -o -name "*al2023*.xml" | grep -i xccdf | head -1)
    fi
    
    if [ -z "$SCAP_XCCDF_FILE" ]; then
        echo "⚠️  WARNING: No SCAP content found for assessment"
        echo "   Please upload CIS Amazon Linux 2023 SCAP content to S3"
        echo "   Expected location: s3://${CIS_S3_BUCKET:-your-bucket}/${CIS_S3_PREFIX:-cis-tools}/scap-content/"
        exit 0
    fi
fi

if [ -n "$SCAP_XCCDF_FILE" ] && [ -f "$SCAP_XCCDF_FILE" ]; then
    echo "Using SCAP content: $SCAP_XCCDF_FILE"
    
    # List available profiles
    echo ""
    echo "Available profiles:"
    "$OSCAP_BIN" xccdf eval --profiles "$SCAP_XCCDF_FILE" 2>&1 | head -20 || true
    
    # Run OpenSCAP assessment
    echo ""
    echo "Running OpenSCAP assessment with profile: $SCAP_PROFILE"
    
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    ASSESSMENT_XML="$ASSESSMENT_OUTPUT_DIR/oscap-assessment-${TIMESTAMP}.xml"
    ASSESSMENT_HTML="$ASSESSMENT_OUTPUT_DIR/oscap-assessment-${TIMESTAMP}.html"
    ASSESSMENT_REPORT="$ASSESSMENT_OUTPUT_DIR/oscap-report-${TIMESTAMP}.txt"
    
    # Run XCCDF evaluation
    if sudo "$OSCAP_BIN" xccdf eval \
        --profile "$SCAP_PROFILE" \
        --results "$ASSESSMENT_XML" \
        --report "$ASSESSMENT_HTML" \
        "$SCAP_XCCDF_FILE" > "$ASSESSMENT_REPORT" 2>&1; then
        echo "✅ OpenSCAP assessment completed successfully"
    else
        ASSESSMENT_EXIT=$?
        echo "⚠️  OpenSCAP assessment completed with exit code: $ASSESSMENT_EXIT"
        echo "   This may indicate some controls failed (which is expected during hardening)"
    fi
    
    # Generate summary
    echo ""
    echo "=== Assessment Results Summary ==="
    if [ -f "$ASSESSMENT_XML" ]; then
        echo "XML Results: $ASSESSMENT_XML"
        
        # Extract pass/fail counts if possible
        if command -v xmllint >/dev/null 2>&1; then
            echo ""
            echo "Result Summary:"
            xmllint --xpath "//*[local-name()='result']/@id" "$ASSESSMENT_XML" 2>/dev/null | head -5 || true
        fi
    fi
    
    if [ -f "$ASSESSMENT_HTML" ]; then
        echo "HTML Report: $ASSESSMENT_HTML"
    fi
    
    if [ -f "$ASSESSMENT_REPORT" ]; then
        echo "Text Report: $ASSESSMENT_REPORT"
        echo ""
        echo "Last 20 lines of assessment:"
        tail -20 "$ASSESSMENT_REPORT" || true
    fi
else
    echo "❌ ERROR: SCAP content file not found or not accessible"
    echo "   File: ${SCAP_XCCDF_FILE:-not found}"
    exit 1
fi

# Also check for CIS-CAT if available (for comparison)
CIS_TOOLS_DIR="/opt/cis-tools"
if [ -n "${CIS_S3_BUCKET:-}" ] && [ -f "$CIS_TOOLS_DIR/cis-cat-full/CIS-CAT.sh" ]; then
    echo ""
    echo "=== Running CIS-CAT Assessment (if available) ==="
    cd "$CIS_TOOLS_DIR/cis-cat-full"
    
    if [ -f "Assessor-CLI.sh" ]; then
        sudo bash Assessor-CLI.sh -b "Amazon Linux 2023 Benchmark" -p "$ASSESSMENT_OUTPUT_DIR" 2>&1 || {
            echo "⚠️  CIS-CAT assessment completed with warnings"
        }
    fi
fi

# Generate final summary
echo ""
echo "=== CIS Assessment Complete ==="
echo "Assessment output directory: $ASSESSMENT_OUTPUT_DIR"
echo ""
echo "Assessment files:"
ls -lah "$ASSESSMENT_OUTPUT_DIR" || true

echo ""
echo "✅ CIS Assessment Complete"
echo "Review assessment reports in: $ASSESSMENT_OUTPUT_DIR"
echo ""
echo "To view HTML report, download: $ASSESSMENT_HTML"

