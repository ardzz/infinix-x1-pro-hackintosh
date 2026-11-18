#!/bin/bash
# Install the ALC269VB headphone fix LaunchDaemon. Run on macOS from this folder: sudo bash install-hpfix.sh
# Needs alc-verb (from the AppleALC release zip) next to this script and boot-arg alcverbs=1.
set -euo pipefail
cd "$(dirname "$0")"
install -d -m 755 /usr/local/libexec
install -m 755 alc-verb /usr/local/libexec/alc-verb
install -m 755 alc269vb-hpfix.sh /usr/local/libexec/alc269vb-hpfix.sh
install -m 644 -o root -g wheel com.infinix.alc269vb-hpfix.plist /Library/LaunchDaemons/com.infinix.alc269vb-hpfix.plist
launchctl bootout system/com.infinix.alc269vb-hpfix 2>/dev/null || true
launchctl bootstrap system /Library/LaunchDaemons/com.infinix.alc269vb-hpfix.plist
nvram boot-args | grep -q alcverbs=1 || echo "WARNING: boot-arg alcverbs=1 not active; add it to config.plist and reboot"
echo "installed; log: /var/log/alc269vb-hpfix.log"
