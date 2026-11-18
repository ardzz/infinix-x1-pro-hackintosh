#!/usr/bin/env python3
"""Generate UTBMap.kext (USBToolBox map) for Infinix INBook X1 Pro (Ice Lake-U).

Edit CONTROLLERS below after physical confirmation (watch-ports.sh), then re-run on any OS
with Python 3 (no sudo needed):
    python3 build_utbmap.py
Output: ./UTBMap.kext/Contents/Info.plist (codeless, depends on USBToolBox.kext).
Copy it to EFI/OC/Kexts/ and keep XhciPortLimit disabled.
"""
import plistlib
import shutil
import struct
from pathlib import Path

# UsbConnector: 0 USB2 Type-A, 3 USB3 Type-A, 8 Type-C USB2-only, 9 Type-C w/ switch, 255 internal
CONTROLLERS = {
    # personality name: (IOPCIPrimaryMatch, [(name, port, connector, comment), ...])
    "XHC": (
        "0x34ed8086",  # 00:14.0 Ice Lake-LP USB 3.1 xHCI
        [
            ("HS01", 0x01, 9, "CONFIRMED USB-C #2 (iPhone); Linux peer SS01"),
            ("HS02", 0x02, 9, "CONFIRMED USB-C #1 (iPhone, both orientations); USB3 lanes on TXHC"),
            ("HS03", 0x03, 255, "CONFIRMED internal webcam 1bcf:2087 (kill switch)"),
            ("HS04", 0x04, 3, "CONFIRMED USB-A 3.0 left (Cruzer); Linux peer SS04"),
            ("HS05", 0x05, 255, "internal: Realtek RTS5129 microSD reader 0bda:0129 attached"),
            ("HS06", 0x06, 3, "CONFIRMED USB-A 3.0 right (Cruzer); Linux peer SS02"),
            ("HS07", 0x07, 3, "CONFIRMED USB-A right, user-labelled 2.0; no Linux peer, but RTL9201 hit SS06 earlier -> kept as 3"),
            ("HS10", 0x0A, 255, "internal: Intel AX201 Bluetooth 8087:0026 attached"),
            ("SS01", 0x0D, 9, "Linux peer of HS01 (USB-C #2)"),
            ("SS02", 0x0E, 3, "Linux peer of HS06 (USB-A 3.0 right)"),
            ("SS04", 0x10, 3, "Linux peer of HS04 (USB-A 3.0 left)"),
            ("SS05", 0x11, 3, "_UPC connectable, no peer; kept (USB3 lanes not physically tested)"),
            ("SS06", 0x12, 3, "RTL9201 enumerated here at SuperSpeed (likely HS07's companion)"),
            # omitted: HS08/HS09 (no physical port hit them in plug test), SS03 ('not used'), USR1/USR2
        ],
    ),
    "TXHC": (
        "0x8a138086",  # 00:0d.0 Ice Lake TCSS (Thunderbolt 3) USB controller
        [
            # TXHC.HS01 omitted: TCSS has no USB2 lanes (USB2 of Type-C comes from XHC HSxx)
            ("SS01", 0x02, 9, "UBTC.CR01 Type-C (RUCC 1); unconfirmed"),
            ("SS02", 0x03, 9, "UBTC.CR02 Type-C (RUCC 2); unconfirmed"),
            ("SS03", 0x04, 9, "UBTC.CR03 Type-C (RUCC 3); unconfirmed"),
            ("SS04", 0x05, 9, "UBTC.CR04 Type-C (RUCC 4); unconfirmed"),
        ],
    ),
}


def le32(value: int) -> bytes:
    return struct.pack("<I", value)


def build(out_dir: Path) -> Path:
    personalities = {}
    for name, (pci_match, ports) in CONTROLLERS.items():
        assert len(ports) <= 15, f"{name}: {len(ports)} ports exceeds the 15-port limit"
        assert len({p[0] for p in ports}) == len(ports), f"{name}: duplicate port names"
        personalities[name] = {
            "CFBundleIdentifier": "com.dhinakg.USBToolBox.kext",
            "IOClass": "USBToolBox",
            "IOMatchCategory": "USBToolBox",
            "IOProviderClass": "IOPCIDevice",
            "IOPCIPrimaryMatch": pci_match,
            "IOProviderMergeProperties": {
                "port-count": le32(max(p[1] for p in ports)),
                "ports": {
                    pname: {"port": le32(pnum), "UsbConnector": conn, "#comment": comment}
                    for pname, pnum, conn, comment in ports
                },
            },
        }

    info = {
        "CFBundleDevelopmentRegion": "English",
        "CFBundleGetInfoString": "v1.1",
        "CFBundleIdentifier": "com.dhinakg.USBToolBox.map",
        "CFBundleInfoDictionaryVersion": "6.0",
        "CFBundleName": "UTBMap",
        "CFBundlePackageType": "KEXT",
        "CFBundleShortVersionString": "1.1",
        "CFBundleSignature": "????",
        "CFBundleVersion": "1.1",
        "IOKitPersonalities": personalities,
        "OSBundleLibraries": {"com.dhinakg.USBToolBox.kext": "1.0.0"},
        "OSBundleRequired": "Root",
    }

    kext = out_dir / "UTBMap.kext"
    if kext.exists():
        shutil.rmtree(kext)
    (kext / "Contents").mkdir(parents=True)
    with (kext / "Contents/Info.plist").open("wb") as f:
        plistlib.dump(info, f, sort_keys=True)
    return kext


if __name__ == "__main__":
    print(build(Path(__file__).resolve().parent))
