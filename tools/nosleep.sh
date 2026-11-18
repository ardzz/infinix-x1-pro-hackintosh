#!/bin/bash
# Display-sleep-only power policy for this laptop.
# S3 resume loses the eDP panel (HPD stays low, screen stays black) and hibernation does not
# resume, so system sleep and hibernation are disabled. Display sleep works with the
# -nodisplaysleepDC6 boot-arg that the published config already carries.
# Run on macOS with sudo; pass the config.plist(s) on the mounted ESP so OpenCore's
# Misc/Boot/HibernateMode is set to None as well:
#   sudo diskutil mount disk0s1        # or whichever partition is your ESP
#   sudo bash nosleep.sh /Volumes/EFI/EFI/OC/config.plist
set -euo pipefail
(( $# )) || { echo "usage: $0 /path/to/EFI/OC/config.plist [more config.plist ...]" >&2; exit 2; }
pmset -a displaysleep 10 sleep 0 disksleep 10 hibernatemode 0 standby 0 autopoweroff 0 powernap 0 proximitywake 0
pmset -a disablesleep 1
rm -f /var/vm/sleepimage
for f in "$@"; do
    /usr/libexec/PlistBuddy -c "Set :Misc:Boot:HibernateMode None" "$f"
    plutil -lint "$f" >/dev/null
    echo "$f: HibernateMode=$(/usr/libexec/PlistBuddy -c "Print :Misc:Boot:HibernateMode" "$f")"
done
sync
pmset -g | grep -E "SleepDisabled|displaysleep|^ sleep|hibernatemode|standby |autopoweroff|powernap|proximitywake"
