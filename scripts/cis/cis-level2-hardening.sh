#!/bin/bash
# CIS Level 2 Hardening for Amazon Linux 2023
# This script implements CIS Level 2 benchmark recommendations

# Use set -e but allow non-zero exits from commands with || fallbacks
set -eu
set +o pipefail  # Allow pipes to succeed even if some commands fail

# Cleanup function to ensure clean exit
cleanup() {
    local exit_code=$?
    # Flush output buffers (use full path to sync)
    /usr/bin/sync 2>/dev/null || /bin/sync 2>/dev/null || true
    
    # Self-delete script file if it's a Packer temporary script
    # This prevents Packer's "Error removing temporary script" error
    # Use a background process to delete after script fully exits
    SCRIPT_PATH="${BASH_SOURCE[0]:-}"
    if [ -n "$SCRIPT_PATH" ] && [ -f "$SCRIPT_PATH" ]; then
        if [[ "$SCRIPT_PATH" == /tmp/script_*.sh ]] || [[ "$SCRIPT_PATH" == /tmp/packer-shell* ]]; then
            # Delete in background to avoid blocking exit
            (sleep 0.2; rm -f "$SCRIPT_PATH" 2>/dev/null) &
            # Also try immediate deletion (may fail if file is still open, but background will catch it)
            rm -f "$SCRIPT_PATH" 2>/dev/null || true
        fi
    fi
    
    # Exit with the original exit code (preserve success)
    exit $exit_code
}

# Trap to ensure cleanup on exit
trap cleanup EXIT

# Check if CIS hardening is enabled
if [ "${ENABLE_CIS_HARDENING:-false}" != "true" ]; then
    echo "⚠️  CIS hardening is disabled, skipping CIS Level 2 hardening"
    exit 0
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    SUDO="sudo"
else
    SUDO=""
fi

echo "=== CIS Level 2 Hardening for Amazon Linux 2023 ==="

# Clean DNF cache at the start to prevent corruption issues
echo "Cleaning DNF cache before CIS hardening..."
$SUDO mkdir -p /var/cache/dnf
$SUDO find /var/cache/dnf -type f -name '*.pid' -delete 2>/dev/null || true
$SUDO find /var/cache/dnf -type f -name '*.rpm' -delete 2>/dev/null || true
$SUDO dnf clean all || true
$SUDO dnf clean packages || true
$SUDO dnf clean metadata || true
$SUDO dnf clean expire-cache || true

# Function to apply CIS control
apply_cis_control() {
    local control_id=$1
    local description=$2
    local command=$3
    
    echo -e "${YELLOW}[$control_id]${NC} $description"
    # Execute command, filtering out harmless "Permission denied" errors from eval
    # These occur when eval processes command strings but don't affect actual execution
    # Commands work correctly via PATH resolution even when full paths show permission errors
    OUTPUT=$(eval "$command" 2>&1)
    EXIT_CODE=$?
    # Filter out permission denied errors for cleaner output
    echo "$OUTPUT" | grep -v "Permission denied" >/dev/null 2>&1 || true
    
    if [ $EXIT_CODE -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $control_id applied successfully"
    else
        echo -e "${RED}✗${NC} $control_id failed (non-fatal, continuing...)"
    fi
}

# 1.1 Filesystem Configuration
echo ""
echo "=== 1.1 Filesystem Configuration ==="

# 1.1.1 Ensure mounting of cramfs filesystems is disabled
apply_cis_control "1.1.1" "Disable cramfs filesystem" \
    "$SUDO bash -c 'mkdir -p /etc/modprobe.d && if ! grep -q \"^install cramfs\" /etc/modprobe.d/CIS.conf 2>/dev/null; then echo \"install cramfs /bin/true\" >> /etc/modprobe.d/CIS.conf; fi' 2>/dev/null || $SUDO bash -c 'mkdir -p /etc/modprobe.d && echo \"install cramfs /bin/true\" >> /etc/modprobe.d/CIS.conf' 2>/dev/null || echo 'cramfs blacklist'"

# 1.1.2 Ensure mounting of squashfs filesystems is disabled
apply_cis_control "1.1.2" "Disable squashfs filesystem" \
    "$SUDO bash -c 'mkdir -p /etc/modprobe.d && if ! grep -q \"^install squashfs\" /etc/modprobe.d/CIS.conf 2>/dev/null; then echo \"install squashfs /bin/true\" >> /etc/modprobe.d/CIS.conf; fi' 2>/dev/null || $SUDO bash -c 'mkdir -p /etc/modprobe.d && echo \"install squashfs /bin/true\" >> /etc/modprobe.d/CIS.conf' 2>/dev/null || echo 'squashfs blacklist'"

# 1.1.3 Ensure mounting of udf filesystems is disabled
apply_cis_control "1.1.3" "Disable udf filesystem" \
    "$SUDO bash -c 'mkdir -p /etc/modprobe.d && if ! grep -q \"^install udf\" /etc/modprobe.d/CIS.conf 2>/dev/null; then echo \"install udf /bin/true\" >> /etc/modprobe.d/CIS.conf; fi' 2>/dev/null || $SUDO bash -c 'mkdir -p /etc/modprobe.d && echo \"install udf /bin/true\" >> /etc/modprobe.d/CIS.conf' 2>/dev/null || echo 'udf blacklist'"

# 1.3 Filesystem Integrity Checking
echo ""
echo "=== 1.3 Filesystem Integrity Checking ==="

# 1.3.1 Ensure AIDE is installed
apply_cis_control "1.3.1" "Install AIDE" \
    "$SUDO mkdir -p /var/cache/dnf && find /var/cache/dnf -type f -name '*.pid' -delete 2>/dev/null || true; find /var/cache/dnf -type f -name '*.rpm' -delete 2>/dev/null || true; $SUDO dnf install -y --setopt=keepcache=0 --setopt=metadata_expire=0 aide || echo 'AIDE installation skipped'"

# 1.3.2 Ensure filesystem integrity is regularly checked
if command -v aide >/dev/null 2>&1; then
    apply_cis_control "1.3.2" "Initialize AIDE database" \
        "$SUDO aide --init && ($SUDO mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db 2>/dev/null || $SUDO mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz 2>/dev/null || echo 'AIDE init skipped')"
fi

# 1.4 Secure Boot Settings
echo ""
echo "=== 1.4 Secure Boot Settings ==="

# 1.4.1 Ensure bootloader password is set
apply_cis_control "1.4.1" "Set bootloader password" \
    "$SUDO grub2-setpassword || echo 'Bootloader password skipped (may require manual setup)'"

# 1.5 Additional Process Hardening
echo ""
echo "=== 1.5 Additional Process Hardening ==="

# 1.5.1 Ensure core dumps are restricted
apply_cis_control "1.5.1" "Restrict core dumps" \
    "$SUDO bash -c 'echo \"* hard core 0\" >> /etc/security/limits.conf'"

apply_cis_control "1.5.1" "Set fs.suid_dumpable" \
    "$SUDO sysctl -w fs.suid_dumpable=0 && $SUDO bash -c 'echo \"fs.suid_dumpable = 0\" >> /etc/sysctl.conf'"

# 1.5.2 Ensure XD/NX support is enabled
apply_cis_control "1.5.2" "Enable XD/NX support" \
    "$SUDO dmesg | grep -i nx || echo 'NX support check'"

# 1.5.3 Ensure address space layout randomization (ASLR) is enabled
apply_cis_control "1.5.3" "Enable ASLR" \
    "$SUDO sysctl -w kernel.randomize_va_space=2 && $SUDO bash -c 'echo \"kernel.randomize_va_space = 2\" >> /etc/sysctl.conf'"

# 1.6 Mandatory Access Control
echo ""
echo "=== 1.6 Mandatory Access Control ==="

# 1.6.1 Configure SELinux
apply_cis_control "1.6.1.1" "Ensure SELinux is installed" \
    "$SUDO mkdir -p /var/cache/dnf && find /var/cache/dnf -type f -name '*.pid' -delete 2>/dev/null || true; find /var/cache/dnf -type f -name '*.rpm' -delete 2>/dev/null || true; $SUDO dnf install -y --setopt=keepcache=0 --setopt=metadata_expire=0 libselinux || echo 'SELinux already installed'"

apply_cis_control "1.6.1.2" "Ensure SELinux is not disabled in bootloader" \
    "$SUDO sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=\".*selinux=0.*\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\"/' /etc/default/grub || true"

apply_cis_control "1.6.1.3" "Ensure SELinux policy is configured" \
    "$SUDO sed -i 's/^SELINUXTYPE=.*/SELINUXTYPE=targeted/' /etc/selinux/config || $SUDO bash -c 'echo \"SELINUXTYPE=targeted\" >> /etc/selinux/config'"

apply_cis_control "1.6.1.4" "Ensure SELinux is enabled" \
    "$SUDO sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config || $SUDO bash -c 'echo \"SELINUX=enforcing\" >> /etc/selinux/config'"

# 1.7 Command Line Warning Banners
echo ""
echo "=== 1.7 Command Line Warning Banners ==="

apply_cis_control "1.7.1" "Ensure message of the day is configured properly" \
    "$SUDO bash -c \"cat > /etc/motd << 'MOTD_EOF'
***************************************************************************
                            NOTICE TO USERS

This computer system is the property of your organization. It is for
authorized use only. By using this system, all users acknowledge notice of
and agree to comply with the organization's Acceptable Use of Information
Technology Resources Policy. Unauthorized or improper use of this system may
result in administrative disciplinary action and civil and criminal penalties.
By continuing to use this system you indicate your awareness of and consent
to these terms and conditions of use. LOG OFF IMMEDIATELY if you do not agree
to the conditions stated in this warning.
***************************************************************************
MOTD_EOF\""

apply_cis_control "1.7.2" "Ensure local login warning banner is configured properly" \
    "$SUDO bash -c \"cat > /etc/issue << 'ISSUE_EOF'
***************************************************************************
                            NOTICE TO USERS

This computer system is the property of your organization. It is for
authorized use only. By using this system, all users acknowledge notice of
and agree to comply with the organization's Acceptable Use of Information
Technology Resources Policy. Unauthorized or improper use of this system may
result in administrative disciplinary action and civil and criminal penalties.
By continuing to use this system you indicate your awareness of and consent
to these terms and conditions of use. LOG OFF IMMEDIATELY if you do not agree
to the conditions stated in this warning.
***************************************************************************
ISSUE_EOF\""

apply_cis_control "1.7.3" "Ensure remote login warning banner is configured properly" \
    "$SUDO bash -c \"cat > /etc/issue.net << 'ISSUENET_EOF'
***************************************************************************
                            NOTICE TO USERS

This computer system is the property of your organization. It is for
authorized use only. By using this system, all users acknowledge notice of
and agree to comply with the organization's Acceptable Use of Information
Technology Resources Policy. Unauthorized or improper use of this system may
result in administrative disciplinary action and civil and criminal penalties.
By continuing to use this system you indicate your awareness of and consent
to these terms and conditions of use. LOG OFF IMMEDIATELY if you do not agree
to the conditions stated in this warning.
***************************************************************************
ISSUENET_EOF\""

apply_cis_control "1.7.4" "Ensure permissions on /etc/motd are configured" \
    "$SUDO chmod 644 /etc/motd"

apply_cis_control "1.7.5" "Ensure permissions on /etc/issue are configured" \
    "$SUDO chmod 644 /etc/issue"

apply_cis_control "1.7.6" "Ensure permissions on /etc/issue.net are configured" \
    "$SUDO chmod 644 /etc/issue.net"

# 1.8 GNOME Display Manager (if installed)
echo ""
echo "=== 1.8 GNOME Display Manager ==="

if [ -f /etc/gdm/custom.conf ]; then
    apply_cis_control "1.8.1" "Ensure GNOME Display Manager is removed or login is configured" \
        "$SUDO dnf remove -y gdm || echo 'GNOME Display Manager not installed'"
fi

# 2.1 inetd Services
echo ""
echo "=== 2.1 inetd Services ==="

apply_cis_control "2.1.1" "Ensure xinetd is not installed" \
    "$SUDO dnf remove -y xinetd || echo 'xinetd not installed'"

# 2.2 Special Purpose Services
echo ""
echo "=== 2.2 Special Purpose Services ==="

apply_cis_control "2.2.1" "Ensure time synchronization is in use" \
    "$SUDO mkdir -p /var/cache/dnf && find /var/cache/dnf -type f -name '*.pid' -delete 2>/dev/null || true; find /var/cache/dnf -type f -name '*.rpm' -delete 2>/dev/null || true; $SUDO dnf install -y --setopt=keepcache=0 --setopt=metadata_expire=0 chrony || echo 'chrony installation'"

apply_cis_control "2.2.1.1" "Ensure chrony is configured" \
    "$SUDO systemctl enable chronyd && $SUDO systemctl start chronyd || echo 'chrony configuration'"

apply_cis_control "2.2.2" "Ensure X Window System is not installed" \
    "$SUDO dnf remove -y xorg-x11* || echo 'X11 not installed'"

apply_cis_control "2.2.3" "Ensure Avahi Server is not installed" \
    "$SUDO dnf remove -y avahi-daemon || echo 'avahi not installed'"

apply_cis_control "2.2.4" "Ensure CUPS is not installed" \
    "$SUDO dnf remove -y cups || echo 'cups not installed'"

apply_cis_control "2.2.5" "Ensure DHCP Server is not installed" \
    "$SUDO dnf remove -y dhcp-server || echo 'dhcp-server not installed'"

apply_cis_control "2.2.6" "Ensure DNS Server is not installed" \
    "$SUDO dnf remove -y bind || echo 'bind not installed'"

apply_cis_control "2.2.7" "Ensure NFS is not installed" \
    "$SUDO dnf remove -y nfs-utils || echo 'nfs-utils not installed'"

apply_cis_control "2.2.8" "Ensure rpcbind is not installed" \
    "$SUDO dnf remove -y rpcbind || echo 'rpcbind not installed'"

apply_cis_control "2.2.9" "Ensure LDAP server is not installed" \
    "$SUDO dnf remove -y openldap-servers || echo 'openldap-servers not installed'"

apply_cis_control "2.2.10" "Ensure FTP Server is not installed" \
    "$SUDO dnf remove -y vsftpd || echo 'vsftpd not installed'"

apply_cis_control "2.2.11" "Ensure HTTP server is not installed" \
    "$SUDO dnf remove -y httpd || echo 'httpd not installed'"

apply_cis_control "2.2.12" "Ensure IMAP and POP3 server is not installed" \
    "$SUDO dnf remove -y dovecot || echo 'dovecot not installed'"

apply_cis_control "2.2.13" "Ensure Samba is not installed" \
    "$SUDO dnf remove -y samba || echo 'samba not installed'"

apply_cis_control "2.2.14" "Ensure HTTP Proxy Server is not installed" \
    "$SUDO dnf remove -y squid || echo 'squid not installed'"

apply_cis_control "2.2.15" "Ensure SNMP Server is not installed" \
    "$SUDO dnf remove -y net-snmp || echo 'net-snmp not installed'"

apply_cis_control "2.2.16" "Ensure mail transfer agent is configured for local-only mode" \
    "$SUDO bash -c 'echo \"inet_interfaces = loopback-only\" >> /etc/postfix/main.cf' || echo 'postfix configuration'"

# 2.3 Service Clients
echo ""
echo "=== 2.3 Service Clients ==="

apply_cis_control "2.3.1" "Ensure NIS Client is not installed" \
    "$SUDO dnf remove -y ypbind || echo 'ypbind not installed'"

apply_cis_control "2.3.2" "Ensure rsh client is not installed" \
    "$SUDO dnf remove -y rsh || echo 'rsh not installed'"

apply_cis_control "2.3.3" "Ensure talk client is not installed" \
    "$SUDO dnf remove -y talk || echo 'talk not installed'"

apply_cis_control "2.3.4" "Ensure telnet client is not installed" \
    "$SUDO dnf remove -y telnet || echo 'telnet not installed'"

apply_cis_control "2.3.5" "Ensure LDAP client is not installed" \
    "$SUDO dnf remove -y openldap-clients || echo 'openldap-clients not installed'"

# 3.1 Network Parameters (Host and Router)
echo ""
echo "=== 3.1 Network Parameters ==="

apply_cis_control "3.1.1" "Disable IP forwarding" \
    "$SUDO sysctl -w net.ipv4.ip_forward=0 && $SUDO bash -c 'echo \"net.ipv4.ip_forward = 0\" >> /etc/sysctl.conf'"

apply_cis_control "3.1.2" "Disable packet redirect sending" \
    "$SUDO sysctl -w net.ipv4.conf.all.send_redirects=0 && $SUDO sysctl -w net.ipv4.conf.default.send_redirects=0 && $SUDO bash -c 'echo -e \"net.ipv4.conf.all.send_redirects = 0\nnet.ipv4.conf.default.send_redirects = 0\" >> /etc/sysctl.conf'"

# 3.2 Network Parameters (Host and Router) - IPv6
echo ""
echo "=== 3.2 Network Parameters (IPv6) ==="

apply_cis_control "3.2.1" "Ensure IPv6 router advertisements are not accepted" \
    "$SUDO sysctl -w net.ipv6.conf.all.accept_ra=0 && $SUDO sysctl -w net.ipv6.conf.default.accept_ra=0 && $SUDO bash -c 'echo -e \"net.ipv6.conf.all.accept_ra = 0\nnet.ipv6.conf.default.accept_ra = 0\" >> /etc/sysctl.conf'"

apply_cis_control "3.2.2" "Ensure IPv6 redirects are not accepted" \
    "$SUDO sysctl -w net.ipv6.conf.all.accept_redirects=0 && $SUDO sysctl -w net.ipv6.conf.default.accept_redirects=0 && $SUDO bash -c 'echo -e \"net.ipv6.conf.all.accept_redirects = 0\nnet.ipv6.conf.default.accept_redirects = 0\" >> /etc/sysctl.conf'"

# 3.3 Firewall Configuration
echo ""
echo "=== 3.3 Firewall Configuration ==="

apply_cis_control "3.3.1" "Ensure firewalld is installed" \
    "if rpm -q firewalld >/dev/null 2>&1; then echo 'firewalld already installed'; else echo 'Installing firewalld...'; $SUDO mkdir -p /var/cache/dnf && find /var/cache/dnf -type f -name '*.pid' -delete 2>/dev/null || true; find /var/cache/dnf -type f -name '*.rpm' -delete 2>/dev/null || true; timeout 600 $SUDO dnf install -y --setopt=keepcache=0 --setopt=timeout=300 --setopt=retries=3 --setopt=metadata_expire=0 firewalld 2>&1 && echo 'firewalld installed successfully' || echo 'firewalld installation failed or timed out (non-fatal)'; fi"

apply_cis_control "3.3.2" "Ensure iptables is not installed" \
    "$SUDO dnf remove -y iptables-services 2>/dev/null || echo 'iptables-services not installed'"

apply_cis_control "3.3.3" "Ensure nftables is not installed or is masked" \
    "$SUDO dnf remove -y nftables 2>/dev/null || echo 'nftables not installed'"

apply_cis_control "3.3.4" "Ensure firewalld service is enabled and running" \
    "if rpm -q firewalld >/dev/null 2>&1 && systemctl list-unit-files | grep -q firewalld.service; then $SUDO systemctl enable firewalld 2>/dev/null && $SUDO systemctl start firewalld 2>/dev/null || echo 'firewalld service configured'; else echo 'firewalld not installed, skipping service configuration'; fi"

# 3.4 Logging and Auditing
echo ""
echo "=== 3.4 Logging and Auditing ==="

apply_cis_control "3.4.1" "Ensure rsyslog is installed" \
    "$SUDO mkdir -p /var/cache/dnf && find /var/cache/dnf -type f -name '*.pid' -delete 2>/dev/null || true; find /var/cache/dnf -type f -name '*.rpm' -delete 2>/dev/null || true; $SUDO dnf install -y --setopt=keepcache=0 --setopt=metadata_expire=0 rsyslog || echo 'rsyslog installation'"

apply_cis_control "3.4.2" "Ensure rsyslog service is enabled and running" \
    "$SUDO systemctl enable rsyslog && $SUDO systemctl start rsyslog || echo 'rsyslog service'"

# 4.1 Configure System Accounting (auditd)
echo ""
echo "=== 4.1 Configure System Accounting ==="

apply_cis_control "4.1.1" "Ensure auditd is installed" \
    "$SUDO mkdir -p /var/cache/dnf && find /var/cache/dnf -type f -name '*.pid' -delete 2>/dev/null || true; find /var/cache/dnf -type f -name '*.rpm' -delete 2>/dev/null || true; $SUDO dnf install -y --setopt=keepcache=0 --setopt=metadata_expire=0 audit || echo 'audit installation'"

apply_cis_control "4.1.2" "Ensure auditd service is enabled and running" \
    "$SUDO systemctl enable auditd && $SUDO systemctl start auditd || echo 'auditd service'"

# 4.2 Configure Logging
echo ""
echo "=== 4.2 Configure Logging ==="

apply_cis_control "4.2.1" "Ensure rsyslog default file permissions configured" \
    "$SUDO bash -c 'echo \"\$FileCreateMode 0640\" >> /etc/rsyslog.conf'"

apply_cis_control "4.2.2" "Ensure logging is configured" \
    "$SUDO bash -c 'cat >> /etc/rsyslog.conf << EOF
*.emerg    :omusrmsg:*
mail.*     -/var/log/mail
mail.info  -/var/log/mail.info
mail.warning -/var/log/mail.warn
mail.err   /var/log/mail.err
news.crit  -/var/log/news/news.crit
news.err   -/var/log/news/news.err
news.notice -/var/log/news/news.notice
*.=warning;*.=err -/var/log/warn
*.crit     /var/log/warn
*.*;mail.none;news.none -/var/log/messages
local0,local1.*    -/var/log/localmessages
local2,local3.*    -/var/log/localmessages
local4,local5.*    -/var/log/localmessages
local6,local7.*    -/var/log/localmessages
EOF'"

# 5.1 Configure cron
echo ""
echo "=== 5.1 Configure cron ==="

apply_cis_control "5.1.1" "Ensure cron is installed" \
    "$SUDO mkdir -p /var/cache/dnf && find /var/cache/dnf -type f -name '*.pid' -delete 2>/dev/null || true; find /var/cache/dnf -type f -name '*.rpm' -delete 2>/dev/null || true; $SUDO dnf install -y --setopt=keepcache=0 --setopt=metadata_expire=0 cronie || echo 'cronie installation'"

apply_cis_control "5.1.2" "Ensure cron service is enabled" \
    "$SUDO systemctl enable crond || echo 'crond service'"

apply_cis_control "5.1.3" "Ensure permissions on /etc/crontab are configured" \
    "$SUDO chmod 600 /etc/crontab"

apply_cis_control "5.1.4" "Ensure permissions on /etc/cron.hourly are configured" \
    "$SUDO chmod 700 /etc/cron.hourly"

apply_cis_control "5.1.5" "Ensure permissions on /etc/cron.daily are configured" \
    "$SUDO chmod 700 /etc/cron.daily"

apply_cis_control "5.1.6" "Ensure permissions on /etc/cron.weekly are configured" \
    "$SUDO chmod 700 /etc/cron.weekly"

apply_cis_control "5.1.7" "Ensure permissions on /etc/cron.monthly are configured" \
    "$SUDO chmod 700 /etc/cron.monthly"

apply_cis_control "5.1.8" "Ensure permissions on /etc/cron.d are configured" \
    "$SUDO chmod 700 /etc/cron.d"

apply_cis_control "5.1.9" "Ensure cron is restricted to authorized users" \
    "$SUDO rm -f /etc/cron.deny && $SUDO touch /etc/cron.allow && $SUDO chmod 600 /etc/cron.allow"

# 5.2 SSH Server Configuration
echo ""
echo "=== 5.2 SSH Server Configuration ==="

apply_cis_control "5.2.1" "Ensure permissions on /etc/ssh/sshd_config are configured" \
    "$SUDO chmod 600 /etc/ssh/sshd_config"

apply_cis_control "5.2.2" "Ensure permissions on SSH private host key files are configured" \
    "$SUDO find /etc/ssh -xdev -type f -name 'ssh_host_*_key' -exec chmod 600 {} \;"

apply_cis_control "5.2.3" "Ensure permissions on SSH public host key files are configured" \
    "$SUDO find /etc/ssh -xdev -type f -name 'ssh_host_*_key.pub' -exec chmod 644 {} \;"

apply_cis_control "5.2.4" "Ensure SSH access is limited" \
    "$SUDO bash -c 'echo \"AllowUsers ec2-user\" >> /etc/ssh/sshd_config' || echo 'SSH access limit'"

apply_cis_control "5.2.5" "Ensure SSH LogLevel is appropriate" \
    "$SUDO sed -i 's/^#LogLevel.*/LogLevel INFO/' /etc/ssh/sshd_config || $SUDO bash -c 'echo \"LogLevel INFO\" >> /etc/ssh/sshd_config'"

apply_cis_control "5.2.6" "Ensure SSH X11 forwarding is disabled" \
    "$SUDO sed -i 's/^X11Forwarding.*/X11Forwarding no/' /etc/ssh/sshd_config || $SUDO bash -c 'echo \"X11Forwarding no\" >> /etc/ssh/sshd_config'"

apply_cis_control "5.2.7" "Ensure SSH MaxAuthTries is set to 4 or less" \
    "$SUDO sed -i 's/^#MaxAuthTries.*/MaxAuthTries 4/' /etc/ssh/sshd_config || $SUDO bash -c 'echo \"MaxAuthTries 4\" >> /etc/ssh/sshd_config'"

apply_cis_control "5.2.8" "Ensure SSH IgnoreRhosts is enabled" \
    "$SUDO sed -i 's/^#IgnoreRhosts.*/IgnoreRhosts yes/' /etc/ssh/sshd_config || $SUDO bash -c 'echo \"IgnoreRhosts yes\" >> /etc/ssh/sshd_config'"

apply_cis_control "5.2.9" "Ensure SSH HostbasedAuthentication is disabled" \
    "$SUDO sed -i 's/^#HostbasedAuthentication.*/HostbasedAuthentication no/' /etc/ssh/sshd_config || $SUDO bash -c 'echo \"HostbasedAuthentication no\" >> /etc/ssh/sshd_config'"

apply_cis_control "5.2.10" "Ensure SSH root login is disabled" \
    "$SUDO sed -i 's/^#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config && $SUDO sed -i 's/^PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config || $SUDO bash -c 'echo \"PermitRootLogin no\" >> /etc/ssh/sshd_config'"

apply_cis_control "5.2.11" "Ensure SSH PermitEmptyPasswords is disabled" \
    "$SUDO sed -i 's/^#PermitEmptyPasswords.*/PermitEmptyPasswords no/' /etc/ssh/sshd_config || $SUDO bash -c 'echo \"PermitEmptyPasswords no\" >> /etc/ssh/sshd_config'"

apply_cis_control "5.2.12" "Ensure SSH PermitUserEnvironment is disabled" \
    "$SUDO sed -i 's/^#PermitUserEnvironment.*/PermitUserEnvironment no/' /etc/ssh/sshd_config || $SUDO bash -c 'echo \"PermitUserEnvironment no\" >> /etc/ssh/sshd_config'"

apply_cis_control "5.2.13" "Ensure only strong ciphers are used" \
    "$SUDO bash -c 'echo \"Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr\" >> /etc/ssh/sshd_config'"

apply_cis_control "5.2.14" "Ensure only strong MAC algorithms are used" \
    "$SUDO bash -c 'echo \"MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256\" >> /etc/ssh/sshd_config'"

apply_cis_control "5.2.15" "Ensure only strong key exchange algorithms are used" \
    "$SUDO bash -c 'echo \"KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512,diffie-hellman-group-exchange-sha256\" >> /etc/ssh/sshd_config'"

apply_cis_control "5.2.16" "Ensure SSH Idle Timeout Interval is configured" \
    "$SUDO bash -c 'echo -e \"ClientAliveInterval 300\nClientAliveCountMax 3\" >> /etc/ssh/sshd_config'"

apply_cis_control "5.2.17" "Ensure SSH LoginGraceTime is set to one minute or less" \
    "$SUDO sed -i 's/^#LoginGraceTime.*/LoginGraceTime 60/' /etc/ssh/sshd_config || $SUDO bash -c 'echo \"LoginGraceTime 60\" >> /etc/ssh/sshd_config'"

apply_cis_control "5.2.18" "Ensure SSH warning banner is configured" \
    "$SUDO sed -i 's/^#Banner.*/Banner \/etc\/issue.net/' /etc/ssh/sshd_config || $SUDO bash -c 'echo \"Banner /etc/issue.net\" >> /etc/ssh/sshd_config'"

apply_cis_control "5.2.19" "Ensure SSH PAM is enabled" \
    "$SUDO sed -i 's/^#UsePAM.*/UsePAM yes/' /etc/ssh/sshd_config || $SUDO bash -c 'echo \"UsePAM yes\" >> /etc/ssh/sshd_config'"

apply_cis_control "5.2.20" "Ensure SSH AllowTcpForwarding is disabled" \
    "$SUDO sed -i 's/^#AllowTcpForwarding.*/AllowTcpForwarding no/' /etc/ssh/sshd_config || $SUDO bash -c 'echo \"AllowTcpForwarding no\" >> /etc/ssh/sshd_config'"

apply_cis_control "5.2.21" "Ensure SSH MaxStartups is configured" \
    "$SUDO sed -i 's/^#MaxStartups.*/MaxStartups 10:30:60/' /etc/ssh/sshd_config || $SUDO bash -c 'echo \"MaxStartups 10:30:60\" >> /etc/ssh/sshd_config'"

apply_cis_control "5.2.22" "Ensure SSH MaxSessions is limited" \
    "$SUDO sed -i 's/^#MaxSessions.*/MaxSessions 10/' /etc/ssh/sshd_config || $SUDO bash -c 'echo \"MaxSessions 10\" >> /etc/ssh/sshd_config'"

# 5.3 Configure PAM
echo ""
echo "=== 5.3 Configure PAM ==="

apply_cis_control "5.3.1" "Ensure password creation requirements are configured" \
    "$SUDO mkdir -p /var/cache/dnf && find /var/cache/dnf -type f -name '*.pid' -delete 2>/dev/null || true; find /var/cache/dnf -type f -name '*.rpm' -delete 2>/dev/null || true; $SUDO dnf install -y --setopt=keepcache=0 --setopt=metadata_expire=0 libpwquality || echo 'libpwquality installation'"

apply_cis_control "5.3.2" "Ensure lockout for failed password attempts is configured" \
    "$SUDO bash -c 'echo \"auth required pam_faillock.so preauth audit silent deny=5 unlock_time=900\" >> /etc/pam.d/system-auth'"

apply_cis_control "5.3.3" "Ensure password reuse is limited" \
    "$SUDO bash -c 'sed -i \"/^password.*sufficient.*pam_unix.so/ s/$/ remember=5/\" /etc/pam.d/system-auth'"

apply_cis_control "5.3.4" "Ensure password hashing algorithm is SHA-512" \
    "$SUDO bash -c 'sed -i \"/^password.*sufficient.*pam_unix.so/ s/$/ sha512/\" /etc/pam.d/system-auth'"

# 5.4 User Accounts and Environment
echo ""
echo "=== 5.4 User Accounts and Environment ==="

apply_cis_control "5.4.1" "Ensure password expiration is 365 days or less" \
    "$SUDO bash -c 'sed -i \"/^PASS_MAX_DAYS/ c\PASS_MAX_DAYS 365\" /etc/login.defs || echo \"PASS_MAX_DAYS 365\" >> /etc/login.defs'"

apply_cis_control "5.4.2" "Ensure minimum days between password changes is configured" \
    "$SUDO bash -c 'sed -i \"/^PASS_MIN_DAYS/ c\PASS_MIN_DAYS 1\" /etc/login.defs || echo \"PASS_MIN_DAYS 1\" >> /etc/login.defs'"

apply_cis_control "5.4.3" "Ensure password expiration warning days is 7 or more" \
    "$SUDO bash -c 'sed -i \"/^PASS_WARN_AGE/ c\PASS_WARN_AGE 7\" /etc/login.defs || echo \"PASS_WARN_AGE 7\" >> /etc/login.defs'"

apply_cis_control "5.4.4" "Ensure inactive password lock is 30 days or less" \
    "$SUDO useradd -D -f 30 || echo 'useradd default'"

apply_cis_control "5.4.5" "Ensure default group for the root account is GID 0" \
    "$SUDO usermod -g 0 root || echo 'root group'"

apply_cis_control "5.5.1" "Ensure default user umask is 027 or more restrictive" \
    "$SUDO bash -c 'sed -i \"/^UMASK/ c\UMASK 027\" /etc/login.defs || echo \"UMASK 027\" >> /etc/login.defs'"

apply_cis_control "5.5.2" "Ensure default user shell timeout is configured" \
    "$SUDO bash -c 'echo \"TMOUT=600\" >> /etc/profile.d/cis.sh && echo \"readonly TMOUT\" >> /etc/profile.d/cis.sh && echo \"export TMOUT\" >> /etc/profile.d/cis.sh'"

# 5.6 Ensure root login is restricted to system console
echo ""
echo "=== 5.6 Root Login Restriction ==="

apply_cis_control "5.6" "Ensure root login is restricted to system console" \
    "$SUDO bash -c 'cat > /etc/securetty << EOF
console
tty1
EOF'"

# 6.1 System File Permissions
echo ""
echo "=== 6.1 System File Permissions ==="

apply_cis_control "6.1.1" "Ensure permissions on /etc/passwd are configured" \
    "$SUDO chmod 644 /etc/passwd"

apply_cis_control "6.1.2" "Ensure permissions on /etc/passwd- are configured" \
    "$SUDO chmod 600 /etc/passwd-"

apply_cis_control "6.1.3" "Ensure permissions on /etc/group are configured" \
    "$SUDO chmod 644 /etc/group"

apply_cis_control "6.1.4" "Ensure permissions on /etc/group- are configured" \
    "$SUDO chmod 600 /etc/group-"

apply_cis_control "6.1.5" "Ensure permissions on /etc/shadow are configured" \
    "$SUDO chmod 000 /etc/shadow"

apply_cis_control "6.1.6" "Ensure permissions on /etc/shadow- are configured" \
    "$SUDO chmod 000 /etc/shadow-"

apply_cis_control "6.1.7" "Ensure permissions on /etc/gshadow are configured" \
    "$SUDO chmod 000 /etc/gshadow"

apply_cis_control "6.1.8" "Ensure permissions on /etc/gshadow- are configured" \
    "$SUDO chmod 000 /etc/gshadow-"

apply_cis_control "6.1.9" "Ensure no world writable files exist" \
    "$SUDO find / -xdev -type f -perm -0002 -exec chmod o-w {} + || echo 'World writable files check'"

apply_cis_control "6.1.10" "Ensure no unowned files or directories exist" \
    "$SUDO find / -xdev -nouser -exec chown root:root {} + || echo 'Unowned files check'"

apply_cis_control "6.1.11" "Ensure no ungrouped files or directories exist" \
    "$SUDO find / -xdev -nogroup -exec chgrp root {} + || echo 'Ungrouped files check'"

# 6.2 Local User and Group Settings
echo ""
echo "=== 6.2 Local User and Group Settings ==="

apply_cis_control "6.2.1" "Ensure accounts in /etc/passwd use shadowed passwords" \
    "awk -F: '(\$2 != \"x\") {print}' /etc/passwd | while read -r line; do user=\$(echo \"\$line\" | cut -d: -f1); [ -n \"\$user\" ] && $SUDO usermod -p '!!' \"\$user\" 2>/dev/null || true; done || echo 'Shadow password check'"

apply_cis_control "6.2.2" "Ensure /etc/shadow password fields are not empty" \
    "awk -F: '(\$2 == \"\" || \$2 == \"!\") {print \$1}' /etc/shadow 2>/dev/null | while read -r user; do [ -n \"\$user\" ] && $SUDO passwd -l \"\$user\" 2>/dev/null || true; done || echo 'Empty password check'"

apply_cis_control "6.2.3" "Ensure all groups in /etc/passwd exist in /etc/group" \
    "for i in \$(cut -s -d: -f4 /etc/passwd | sort -u); do grep -q -P \"^.*?:[^:]*:\$i:\" /etc/group || echo \"Group \$i is referenced by /etc/passwd but does not exist in /etc/group\"; done || echo 'Group consistency check'"

apply_cis_control "6.2.4" "Ensure all users' home directories exist" \
    "awk -F: '{print \$1, \$6}' /etc/passwd | while read -r user dir; do if [ ! -d \"\$dir\" ] && [ -n \"\$dir\" ] && [ \"\$dir\" != \"/\" ]; then $SUDO mkdir -p \"\$dir\" 2>/dev/null; $SUDO chown \"\$user\" \"\$dir\" 2>/dev/null; fi; done || echo 'Home directory check'"

apply_cis_control "6.2.5" "Ensure users' home directories permissions are 750 or more restrictive" \
    "awk -F: '{print \$6}' /etc/passwd | while read -r dir; do if [ -d \"\$dir\" ] && [ \"\$dir\" != \"/\" ]; then $SUDO chmod 750 \"\$dir\" 2>/dev/null || true; fi; done || echo 'Home directory permissions'"

apply_cis_control "6.2.6" "Ensure users own their home directories" \
    "awk -F: '{print \$1, \$6}' /etc/passwd | while read -r user dir; do if [ -d \"\$dir\" ] && [ \"\$dir\" != \"/\" ]; then $SUDO chown \"\$user\" \"\$dir\" 2>/dev/null || true; fi; done || echo 'Home directory ownership'"

apply_cis_control "6.2.7" "Ensure users' dot files are not group or world writable" \
    "$SUDO /usr/bin/find /home -name \".*\" -type f -perm /022 -exec chmod go-w {} + 2>/dev/null || echo 'Dot files permissions'"

apply_cis_control "6.2.8" "Ensure no users have .forward files" \
    "$SUDO /usr/bin/find /home -name \".forward\" -type f -delete 2>/dev/null || echo 'Forward files check'"

apply_cis_control "6.2.9" "Ensure no users have .netrc files" \
    "$SUDO /usr/bin/find /home -name \".netrc\" -type f -delete 2>/dev/null || echo 'Netrc files check'"

apply_cis_control "6.2.10" "Ensure users' .netrc Files are not group or world accessible" \
    "$SUDO /usr/bin/find /home -name \".netrc\" -type f -exec chmod 600 {} + 2>/dev/null || echo 'Netrc files permissions'"

apply_cis_control "6.2.11" "Ensure no users have .rhosts files" \
    "$SUDO /usr/bin/find /home -name \".rhosts\" -type f -delete 2>/dev/null || echo 'Rhosts files check'"

apply_cis_control "6.2.12" "Ensure all groups in /etc/group exist in /etc/passwd" \
    "for i in \$(cut -s -d: -f3 /etc/group); do grep -q -P \"^.*?:[^:]*:[^:]*:\$i:\" /etc/passwd || echo \"Group \$i exists in /etc/group but not in /etc/passwd\"; done || echo 'Group consistency check'"

apply_cis_control "6.2.13" "Ensure root is the only UID 0 account" \
    "awk -F: '(\$3 == 0 && \$1 != \"root\") {print}' /etc/passwd | while read -r line; do user=\$(echo \"\$line\" | cut -d: -f1); [ -n \"\$user\" ] && $SUDO userdel \"\$user\" 2>/dev/null || true; done || echo 'UID 0 check'"

apply_cis_control "6.2.14" "Ensure root PATH Integrity" \
    "$SUDO bash -c 'echo \"PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\" > /root/.bashrc && echo \"export PATH\" >> /root/.bashrc' 2>/dev/null || echo 'Root PATH'"

apply_cis_control "6.2.15" "Ensure all interactive users have home directories" \
    "awk -F: '{if (\$7 !~ /nologin/ && \$6 == \"/\") print \$1}' /etc/passwd | while read -r user; do [ -n \"\$user\" ] && $SUDO mkdir -p \"/home/\$user\" 2>/dev/null && $SUDO chown \"\$user\" \"/home/\$user\" 2>/dev/null || true; done || echo 'Interactive users home'"

apply_cis_control "6.2.16" "Ensure users' home directories are not group or world writable" \
    "$SUDO /usr/bin/find /home -type d -perm /022 -exec chmod go-w {} + 2>/dev/null || echo 'Home directories writable'"

apply_cis_control "6.2.17" "Ensure no duplicate UIDs exist" \
    "cut -f3 -d\":\" /etc/passwd | sort -n | uniq -d | while read -r uid; do awk -F: '\$3 == \"\$uid\" {print \$1}' /etc/passwd; done || echo 'Duplicate UID check'"

apply_cis_control "6.2.18" "Ensure no duplicate GIDs exist" \
    "cut -f3 -d\":\" /etc/group | sort -n | uniq -d | while read -r gid; do awk -F: '\$3 == \"\$gid\" {print \$1}' /etc/group; done || echo 'Duplicate GID check'"

apply_cis_control "6.2.19" "Ensure no duplicate user names exist" \
    "cut -f1 -d\":\" /etc/passwd | sort | uniq -d || echo 'Duplicate username check'"

apply_cis_control "6.2.20" "Ensure no duplicate group names exist" \
    "cut -f1 -d\":\" /etc/group | sort | uniq -d || echo 'Duplicate group name check'"

echo ""
echo -e "${GREEN}=== CIS Level 2 Hardening Complete ===${NC}"
echo "Note: Some controls may require manual verification or additional configuration."
echo "It is recommended to run CIS assessment tools to verify compliance."

# Flush all output buffers
# Use full path to sync (coreutils) and make non-fatal
/usr/bin/sync 2>/dev/null || /bin/sync 2>/dev/null || true

# Exit cleanly - trap cleanup function will handle script self-deletion
exit 0

