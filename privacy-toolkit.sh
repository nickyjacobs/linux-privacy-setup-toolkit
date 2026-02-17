#!/bin/bash

# Linux Privacy Setup Toolkit
# A comprehensive privacy and security hardening script for Linux systems

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_NAME="Privacy Setup Toolkit"
VERSION="1.1.0"

# Logging
LOG_FILE="/tmp/privacy_toolkit_$(date +%Y%m%d_%H%M%S).log"

# Backup directory for config backups (created when needed)
BACKUP_DIR="$HOME/.privacy-toolkit-backups"

# Dry-run mode: no system changes, only show what would be done (set by --dry-run or --test)
DRY_RUN=""
TEST_DIR=""
BIN_DIR=""   # Set in main: either $HOME/.local/bin or $TEST_DIR/bin when DRY_RUN

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to log messages
log_message() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$message" >> "$LOG_FILE"
    print_color "$BLUE" "$message"
}

# Function to prompt user for confirmation
confirm_action() {
    local message=$1
    local default=${2:-"n"}
    
    print_color "$YELLOW" "$message"
    if [[ -n "${DRY_RUN:-}" ]]; then
        print_color "$GREEN" "Continue? [y/N]: y (dry-run)"
        return 0
    fi
    read -p "Continue? [y/N]: " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to check if running as root (must run early, before any destructive prompts)
check_root() {
    if [[ $EUID -eq 0 ]]; then
        if [[ -n "${DRY_RUN:-}" ]]; then
            print_color "$YELLOW" "Running as root in dry-run only (no system changes will be made)."
            return 0
        fi
        print_color "$RED" "This script should not be run as root for security reasons."
        print_color "$YELLOW" "Run as a normal user; sudo will be requested when needed."
        exit 1
    fi
}

# Function to detect distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        VERSION_ID=${VERSION_ID:-"unknown"}
    else
        print_color "$RED" "Cannot detect Linux distribution"
        exit 1
    fi
    
    log_message "Detected distribution: $DISTRO $VERSION_ID"
}

# Function to check dependencies (curl/wget optional for future use; ufw and apparmor-utils for hardening)
check_dependencies() {
    local deps=("ufw" "apparmor-utils")
    local missing_deps=()
    
    print_color "$CYAN" "Checking dependencies..."
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_color "$YELLOW" "Missing dependencies: ${missing_deps[*]}"
        if confirm_action "Install missing dependencies?"; then
            install_dependencies "${missing_deps[@]}"
        else
            print_color "$RED" "Cannot continue without required dependencies"
            exit 1
        fi
    fi
}

# Function to install dependencies
install_dependencies() {
    local deps=("$@")
    if [[ -n "${DRY_RUN:-}" ]]; then
        print_color "$CYAN" "Would run: sudo apt/dnf/pacman install -y ${deps[*]} (depending on distro)"
        return
    fi
    case $DISTRO in
        ubuntu|debian|kali)
            sudo apt update
            sudo apt install -y "${deps[@]}"
            ;;
        fedora)
            sudo dnf install -y "${deps[@]}"
            ;;
        arch|manjaro)
            sudo pacman -S --noconfirm "${deps[@]}"
            ;;
        *)
            print_color "$RED" "Unsupported distribution for automatic dependency installation"
            print_color "$YELLOW" "Please install manually: ${deps[*]}"
            exit 1
            ;;
    esac
}

# Function to configure UFW firewall
configure_firewall() {
    print_color "$PURPLE" "=== Configuring UFW Firewall ==="
    print_color "$YELLOW" "WARNING: This will RESET all existing UFW rules and apply: deny incoming, allow outgoing, SSH/DNS/HTTP/HTTPS/NTP."
    if ! confirm_action "Configure UFW firewall? (Existing rules will be replaced)"; then
        return 0
    fi
    
    log_message "Configuring UFW firewall"
    if [[ -n "${DRY_RUN:-}" ]]; then
        print_color "$CYAN" "Would run: ufw --force reset; ufw default deny incoming; ufw default allow outgoing; ufw allow ssh; ufw allow out 53,80,443,123; ufw enable; ufw logging on"
        print_color "$GREEN" "✓ UFW firewall (dry-run)"
        return
    fi
    
    # Reset UFW to defaults
    sudo ufw --force reset
    
    # Set default policies
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    
    # Allow essential services
    sudo ufw allow ssh
    sudo ufw allow out 53  # DNS
    sudo ufw allow out 80  # HTTP
    sudo ufw allow out 443 # HTTPS
    sudo ufw allow out 123 # NTP
    
    # Enable UFW
    sudo ufw --force enable
    
    # Enable logging
    sudo ufw logging on
    
    print_color "$GREEN" "✓ UFW firewall configured successfully"
}

# Function to configure DNS encryption
configure_dns() {
    print_color "$PURPLE" "=== Configuring Encrypted DNS ==="
    if ! confirm_action "Configure DNS over HTTPS (DoH) using systemd-resolved?"; then
        return 0
    fi
    
    log_message "Configuring encrypted DNS"
    if [[ -n "${DRY_RUN:-}" ]]; then
        print_color "$CYAN" "Would backup /etc/systemd/resolved.conf to $BACKUP_DIR (if exists)"
        print_color "$CYAN" "Would write DoH/DoT config to /etc/systemd/resolved.conf and restart systemd-resolved; would symlink resolv.conf"
        print_color "$GREEN" "✓ Encrypted DNS (dry-run)"
        return
    fi
    
    # Backup existing resolved.conf if present
    if [ -f /etc/systemd/resolved.conf ]; then
        mkdir -p "$BACKUP_DIR"
        sudo cp -a /etc/systemd/resolved.conf "$BACKUP_DIR/resolved.conf.$(date +%Y%m%d_%H%M%S).bak"
        log_message "Backed up /etc/systemd/resolved.conf to $BACKUP_DIR"
    fi
    
    # Create systemd-resolved configuration (also created if service not present, for future use)
    sudo mkdir -p /etc/systemd
    sudo tee /etc/systemd/resolved.conf > /dev/null <<EOF
[Resolve]
DNS=1.1.1.1#cloudflare-dns.com 8.8.8.8#dns.google
DNSOverTLS=yes
DNSSEC=yes
FallbackDNS=1.0.0.1#cloudflare-dns.com 8.8.4.4#dns.google
Cache=yes
Domains=~.
EOF
    
    if sudo systemctl restart systemd-resolved 2>/dev/null; then
        if [ -d /run/systemd/resolve ]; then
            sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
            print_color "$CYAN" "Note: If you use NetworkManager, it may overwrite /etc/resolv.conf."
        fi
        print_color "$GREEN" "✓ Encrypted DNS configured successfully (systemd-resolved)"
    else
        print_color "$YELLOW" "systemd-resolved is not installed or not used on this system (e.g. Kali often uses NetworkManager only)."
        print_color "$CYAN" "Config written to /etc/systemd/resolved.conf for when you use systemd-resolved."
        print_color "$CYAN" "For encrypted DNS now: set DNS to 1.1.1.1 or 8.8.8.8 in NetworkManager (connection → IPv4/IPv6 → DNS), or use DoH in Firefox settings."
        print_color "$GREEN" "✓ DNS config file written; use NetworkManager or browser DoH for encryption on this system"
    fi
}

# Function to install and configure browser security
configure_browser() {
    print_color "$PURPLE" "=== Browser Security Configuration ==="
    
    if ! confirm_action "Install Firefox with privacy-focused configuration?"; then
        return 0
    fi
    
    log_message "Configuring browser security"
    if [[ -n "${DRY_RUN:-}" ]]; then
        print_color "$CYAN" "Would install Firefox (if not present); would create/overwrite user.js in default profile (with backup)"
        print_color "$GREEN" "✓ Browser security (dry-run)"
        return
    fi
    
    # Install Firefox if not present
    case $DISTRO in
        ubuntu|debian|kali)
            sudo apt install -y firefox
            ;;
        fedora)
            sudo dnf install -y firefox
            ;;
        arch|manjaro)
            sudo pacman -S --noconfirm firefox
            ;;
        *)
            print_color "$YELLOW" "Firefox not auto-installed for $DISTRO. Install Firefox and re-run this step to apply privacy settings."
            ;;
    esac
    
    # Create Firefox user.js with privacy settings
    FIREFOX_PROFILE_DIR="$HOME/.mozilla/firefox"
    
    if [ -d "$FIREFOX_PROFILE_DIR" ]; then
        PROFILE=$(find "$FIREFOX_PROFILE_DIR" -maxdepth 2 -name "*.default*" -type d 2>/dev/null | head -n1)
        
        if [ -n "$PROFILE" ]; then
            # Backup existing user.js if present
            if [ -f "$PROFILE/user.js" ]; then
                mkdir -p "$BACKUP_DIR"
                cp -a "$PROFILE/user.js" "$BACKUP_DIR/user.js.$(date +%Y%m%d_%H%M%S).bak"
                log_message "Backed up Firefox user.js to $BACKUP_DIR"
            fi
            cat > "$PROFILE/user.js" <<EOF
// Privacy-focused Firefox configuration
user_pref("privacy.trackingprotection.enabled", true);
user_pref("privacy.trackingprotection.socialtracking.enabled", true);
user_pref("privacy.partition.network_state", false);
user_pref("privacy.donottrackheader.enabled", true);
user_pref("geo.enabled", false);
user_pref("dom.webnotifications.enabled", false);
user_pref("media.navigator.enabled", false);
user_pref("network.cookie.cookieBehavior", 1);
user_pref("network.http.referer.XOriginPolicy", 2);
user_pref("network.http.referer.XOriginTrimmingPolicy", 2);
user_pref("webgl.disabled", true);
user_pref("dom.webaudio.enabled", false);
user_pref("beacon.enabled", false);
user_pref("browser.safebrowsing.downloads.remote.enabled", false);
user_pref("network.prefetch-next", false);
user_pref("network.dns.disablePrefetch", true);
user_pref("network.predictor.enabled", false);
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("toolkit.telemetry.enabled", false);
user_pref("browser.ping-centre.telemetry", false);
EOF
            print_color "$GREEN" "✓ Firefox privacy configuration applied"
        else
            print_color "$YELLOW" "No Firefox default profile found. Start Firefox once to create it, then re-run this script to apply privacy settings."
        fi
    else
        print_color "$YELLOW" "Firefox profile directory not found. Start Firefox once, then re-run this script to apply privacy settings."
    fi
}

# Function to configure file metadata removal
configure_metadata_removal() {
    print_color "$PURPLE" "=== Metadata Removal Tools ==="
    
    if ! confirm_action "Install tools for removing metadata from files?"; then
        return 0
    fi
    
    log_message "Installing metadata removal tools"
    if [[ -n "${DRY_RUN:-}" ]]; then
        print_color "$CYAN" "Would install exiftool and mat2; creating strip-metadata script in $BIN_DIR for inspection"
    fi
    
    if [[ -z "${DRY_RUN:-}" ]]; then
        case $DISTRO in
            ubuntu|debian|kali)
                sudo apt install -y exiftool mat2 2>/dev/null || {
                    print_color "$YELLOW" "apt install failed. Trying exiftool only..."
                    sudo apt install -y exiftool 2>/dev/null || true
                    print_color "$YELLOW" "Install manually later: sudo apt install -y exiftool mat2"
                    true
                }
                ;;
            fedora)
                sudo dnf install -y perl-Image-ExifTool mat2 2>/dev/null || true
                ;;
            arch|manjaro)
                sudo pacman -S --noconfirm exiftool mat2 2>/dev/null || true
                ;;
        esac
    fi
    
    # Create convenience script (in dry-run uses BIN_DIR from main)
    local bin_dir="${BIN_DIR:-$HOME/.local/bin}"
    mkdir -p "$bin_dir"
    cat > "$bin_dir/strip-metadata" <<'EOF'
#!/bin/bash
# Metadata stripping utility

if [ $# -eq 0 ]; then
    echo "Usage: strip-metadata <file1> [file2] ..."
    echo "Removes metadata from specified files"
    exit 1
fi

for file in "$@"; do
    if [ -f "$file" ]; then
        echo "Stripping metadata from: $file"
        mat2 --inplace "$file" 2>/dev/null || exiftool -all= -overwrite_original "$file" 2>/dev/null
        echo "✓ Processed: $file"
    else
        echo "✗ File not found: $file"
    fi
done
EOF
    
    chmod +x "$bin_dir/strip-metadata"
    
    if [[ -n "${DRY_RUN:-}" ]]; then
        print_color "$GREEN" "✓ Metadata removal script created (dry-run: $bin_dir/strip-metadata)"
    else
        print_color "$GREEN" "✓ Metadata removal tools installed"
    fi
    print_color "$CYAN" "Use 'strip-metadata <filename>' to remove metadata from files"
}

# Function to configure application sandboxing
configure_sandboxing() {
    print_color "$PURPLE" "=== Application Sandboxing ==="
    
    if ! confirm_action "Install and configure Firejail for application sandboxing?"; then
        return 0
    fi
    
    log_message "Installing Firejail"
    if [[ -n "${DRY_RUN:-}" ]]; then
        print_color "$CYAN" "Would install firejail; would run firecfg; would create /etc/firejail/browser-common.local"
        print_color "$GREEN" "✓ Application sandboxing (dry-run)"
        return
    fi
    
    case $DISTRO in
        ubuntu|debian|kali)
            sudo apt install -y firejail firejail-profiles
            ;;
        fedora)
            sudo dnf install -y firejail
            ;;
        arch|manjaro)
            sudo pacman -S --noconfirm firejail
            ;;
    esac
    
    # Configure Firejail
    sudo firecfg
    
    # Create custom profile for browsers
    sudo mkdir -p /etc/firejail
    cat > /tmp/browser-common.local <<EOF
# Custom browser security profile
caps.drop all
netfilter
noroot
protocol unix,inet,inet6,netlink
seccomp
shell none

private-cache
private-dev
private-tmp

disable-mnt
noexec /tmp
EOF
    
    sudo mv /tmp/browser-common.local /etc/firejail/
    
    print_color "$GREEN" "✓ Firejail sandboxing configured"
    print_color "$CYAN" "Applications will now run in sandboxed environments"
}

# Function to configure system hardening
configure_system_hardening() {
    print_color "$PURPLE" "=== System Hardening ==="
    
    if ! confirm_action "Apply system hardening configurations?"; then
        return 0
    fi
    
    log_message "Applying system hardening"
    if [[ -n "${DRY_RUN:-}" ]]; then
        print_color "$CYAN" "Would offer to disable bluetooth, cups, avahi-daemon; would write /etc/sysctl.d/99-privacy-hardening.conf and apply sysctl"
        print_color "$GREEN" "✓ System hardening (dry-run)"
        return
    fi
    
    # Disable unnecessary services
    SERVICES_TO_DISABLE=("bluetooth" "cups" "avahi-daemon")
    
    for service in "${SERVICES_TO_DISABLE[@]}"; do
        if systemctl is-enabled "$service" &>/dev/null; then
            if confirm_action "Disable $service?"; then
                sudo systemctl disable "$service"
                sudo systemctl stop "$service"
                log_message "Disabled service: $service"
            fi
        fi
    done
    
    # Configure kernel parameters
    cat > /tmp/99-privacy-hardening.conf <<EOF
# Network security
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 1

# Memory protection
kernel.randomize_va_space = 2
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
kernel.unprivileged_bpf_disabled = 1
net.core.bpf_jit_harden = 2

# Process restrictions
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
fs.suid_dumpable = 0
EOF
    
    sudo mv /tmp/99-privacy-hardening.conf /etc/sysctl.d/
    # Apply sysctl; ignore errors for parameters not present on this kernel (e.g. older kernels)
    sudo sysctl -p /etc/sysctl.d/99-privacy-hardening.conf 2>/dev/null || true
    sudo sysctl --system 2>/dev/null || true
    
    print_color "$GREEN" "✓ System hardening applied"
}

# Function to create privacy audit script
create_audit_script() {
    print_color "$PURPLE" "=== Creating Privacy Audit Script ==="
    local bin_dir="${BIN_DIR:-$HOME/.local/bin}"
    mkdir -p "$bin_dir"
    if [[ -n "${DRY_RUN:-}" ]]; then
        print_color "$CYAN" "Would create privacy-audit script in $bin_dir (dry-run: writing to $bin_dir for inspection)"
    fi
    cat > "$bin_dir/privacy-audit" <<'EOF'
#!/bin/bash
# Privacy configuration audit script

echo "=== Privacy Configuration Audit ==="
echo "Date: $(date)"
echo

# Check firewall status
echo "🔥 Firewall Status:"
sudo ufw status verbose
echo

# Check DNS configuration
echo "🌐 DNS Configuration:"
if command -v resolvectl &>/dev/null; then
    resolvectl status | grep -E "DNS Servers|Current DNS"
elif command -v systemd-resolve &>/dev/null; then
    systemd-resolve --status | grep -A5 "DNS Servers"
else
    echo "  (resolvectl/systemd-resolve not found; check /etc/resolv.conf)"
fi
echo

# Check running services
echo "📊 Listening Services:"
ss -tuln | grep LISTEN
echo

# Check browser profiles
echo "🌍 Browser Configuration:"
if [ -d "$HOME/.mozilla/firefox" ]; then
    echo "Firefox profiles found:"
    find "$HOME/.mozilla/firefox" -name "user.js" -exec echo "  - {}" \;
fi
echo

# Check sandboxing
echo "🏖️ Sandboxing:"
if command -v firejail &> /dev/null; then
    echo "Firejail installed: ✓"
    echo "Active sandbox processes:"
    firejail --list 2>/dev/null || echo "  None currently running"
else
    echo "Firejail: ✗ Not installed"
fi
echo

# Check metadata tools
echo "🗂️ Metadata Tools:"
for tool in mat2 exiftool; do
    if command -v "$tool" &> /dev/null; then
        echo "$tool: ✓"
    else
        echo "$tool: ✗"
    fi
done
echo

echo "Audit complete. Check configurations regularly!"
EOF
    
    chmod +x "$bin_dir/privacy-audit"
    
    if [[ -n "${DRY_RUN:-}" ]]; then
        print_color "$GREEN" "✓ Privacy audit script created (dry-run: $bin_dir/privacy-audit)"
    else
        print_color "$GREEN" "✓ Privacy audit script created"
    fi
    print_color "$CYAN" "Run 'privacy-audit' to check your privacy configuration anytime"
}

# Function to display summary
show_summary() {
    print_color "$GREEN" ""
    print_color "$GREEN" "================================="
    print_color "$GREEN" "   PRIVACY SETUP COMPLETE!"
    print_color "$GREEN" "================================="
    print_color "$CYAN" ""
    print_color "$CYAN" "What was configured:"
    print_color "$YELLOW" "• UFW Firewall with restrictive rules"
    print_color "$YELLOW" "• Encrypted DNS over HTTPS/TLS"
    print_color "$YELLOW" "• Firefox with privacy-focused settings"
    print_color "$YELLOW" "• Metadata removal tools (mat2, exiftool)"
    print_color "$YELLOW" "• Application sandboxing with Firejail"
    print_color "$YELLOW" "• System hardening configurations"
    print_color "$YELLOW" "• Privacy audit script"
    print_color "$CYAN" ""
    print_color "$CYAN" "Useful commands:"
    print_color "$WHITE" "• privacy-audit        - Check privacy configuration"
    print_color "$WHITE" "• strip-metadata <file> - Remove file metadata"
    print_color "$WHITE" "• firejail <app>       - Run app in sandbox"
    print_color "$CYAN" ""
    print_color "$BLUE" "Log file: $LOG_FILE"
    print_color "$CYAN" ""
    print_color "$RED" "Remember: Privacy is an ongoing process!"
    print_color "$RED" "Keep your system updated and audit regularly."
}

# Main menu
main_menu() {
    clear 2>/dev/null || true
    print_color "$PURPLE" "╔════════════════════════════════════════╗"
    print_color "$PURPLE" "║          $SCRIPT_NAME v$VERSION          ║"
    print_color "$PURPLE" "╚════════════════════════════════════════╝"
    print_color "$CYAN" ""
    print_color "$CYAN" "This toolkit will help configure privacy and security"
    print_color "$CYAN" "settings on your Linux system. Each step will ask for"
    print_color "$CYAN" "your confirmation before making changes."
    print_color "$CYAN" ""
    
    if ! confirm_action "Ready to begin privacy setup?"; then
        print_color "$YELLOW" "Setup cancelled by user"
        exit 0
    fi
}

# Main execution
main() {
    # Parse arguments (--dry-run or --test = no system changes)
    for arg in "$@"; do
        case $arg in
            --dry-run|--test) DRY_RUN=1 ;;
            -h|--help)
                echo "Usage: $0 [--dry-run|--test]"
                echo "  --dry-run, --test   Run without making system changes (for testing)"
                exit 0
                ;;
        esac
    done
    
    if [[ -n "${DRY_RUN:-}" ]]; then
        print_color "$YELLOW" "=== DRY RUN: no system or home config changes; generated scripts go to a temp dir ==="
        # Allow override so tests can write inside workspace (e.g. when /tmp is not writable)
        TEST_DIR="${DRY_RUN_OUTPUT_DIR:-/tmp/privacy-toolkit-dryrun-$$}"
        BIN_DIR="$TEST_DIR/bin"
        mkdir -p "$BIN_DIR"
        LOG_FILE="$TEST_DIR/toolkit.log"
        BACKUP_DIR="$TEST_DIR/backups"
        print_color "$CYAN" "Test output directory: $TEST_DIR"
    fi
    
    check_root
    
    # Create .local/bin if it doesn't exist (or use BIN_DIR in dry-run)
    if [[ -z "${DRY_RUN:-}" ]]; then
        mkdir -p "$HOME/.local/bin"
        BIN_DIR="$HOME/.local/bin"
    fi
    
    # Add .local/bin to PATH if not already there (skip .bashrc changes in dry-run)
    if [[ -z "${DRY_RUN:-}" ]]; then
        if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
            local bashrc="${HOME}/.bashrc"
            if [ -f "$bashrc" ] && grep -q '[.]local/bin' "$bashrc" 2>/dev/null; then
                print_color "$CYAN" "PATH already contains .local/bin in bashrc"
            else
                [ -f "$bashrc" ] || touch "$bashrc"
                echo '' >> "$bashrc"
                echo '# Added by Privacy Setup Toolkit' >> "$bashrc"
                echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$bashrc"
            fi
            export PATH="$HOME/.local/bin:$PATH"
        fi
    else
        export PATH="$BIN_DIR:$PATH"
    fi
    
    main_menu
    detect_distro
    check_dependencies
    
    log_message "Starting privacy setup toolkit"
    
    configure_firewall
    configure_dns
    configure_browser
    configure_metadata_removal
    configure_sandboxing
    configure_system_hardening
    create_audit_script
    
    show_summary
    
    log_message "Privacy setup completed successfully"
    
    if [[ -n "${DRY_RUN:-}" ]]; then
        print_color "$GREEN" ""
        print_color "$GREEN" "Dry run complete. Inspect generated scripts in: $TEST_DIR"
        print_color "$CYAN" "  - $BIN_DIR/privacy-audit"
        print_color "$CYAN" "  - $BIN_DIR/strip-metadata"
        print_color "$CYAN" "  - $LOG_FILE"
        echo ""
    fi
}

# Run main function
main "$@"
