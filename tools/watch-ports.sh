#!/usr/bin/env bash
# Live USB port watcher for USB port mapping. Runs under Linux (e.g. a live USB) on the
# laptop itself, as a normal user; it only reads sysfs:
#   bash watch-ports.sh
# Plug a USB2 stick and a USB3 stick into each physical port (both orientations for
# Type-C), and toggle the webcam kill switch. Each attach/detach prints the
# root-hub port, macOS port number (hex) and ACPI name. Ctrl-C to stop.
export PATH=/usr/local/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin

declare -A ctrl_name=([0000:00:14.0]=XHC [0000:00:0d.0]=TXHC)

describe() { # $1 = sysfs usb device dir of a root-hub child, e.g. /sys/bus/usb/devices/3-7
    local dev=$1 busnum portnum hub pci ctrl acpi port_dir speed id prod mac
    busnum=$(<"$dev/busnum")
    portnum=${dev##*-}
    hub=$(readlink -f "/sys/bus/usb/devices/usb$busnum")
    pci=$(basename "$(dirname "$hub")")
    ctrl=${ctrl_name[$pci]:-$pci}
    port_dir="/sys/bus/usb/devices/$busnum-0:1.0/usb$busnum-port$portnum"
    acpi=$(cat "$port_dir/firmware_node/path" 2>/dev/null || echo '?')
    mac=$(printf '0x%02x' "$(( $(cat "$port_dir/firmware_node/adr" 2>/dev/null || echo "$portnum") ))")
    speed=$(<"$dev/speed")
    id="$(<"$dev/idVendor"):$(<"$dev/idProduct")"
    prod=$(cat "$dev/product" 2>/dev/null)
    printf 'bus%s-port%s  ctrl=%-4s  macOS port=%s  acpi=%-28s  speed=%sM  %s %s\n' \
        "$busnum" "$portnum" "$ctrl" "$mac" "$acpi" "$speed" "$id" "$prod"
}

snapshot() {
    local d
    for d in /sys/bus/usb/devices/[0-9]*-[0-9]*; do
        [[ $(basename "$d") =~ ^[0-9]+-[0-9]+$ ]] || continue # root-hub children only
        describe "$d"
    done | sort
}

echo "== currently attached =="
prev=$(snapshot)
printf '%s\n' "$prev"
echo "== watching (Ctrl-C to stop) =="
while sleep 0.5; do
    cur=$(snapshot)
    if [[ $cur != "$prev" ]]; then
        comm -13 <(printf '%s\n' "$prev") <(printf '%s\n' "$cur") | sed "s/^/$(date +%T) + /"
        comm -23 <(printf '%s\n' "$prev") <(printf '%s\n' "$cur") | sed "s/^/$(date +%T) - /"
        prev=$cur
    fi
done
