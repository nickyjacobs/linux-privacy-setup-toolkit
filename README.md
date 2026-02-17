# Linux Privacy Setup Toolkit – Complete Guide

## Table of Contents

- [Overview](#overview)
- [What This Tool Does](#what-this-tool-does)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Usage](#usage)
- [Detailed Feature Breakdown](#detailed-feature-breakdown)
- [Post-Setup Commands](#post-setup-commands)
- [Security Considerations](#security-considerations)
- [Troubleshooting](#troubleshooting)
- [Advanced Customization](#advanced-customization)
- [Frequently Asked Questions](#frequently-asked-questions)

## Overview

The Linux Privacy Setup Toolkit is a comprehensive bash script designed to transform your Linux system into a privacy-focused, security-hardened machine. Unlike basic privacy guides that suggest installing a VPN and calling it a day, this toolkit implements multiple layers of protection at the system level.

### Why This Tool Exists

Most privacy tutorials are scattered across outdated blog posts, broken GitHub repositories, and forum threads from years ago. This toolkit consolidates the best privacy practices into a single, automated setup process that:

- **Actually works** – Tested on major Linux distributions
- **Explains what it's doing** – No black box operations
- **Asks for permission** – You control what gets installed
- **Provides ongoing tools** – Not just a one-time setup

### Philosophy

Privacy isn't about becoming invisible – it's about making surveillance expensive and difficult. This toolkit raises the cost of tracking you by implementing multiple layers of protection that work together to scatter your digital footprint instead of serving it up on a silver platter.

## What This Tool Does

### 🔥 UFW Firewall Configuration

**Problem Solved:** Your system accepts incoming connections by default, creating attack vectors.

**What It Does:**

- Resets UFW to clean state
- Sets default policy to deny all incoming connections
- Allows only essential outgoing connections (DNS, HTTP, HTTPS, NTP, SSH)
- Enables comprehensive logging
- Creates a restrictive security perimeter around your system

### 🌐 DNS Encryption Setup

**Problem Solved:** DNS requests leak your browsing history to your ISP in plain text.

**What It Does:**

- Configures systemd-resolved for DNS over HTTPS (DoH) and DNS over TLS (DoT)
- Uses Cloudflare (1.1.1.1) and Google (8.8.8.8) as encrypted DNS providers
- Enables DNSSEC for cryptographic validation of DNS responses
- Prevents DNS hijacking and manipulation
- Hides your browsing patterns from network-level surveillance

### 🌍 Browser Privacy Hardening

**Problem Solved:** Default browser settings leak data through tracking, fingerprinting, and telemetry.

**What It Does:** Installs Firefox (if not present), creates privacy configuration (user.js), enables tracking protection, blocks WebGL/WebRTC/Web Audio fingerprinting, disables telemetry, strict cookies and referrer policy, no DNS prefetch.

### 🗂️ Metadata Removal Tools

**Problem Solved:** Files contain hidden metadata (EXIF, document properties, GPS, etc.).

**What It Does:** Installs mat2 and exiftool, creates a `strip-metadata` command; removes EXIF, document metadata, camera info, timestamps. Both GUI (mat2) and CLI (exiftool) options.

### 🏖️ Application Sandboxing

**Problem Solved:** Applications could access your entire filesystem and data.

**What It Does:** Installs and configures Firejail, creates isolated environments, uses `firecfg` for automatic sandboxing of common apps, restricts filesystem/device access, drops capabilities.

### 🔒 System Hardening

**Problem Solved:** Default Linux config prioritises usability over security.

**What It Does:** Optionally disables Bluetooth, CUPS, Avahi (per-service confirmation), sets kernel parameters (ASLR, kptr_restrict, dmesg_restrict), hardens network (no redirects/source routing, SYN cookies, log martians), protects hardlinks/symlinks.

### 📊 Privacy Auditing

**Problem Solved:** People set privacy once and never check again.

**What It Does:** Creates a `privacy-audit` command that reports firewall status, DNS config, listening services, browser profiles, Firejail status, and metadata tools. Use it regularly for health checks.

---

## Prerequisites

**System requirements:** Linux (Ubuntu, Debian, Fedora, or Arch-based), non-root user with sudo, internet, ~100 MB disk.

**Supported distributions:** Ubuntu 18.04+ and derivatives (Pop!_OS, Linux Mint), Debian 10+ and derivatives (**including Kali Linux**), Fedora 30+ and derivatives (CentOS Stream, Rocky), Arch and derivatives (Manjaro, EndeavourOS).

**Before running:** The script makes system-level changes and will prompt before each step. Backups of `resolved.conf` and Firefox `user.js` are saved to `~/.privacy-toolkit-backups/`. Some changes may require a reboot.

---

## Installation

1. **Get the files:** Clone the repo or download the script.
   ```bash
   git clone https://github.com/YOUR_USERNAME/linux-privacy-setup-toolkit.git
   cd linux-privacy-setup-toolkit
   ```
2. **Make executable:** `chmod +x privacy-toolkit.sh run-tests.sh`
3. **Verify (recommended):** Open the script and check it; the script only uses package managers (apt/dnf/pacman), no raw curl/wget to external URLs.

---

## Usage

**Basic:** `./privacy-toolkit.sh` — runs interactively and asks before each change.

**Testing (recommended first):**

- `./privacy-toolkit.sh --dry-run` — no system changes; writes generated scripts to a temp dir.
- `./run-tests.sh` — syntax check, full dry-run, and generated-script checks.
- `DRY_RUN_OUTPUT_DIR=/path/to/output ./privacy-toolkit.sh --dry-run` — custom output dir (e.g. CI).

**What to expect:** Welcome → distro detection → dependency check (e.g. ufw, apparmor-utils) → step-by-step configuration with confirmations → summary and useful commands.

**Sample flow:**

```
╔════════════════════════════════════════╗
║     Privacy Setup Toolkit v1.1.0      ║
╚════════════════════════════════════════╝
Ready to begin privacy setup?
Continue? [y/N]: y
[2026-02-17 00:30:00] Detected distribution: ubuntu 22.04
Missing dependencies: ufw apparmor-utils
Install missing dependencies? Continue? [y/N]: y
=== Configuring UFW Firewall ===
WARNING: This will RESET all existing UFW rules...
Configure UFW firewall? (Existing rules will be replaced)
Continue? [y/N]: y
✓ UFW firewall configured successfully
[... continues for each component ...]
## Detailed Feature Breakdown

### UFW Firewall Configuration

**Technical details:**
# Default policies applied
sudo ufw default deny incoming
sudo ufw default allow outgoing# Block all incoming connections
# Allow all outgoing connections
# Specific rules created
sudo ufw allow ssh
sudo ufw allow out 53
sudo ufw allow out 80
sudo ufw allow out 443
sudo ufw allow out 123# SSH access (port 22)
# DNS queries
# HTTP traffic
# HTTPS traffic
# Network Time Protocol
What This Protects Against:
Unauthorized network services accessing your machine
Network-based attacks and port scanning
Malware attempting to establish backdoor connections
Data exfiltration through unexpected network channels
Potential Issues:
May block legitimate services you run locally
Gaming or peer-to-peer applications might need additional rules
Some development tools may require port exceptions
### DNS Encryption Configuration

The toolkit configures `/etc/systemd/resolved.conf`:
[Resolve]
DNS=1.1.1.1#cloudflare-dns.com 8.8.8.8#dns.google
DNSOverTLS=yes
DNSSEC=yes
FallbackDNS=1.0.0.1#cloudflare-dns.com 8.8.4.4#dns.google
Cache=yes
Domains=~.

**What This Protects Against:**
ISP monitoring of your web browsing through DNS logs
DNS hijacking and redirection attacks
Man-in-the-middle DNS manipulation
DNS cache poisoning attacks
How It Works:
DNS queries are encrypted using TLS before leaving your system
DNSSEC verifies the authenticity of DNS responses
Multiple providers ensure redundancy and reliability
Local caching improves performance while maintaining privacy
### Browser Privacy Hardening

**Key privacy settings applied:**
// Disable tracking and fingerprinting
user_pref("privacy.trackingprotection.enabled", true);
user_pref("webgl.disabled", true);
user_pref("geo.enabled", false);
// Prevent data collection
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("toolkit.telemetry.enabled", false);
// Harden network behavior
user_pref("network.http.referer.XOriginPolicy", 2);
user_pref("network.dns.disablePrefetch", true);
Fingerprinting Vectors Blocked:
WebGL fingerprinting: Graphics card and driver information
Canvas fingerprinting: Unique rendering characteristics
Audio fingerprinting: Audio processing differences
Font fingerprinting: Installed system fonts
Geolocation: Physical location data
WebRTC: IP address leakage
Trade-offs:
Some websites may not function correctly
Media-rich content might have degraded performance
Online services might request additional verification.

**Metadata Removal Tools**
What Gets Removed:
EXIF data from images: Camera model, GPS coordinates, timestamps, camera settings
Document metadata: Author names, creation/modification dates, revision history,
comments
Audio/Video metadata: Recording device, location, duration, bitrate information
Office document properties: Company information, user names, document statistics
Usage Examples:
# Remove metadata from a single file
strip-metadata photo.jpg
# Remove metadata from multiple files
strip-metadata *.jpg *.png *.pdf
# Check metadata before removal
exiftool photo.jpg
mat2 --show document.pdf
Important Notes:
Always keep backups of original files
Some metadata removal may affect file functionality
Certain file formats may not support all metadata removal options
Application Sandboxing with Firejail
How Sandboxing Works: Firejail creates isolated environments for applications using Linux
namespaces and seccomp filters:
# Automatic sandboxing setup
sudo firecfg # Creates symbolic links for automatic sandboxing
# Manual sandboxing examples
firejail firefox
firejail --private vlc movie.mp4
firejail --net=none libreoffice
# Run Firefox in sandbox
# Run VLC with private home directory
# Run LibreOffice without network access
Security Features:
Filesystem isolation: Applications can't access unauthorized directories
Network filtering: Control which applications can access the internet
Capability dropping: Remove dangerous system capabilities from processes. Resource limiting: Prevent applications from consuming excessive system resources
Default Restrictions:
No access to /boot , /lib , /usr directories
Private /tmp directory
Restricted device access
No root privileges within sandbox
System Hardening Parameters
Network Security Hardening:
# Prevent IP spoofing
net.ipv4.conf.all.accept_source_route = 0
# Disable ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
# Enable SYN cookies (DDoS protection)
net.ipv4.tcp_syncookies = 1
# Log suspicious packets
net.ipv4.conf.all.log_martians = 1
Memory Protection:
# Maximum ASLR (Address Space Layout Randomization)
kernel.randomize_va_space = 2
# Hide kernel pointers
kernel.kptr_restrict = 2
# Restrict kernel logs
kernel.dmesg_restrict = 1
Process Protection:
# Protect against hardlink attacks
fs.protected_hardlinks = 1
# Protect against symlink attacks
fs.protected_symlinks = 1
# Disable core dumps for SUID processes
fs.suid_dumpable = 0

## Post-Setup Commands

After running the toolkit you have:

| Command | Description |
|--------|-------------|
| `privacy-audit` | Firewall, DNS, services, browser, sandbox, metadata tools status |
| `strip-metadata <file>...` | Remove metadata from files |
| `firejail <app>` | Run app in sandbox |

**privacy-audit** shows:
Current firewall status and rules
DNS configuration and servers
Active network services and listening ports
Browser privacy configurations
Sandboxing status and active processes
Metadata removal tool availability
Example output:
=== Privacy Configuration Audit ===
Date: 2025-01-15 14:30:00
🔥 Firewall Status:
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), disabled (routed)
🌐 DNS Configuration:
DNS Servers: 1.1.1.1#cloudflare-dns.com
8.8.8.8#dns.google
📊 Listening Services:
tcp
tcp
LISTEN
LISTEN
0
0
128
128
🌍 Browser Configuration:
127.0.0.1:631
[::1]:631
*:*
[::]:*
Firefox profiles found:
- /home/user/.mozilla/firefox/abc123.default/user.js
🏖️ Sandboxing:
Firejail installed: ✓
Active sandbox processes:
None currently running
🗂️ Metadata Tools: mat2: ✓
exiftool: ✓
Metadata Stripping Command
# Strip metadata from files
strip-metadata photo1.jpg photo2.jpg document.pdf
# Works with wildcards
strip-metadata *.jpg *.png *.pdf
# Check what metadata exists first
exiftool -all photo.jpg
mat2 --show document.pdf
Sandboxed Application Launching
# Applications are automatically sandboxed after firecfg
firefox
# Launches in sandbox automatically
vlc
# Launches in sandbox automatically
# Manual sandboxing with custom options
firejail --private firefox
firejail --net=none libreoffice
firejail --read-only=~ evince document.pdf
# Private home directory
# No network access
# Read-only home directory
## Security Considerations

### What This Toolkit Can and Cannot Do
✅ What It Protects Against:
Network-level surveillance and traffic analysis
Basic browser fingerprinting and tracking
Metadata leakage from files
System-level attacks through network services
Application-level data exfiltration
DNS monitoring and manipulation
❌ What It Cannot Protect Against:
Advanced persistent threats (APTs) with zero-day exploits
Physical access to your device
Social engineering attacks
Malware that exploits unknown vulnerabilities. Government-level surveillance with legal access
Your own poor security practices (weak passwords, etc.)
Additional Security Recommendations
Password Security:
Use a password manager (KeePassXC, Bitwarden)
Enable two-factor authentication wherever possible
Use unique, strong passwords for every account
System Updates:
# Keep your system updated
sudo apt update && sudo apt upgrade
sudo dnf update
sudo pacman -Syu
# Ubuntu/Debian
# Fedora
# Arch
Disk Encryption: If you haven't already, enable full disk encryption:
Use LUKS during Linux installation
Consider encrypting external drives
Enable encrypted swap
Additional Privacy Tools to Consider:
VPN: While not a magic bullet, still useful for some threat models
Tor Browser: For truly anonymous web browsing
Signal: For private messaging
ProtonMail: For private email
Veracrypt: For encrypted file containers
Understanding Your Threat Model
Before relying solely on this toolkit, consider:
Who are you protecting against?
Casual data harvesting by tech companies
Network-level surveillance by ISPs
Local network attackers (coffee shop WiFi)
Government surveillance
Criminal hackers
What are you protecting? Browsing habits and personal interests
Personal files and documents
Communication with others
Financial and business information
Political or activist activities
What are the consequences of failure?
Embarrassment or social consequences
Financial loss
Professional damage
Legal troubles
Physical safety concerns
## Troubleshooting

### Common Issues and Solutions

**Firewall blocks a service you need (gaming, dev server, etc.)**

Solution:
# Allow specific ports
sudo ufw allow 8080
sudo ufw allow from 192.168.1.0/24
sudo ufw allow out on tun0
# Allow port 8080
# Allow local network
# Allow VPN interface
# Check current rules
sudo ufw status numbered
# Delete unwanted rules
sudo ufw delete [number]
**DNS resolution issues (sites don’t load or are slow)**

Solution:
# Check DNS status (use resolvectl on newer systems, systemd-resolve on older)
resolvectl status
# or: systemd-resolve --status
# Flush DNS cache
resolvectl flush-caches
# or: sudo systemd-resolve --flush-caches
# Test DNS resolution
nslookup google.com
dig google.com
# Temporary fallback to regular DNS
sudo systemctl stop systemd-resolved
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf

**systemd-resolved not found (e.g. on Kali Linux)**

If you see "systemd-resolved is not installed or not used", Kali often uses NetworkManager instead. The script writes `/etc/systemd/resolved.conf` for future use, but for encrypted DNS now:

- **NetworkManager:** Edit connection → IPv4/IPv6 → DNS: `1.1.1.1, 8.8.8.8` (or use DoH-capable DNS)
- **Firefox:** Settings → Privacy & Security → Enable "DNS over HTTPS" and choose a provider (Cloudflare, etc.)
**Browser compatibility:** Separate profile, relax settings for some sites, or use another browser.

**Application sandboxing problems:** Check status with `firejail --list`; use a custom profile with `--read-write=~/Documents` if needed; to disable sandboxing for an app, remove the firejail symlink (e.g. `sudo rm /usr/local/bin/app_name`).

**System performance:** Check with `htop`/`iotop`, review `sudo ufw status verbose`; consider disabling some hardening if needed.

**Log files:** `/tmp/privacy_toolkit_*.log` (or the path shown at end of dry-run). Useful commands: `sudo ufw status verbose`, `resolvectl status` or `systemd-resolve --status`, `ss -tuln`, `firejail --list`.

---

## Advanced Customization

**Firewall:** Add rules for gaming (e.g. UDP 3478–3480, Steam), dev (3000, 8080), or local subnet.

**Adding application-specific rules:**
# Gaming applications
sudo ufw allow out 3478:3480/udp
sudo ufw allow out 7777:7784/tcp
sudo ufw allow out 27000:27100/tcp
# Discord voice
# Steam
# Steam games
# Development tools
sudo ufw allow 3000
# React dev server
sudo ufw allow 8080
# Common dev port
sudo ufw allow from 192.168.1.0/24 # Local network access
Creating Service-Specific Profiles:
# Create work profile
sudo ufw allow out 443 comment 'HTTPS for work'
sudo ufw allow out 993 comment 'IMAP SSL for email'
sudo ufw allow out 25 comment 'SMTP for email'
# Create gaming profile
sudo ufw allow out 3478:3480/udp comment 'Discord'
sudo ufw allow out 7777:7784/tcp comment 'Steam'Customizing DNS Configuration
Using Alternative DNS Providers: Edit /etc/systemd/resolved.conf :
[Resolve]
# Quad9 (privacy-focused)
DNS=9.9.9.9#dns.quad9.net 149.112.112.112#dns.quad9.net
# OpenDNS (with filtering)
DNS=208.67.222.222#opendns.com 208.67.220.220#opendns.com
# AdGuard (with ad blocking)
DNS=94.140.14.14#adguard-dns.com 94.140.15.15#adguard-dns.com
Advanced Browser Hardening
Creating Multiple Browser Profiles:
# Create work profile
firefox -P work -no-remote
# Create personal profile
firefox -P personal -no-remote
# Create high-security profile
firefox -P secure -no-remote
Additional Privacy Extensions:
uBlock Origin: Advanced ad and tracker blocking
ClearURLs: Remove tracking parameters from URLs
Decentraleyes: Protect against tracking via CDNs
Cookie AutoDelete: Automatically delete cookies
Multi-Account Containers: Isolate browsing contexts
Custom Sandboxing Profiles
Creating Application-Specific Profiles:
# Custom profile for document editing
cat > ~/.config/firejail/libreoffice-custom.profile << EOF
include libreoffice.profile
caps.drop all
private-cache
private-dev
private-tmp
read-only ${HOME}/Templates
read-write ${HOME}/Documents
EOF
# Use custom profile
firejail --profile=libreoffice-custom libreoffice
System Hardening Customization
Additional Kernel Parameters: Add to /etc/sysctl.d/99-privacy-hardening.conf :
# Additional network hardening
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_sack = 0
net.ipv4.tcp_window_scaling = 0
# Additional memory protection
kernel.exec-shield = 1
kernel.randomize_va_space = 2
# Process restrictions
kernel.yama.ptrace_scope = 1
## Frequently Asked Questions

**Q: Will this break my existing applications?** A: The toolkit is designed to minimize
breakage, but some applications may need adjustment. Each change asks for your
permission, and you can skip components that might interfere with your workflow.
Q: How much will this slow down my system? A: Performance impact is minimal. DNS
encryption adds a small delay to initial connections, and sandboxing has negligible
overhead. Most users won't notice any difference.
Q: Can I undo these changes? A: Most changes can be reverted:
Firewall: sudo ufw reset
DNS: Edit /etc/systemd/resolved.conf
Browser: Delete user.js files
Sandboxing: sudo firecfg --clean
System hardening: Remove files from /etc/sysctl.d/
**Q: Why not use a VPN instead?** A: VPNs are useful but not sufficient alone. This toolkit
addresses system-level privacy issues that VPNs can't solve, like browser fingerprinting,
metadata leakage, and local application security.
Q: Is this better than using Tails or Qubes? A: Different tools for different needs:
Tails: Best for temporary, anonymous sessions
Qubes: Best for high-security compartmentalization
This toolkit: Best for hardening your daily-use Linux system
Q: Why systemd-resolved instead of other DNS solutions? A: Systemd-resolved is
already present on most modern Linux systems, supports DoH/DoT out of the box, and
integrates well with existing network management tools.
Privacy Questions
Q: How does this compare to using Tor? A: This toolkit hardens your regular browsing,
while Tor provides anonymity through routing. Use both for different purposes:
This toolkit: Daily browsing with improved privacy
Tor: Anonymous browsing when identity protection is critical
Q: Will this protect against government surveillance? A: This toolkit provides protection
against casual surveillance and data harvesting. For protection against targeted government
surveillance, you need additional operational security measures beyond technical tools.
Q: What about mobile devices? A: This toolkit is Linux-specific. For mobile privacy:
Android: Use LineageOS, F-Droid apps, and privacy-focused ROMs
iOS: Limited options due to Apple's restrictions
Troubleshooting Questions
Q: What if I can't connect to certain websites? A: Try these steps:
1. Check if it's a DNS issue: nslookup website.com
2. Temporarily disable firewall: sudo ufw disable
3. Test with a different browser or profile
4. Check browser console for specific errors
Q: How do I know if everything is working correctly? A: Use the built-in audit command:
privacy-audit
This will show you the status of all privacy components.
Q: What should I do if I suspect my privacy setup has been compromised? A: 1. Run privacy-audit to check configuration integrity
2. Review firewall logs: sudo journalctl -u ufw
3. Check for unexpected network connections: ss -tuln
4. Consider running from a live USB if compromise is suspected
## Conclusion

The Linux Privacy Setup Toolkit provides a solid foundation for digital privacy. Privacy is an ongoing process: run `privacy-audit` regularly, keep the system updated, and adapt to your threat model. For the latest version and to contribute, see the project repository on GitHub.
