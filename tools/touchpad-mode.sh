#!/bin/bash
# Switch the SYNA3602 I2C touchpad setup in OpenCore config.plist. Run on macOS with sudo
# (a timestamped .bak copy of the config is written next to it):
#   sudo bash touchpad-mode.sh native|v265|gpio|poll|gpi0-on|gpi0-off /Volumes/EFI/EFI/OC/config.plist
#   v265   : VoodooI2C 2.6.5 set, stock DSDT GpioInt (published default; touchpad works)
#   native : VoodooI2C 2.9.1, stock DSDT GpioInt (attaches on 15.8.3 but the touchpad stays dead)
#   gpio   : VoodooI2C 2.9.1 + SSDT-TPD0-GPIO (pin 0x6D hard-coded) + TPD0 _CRS->XCRS patch
#   poll   : VoodooI2C 2.9.1 + SSDT-TPD0-POLL (no interrupt) + TPD0 _CRS->XCRS patch
#   gpi0-on/off : SSDT-GPI0 (only if ioreg shows GPI0 as PNP0C02)
set -euo pipefail
mode=${1:?mode}; cfg=${2:?config.plist}
PB=/usr/libexec/PlistBuddy

set_by() { # section key value enabled
    local i=0 v
    while v=$($PB -c "Print :$1:$i:$2" "$cfg" 2>/dev/null); do
        [[ $v == "$3" ]] && { $PB -c "Set :$1:$i:Enabled $4" "$cfg"; echo "$3 -> $4"; return; }
        i=$((i + 1))
    done
    echo "WARN: $3 not found in $1" >&2
}
kexts() { # 291-enabled 265-enabled
    for b in VoodooI2C.kext/Contents/PlugIns/VoodooGPIO.kext VoodooI2C.kext/Contents/PlugIns/VoodooI2CServices.kext VoodooI2C.kext VoodooI2CHID.kext; do
        set_by Kernel:Add BundlePath "$b" "$1"
        local alt=${b/#VoodooI2CHID.kext/VoodooI2CHID-2.6.5.kext}
        [[ $alt == "$b" ]] && alt=${b/#VoodooI2C.kext/VoodooI2C-2.6.5.kext}
        set_by Kernel:Add BundlePath "$alt" "$2"
    done
}
override() { # patch gpio poll
    set_by ACPI:Patch Comment "TPD0 _CRS to XCRS (for SSDT-TPD0-GPIO or -POLL)" "$1"
    set_by ACPI:Add Path SSDT-TPD0-GPIO.aml "$2"
    set_by ACPI:Add Path SSDT-TPD0-POLL.aml "$3"
}

cp "$cfg" "$cfg.bak-$(date +%Y%m%d-%H%M%S)"
case $mode in
native) kexts true false; override false false false ;;
v265)   kexts false true; override false false false ;;
gpio)   kexts true false; override true true false ;;
poll)   kexts true false; override true false true ;;
gpi0-on)  set_by ACPI:Add Path SSDT-GPI0.aml true ;;
gpi0-off) set_by ACPI:Add Path SSDT-GPI0.aml false ;;
*) echo "unknown mode" >&2; exit 2 ;;
esac
plutil -lint "$cfg"
echo "Reboot, then: log show --last boot --predicate 'sender CONTAINS[c] \"Voodoo\"' | tail -50"
