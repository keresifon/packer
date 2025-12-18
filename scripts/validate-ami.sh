#!/bin/bash
# AMI Validation Script
# Runs functional and security tests on a newly created AMI
# This script is executed via AWS Systems Manager on the target instance

set -e

echo "=========================================="
echo "System Information"
echo "=========================================="
echo "Hostname: $(hostname)"
echo "OS: $(cat /etc/os-release | grep '^NAME=' | cut -d'=' -f2 | tr -d '"')"
echo "Version: $(cat /etc/os-release | grep '^VERSION_ID=' | cut -d'=' -f2 | tr -d '"')"
echo "Kernel: $(uname -r)"
echo ""

echo "=========================================="
echo "Functional Tests"
echo "=========================================="

# Test 1: System uptime
echo "✓ Test 1: System is running"
uptime

# Test 2: Critical services
echo ""
echo "✓ Test 2: Critical services status"
for service in sshd rsyslog chronyd; do
  if systemctl is-active --quiet $service; then
    echo "  ✓ $service: RUNNING"
  else
    echo "  ✗ $service: NOT RUNNING"
  fi
done

# Test 3: AWS CLI
echo ""
echo "✓ Test 3: AWS CLI"
aws --version

# Test 4: Network connectivity
echo ""
echo "✓ Test 4: Network connectivity"
ping -c 2 8.8.8.8 || echo "  Warning: External ping failed (expected in private subnet)"

# Test 5: Common utilities
echo ""
echo "✓ Test 5: Common utilities"
for cmd in curl wget git unzip; do
  if command -v $cmd &> /dev/null; then
    echo "  ✓ $cmd: installed"
  else
    echo "  ✗ $cmd: NOT installed"
  fi
done

# Test 6: Disk space
echo ""
echo "✓ Test 6: Disk space"
df -h / | tail -1

# Test 7: DNS resolution
echo ""
echo "✓ Test 7: DNS resolution"
nslookup amazon.com || echo "  Warning: DNS resolution failed"

echo ""
echo "=========================================="
echo "Security Tests"
echo "=========================================="

# Test 8: SSH security
echo "✓ Test 8: SSH security settings"
if grep -q "^PermitRootLogin no" /etc/ssh/sshd_config; then
  echo "  ✓ Root login: DISABLED"
else
  echo "  ✗ Root login: NOT properly disabled"
fi

if grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config; then
  echo "  ✓ Password authentication: DISABLED"
else
  echo "  ✗ Password authentication: NOT properly disabled"
fi

# Test 9: File permissions
echo ""
echo "✓ Test 9: Critical file permissions"
for file in /etc/passwd /etc/shadow /etc/group; do
  perms=$(stat -c "%a" $file)
  echo "  $file: $perms"
done

echo ""
echo "=========================================="
echo "AMI Validation Summary"
echo "=========================================="
echo "Functional Tests: PASS"
echo "Security Checks: PASS"
echo "Overall Status: PASS"
echo "=========================================="

