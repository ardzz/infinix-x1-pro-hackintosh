#!/bin/bash
# Switch OpenCore config between laobamac AirportItlwm (plain native Wi-Fi) and
# ForbiddenItlwm (AirDrop). Run on macOS with sudo, ESP mounted (a timestamped .bak copy is written):
#   sudo bash airdrop-mode.sh on|off /Volumes/EFI/EFI/OC/config.plist
# ForbiddenItlwm AirDrop only activates on 15.8 / 15.8.1 / 15.8.2 / 15.8.3 (24H23, 24H32, 24H232, 24H241).
# Before any macOS update: run "off" (or at least drop -btleadv), update, check the new build is supported, then "on".
set -euo pipefail
mode=${1:?on|off}; cfg=${2:?path to config.plist}
PB=/usr/libexec/PlistBuddy
GUID=7C436110-AB2A-4BBB-A880-FE41995C9F82
FLAGS="-btleadv -itlawdlcoexprobe -itlawdliface -itlawdlnativeup -itlawdlcoexrx -itlawdlcoextx -itlawdlcoexmulti -itlawdlcoexdata -itlawdlmitx -itlawdlelicit -itlawdlcaps -itlawdlsvcmerge -itlawdlawsync itlawdlintcoal=4 -itlawdlcoexbatx -itlawdlcoexpeerpause -itlawdlcoexbatrace itlawdltxqueue=4096"

set_kext() { # bundle enabled
    local i=0 b
    while b=$($PB -c "Print :Kernel:Add:$i:BundlePath" "$cfg" 2>/dev/null); do
        [[ $b == "$1" ]] && { $PB -c "Set :Kernel:Add:$i:Enabled $2" "$cfg"; echo "$1 -> $2"; return; }
        i=$((i + 1))
    done
    echo "WARN: $1 not in Kernel/Add" >&2
}

build=$(sw_vers -buildVersion)
cp "$cfg" "$cfg.bak-$(date +%Y%m%d-%H%M%S)"
args=$($PB -c "Print :NVRAM:Add:$GUID:boot-args" "$cfg")
clean=$(tr ' ' '\n' <<<"$args" | grep -Ev '^(-btleadv|-?itlawdl.*)$' | xargs)

case $mode in
on)
    case $build in 24H23|24H32|24H232|24H241) ;; *) echo "NOTE: build $build not verified by ForbiddenItlwm; AirDrop stays off (plain Wi-Fi)." ;; esac
    set_kext AirportItlwm.kext false; set_kext itlwm.kext false; set_kext IntelBTPatcher.kext false
    set_kext BTLEAdvFixup.kext true; set_kext ForbiddenItlwm.kext true
    $PB -c "Set :NVRAM:Add:$GUID:boot-args $clean $FLAGS" "$cfg" ;;
off)
    set_kext ForbiddenItlwm.kext false; set_kext BTLEAdvFixup.kext false
    set_kext AirportItlwm.kext true; set_kext IntelBTPatcher.kext true
    $PB -c "Set :NVRAM:Add:$GUID:boot-args $clean" "$cfg" ;;
*) echo "usage: $0 on|off config.plist" >&2; exit 2 ;;
esac
plutil -lint "$cfg"
echo "boot-args: $($PB -c "Print :NVRAM:Add:$GUID:boot-args" "$cfg")"
echo "Reboot. Verify: ioreg -l -w0 | grep -E '\"ItlwmAWDL(InterfaceBuild|BuildCheck)\"|\"ITLAWDLCoex(Added|Channel|CountryLearned)\"'"
