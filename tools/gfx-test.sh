#!/bin/bash
# One-change-at-a-time iGPU experiments for the Ice Lake tiled-corruption issue (run on macOS):
#   sudo bash gfx-test.sh <step> /Volumes/EFI/EFI/OC/config.plist
# Every step first restores the saved baseline, then applies exactly one change. Reboot after each.
#   status    : show current iGPU props + boot-args
#   base      : restore baseline (original config before any gfx experiment)
#   noytile   : 1. remove AAPL,GfxYTile
#   nounified : 2. remove framebuffer-unifiedmem (4080 MiB VRAM override)
#   fb8a52    : 3. AAPL,ig-platform-id -> 0x8A520000 (Dortania/WEG default for G7)
#   gucoff    : 6. boot-arg igfxfw=2 -> igfxfw=0
#   nodbeo    : 7. remove enable-dbuf-early-optimizer AND -igfxdbeo
#   vesa      : diagnostic only: add -igfxvesa (no acceleration)
#   dbufdelay2 / dbufdelay3 : keep DBUF fix, set dbuf-optimizer-delay to 2 or 3 seconds (WEG ICL underrun fix)
#   fb8a51    : wake 1. AAPL,ig-platform-id -> 0x8A510002 (ICL black-screen-after-wake workaround)
#   con0f98   : wake 2. framebuffer-con0-enable=1 + framebuffer-con0-flags=0x98 (adds MiscIoPowerWell)
#   con0f198  : wake 3. framebuffer-con0-enable=1 + framebuffer-con0-flags=0x198 (+PowerWell2)
#   agdc0     : wake 4. boot-arg igfxagdc=0
#   fb5c01spoof : 0x8A5C0001 with device-id spoofed to 0x8A5C (as other ICL/Infinix Sequoia EFIs)
#   fb5c01    : 0x8A5C0001 (Ventura-era framebuffer, sleep worked there) on the current baseline (keeps dbuf delay)
#   nodc6     : boot-arg -nodisplaysleepDC6 (keep iGPU out of DC6 while the display sleeps; PPS state survives)
#   dc6cfg0   : boot-arg dc6config=0 (disable HW DC6 entirely)
#   adopt     : make the CURRENT config the new baseline (after a step fixed it)
set -euo pipefail
step=${1:?step}; cfg=${2:?config.plist}
base="$(dirname "$cfg")/config.gfx-baseline.plist"
PB=/usr/libexec/PlistBuddy
DEV='DeviceProperties.Add.PciRoot(0x0)/Pci(0x2,0x0)'
GUID=7C436110-AB2A-4BBB-A880-FE41995C9F82

[[ -f $base ]] || { cp "$cfg" "$base"; echo "baseline saved: $base"; }
args() { $PB -c "Print :NVRAM:Add:$GUID:boot-args" "$cfg"; }
set_args() { $PB -c "Set :NVRAM:Add:$GUID:boot-args $1" "$cfg"; }
rm_prop() { plutil -remove "$DEV.$1" "$cfg" >/dev/null && echo "removed $1"; }
restore() { cp "$base" "$cfg"; }

case $step in
status) ;;
base) restore ;;
noytile) restore; rm_prop 'AAPL,GfxYTile' ;;
nounified) restore; rm_prop framebuffer-unifiedmem ;;
fb8a52) restore; plutil -replace "$DEV.AAPL,ig-platform-id" -data AABSig== "$cfg"; echo "ig-platform-id -> 0000528A" ;;
gucoff) restore; set_args "$(args | sed 's/igfxfw=2/igfxfw=0/')" ;;
nodbeo) restore; rm_prop enable-dbuf-early-optimizer; set_args "$(args | tr ' ' '\n' | grep -vx -- -igfxdbeo | xargs)" ;;
dbufdelay2) restore; plutil -insert "$DEV.dbuf-optimizer-delay" -data AgAAAA== "$cfg"; echo "dbuf-optimizer-delay -> 02000000" ;;
dbufdelay3) restore; plutil -insert "$DEV.dbuf-optimizer-delay" -data AwAAAA== "$cfg"; echo "dbuf-optimizer-delay -> 03000000" ;;
fb8a51) restore; plutil -replace "$DEV.AAPL,ig-platform-id" -data AgBRig== "$cfg"; echo "ig-platform-id -> 0200518A" ;;
con0f98) restore; plutil -insert "$DEV.framebuffer-con0-enable" -data AQAAAA== "$cfg"; plutil -insert "$DEV.framebuffer-con0-flags" -data mAAAAA== "$cfg"; echo "con0 flags -> 98000000" ;;
con0f198) restore; plutil -insert "$DEV.framebuffer-con0-enable" -data AQAAAA== "$cfg"; plutil -insert "$DEV.framebuffer-con0-flags" -data mAEAAA== "$cfg"; echo "con0 flags -> 98010000" ;;
agdc0) restore; set_args "$(args) igfxagdc=0" ;;
fb5c01spoof) restore; plutil -replace "$DEV.AAPL,ig-platform-id" -data AQBcig== "$cfg"; plutil -replace "$DEV.device-id" -data XIoAAA== "$cfg"; echo "ig-platform-id -> 01005C8A, device-id -> 5C8A0000" ;;
fb5c01) restore; plutil -replace "$DEV.AAPL,ig-platform-id" -data AQBcig== "$cfg"; echo "ig-platform-id -> 01005C8A" ;;
nodc6) restore; set_args "$(args) -nodisplaysleepDC6" ;;
dc6cfg0) restore; set_args "$(args) dc6config=0" ;;
vesa) restore; set_args "$(args) -igfxvesa" ;;
adopt) cp "$cfg" "$base"; echo "current config is the new baseline" ;;
*) echo "unknown step" >&2; exit 2 ;;
esac
plutil -lint "$cfg"
echo "boot-args: $(args)"
for k in AAPL,ig-platform-id device-id AAPL,GfxYTile framebuffer-unifiedmem enable-dbuf-early-optimizer dbuf-optimizer-delay framebuffer-con0-flags; do
    v=$(plutil -extract "$DEV.$k" raw -o - "$cfg" 2>/dev/null) || v='<absent>'
    printf '  %-28s %s\n' "$k" "$v"
done
