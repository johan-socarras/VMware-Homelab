#!/usr/bin/env python3
"""Writes a shareable <vm>.vmx.example from a live VMware Workstation .vmx.

Drops what Workstation generates per machine (UUIDs, generated MACs, VM generation ID,
NVMe NQN, VMCI id, runtime state, auto-assigned PCI slots), points disks at their base
.vmdk instead of the current snapshot delta, and keeps everything that defines the VM:
hardware version, guest OS, firmware, CPU and memory, devices, pinned PCI slots, networks
and annotation.

Usage: export-vmx.py <path/to/vm.vmx> <output.vmx.example>
"""
import re
import sys
from pathlib import Path

DROP = re.compile(
    r"^(uuid\.(bios|location)|vmci0\.id|nvme0\.subnqnUUID|ethernet\d+\.generatedAddress(Offset)?"
    r"|vm\.(createDate|lastPowerRequestTimestamp|genid)|guestInfo\.|monitor\.phys_bits_used|vmotion\."
    r"|numa\.autosize\.|svga\.(vramSize|guestBackedPrimaryAware)|cleanShutdown|softPowerOff"
    r"|tools\.capability\.|toolsInstallManager\.|vmxstats\.filename|extendedConfigFile"
    r"|checkpoint\.|sched\.swap\.derivedName|migrate\.hostlog|mainMem\.backing"
    r"|usb_xhci:\d+\.|scsi\d+:\d+\.redo|nvme\d+:\d+\.redo|sata\d+:\d+\.redo"
    r"|RemoteDisplay\.vnc\.)"
)
# PCI slots Workstation assigns on its own; the ones pinned on purpose (NICs, NVMe) are kept
AUTO_SLOT = re.compile(r"^(pciBridge\d+|sata\d+|scsi\d+|usb|ehci|usb_xhci|sound)\.pciSlotNumber")

if len(sys.argv) != 3:
    sys.exit("usage: export-vmx.py <path/to/vm.vmx> <output.vmx.example>")
src, dst = sys.argv[1], sys.argv[2]
out = ["# Example configuration exported from a working VM with scripts/export-vmx.py.",
       "# Machine-specific values (UUIDs, generated MACs, runtime state) were removed;",
       "# VMware Workstation regenerates them when the VM is registered and powered on."]
for line in Path(src).read_text(encoding="utf-8").splitlines():
    key = line.split("=", 1)[0].strip()
    if line.startswith("#!") or DROP.match(key) or AUTO_SLOT.match(key):
        continue
    # A disk that has snapshots points at its newest delta (name-000001.vmdk): use the base disk
    line = re.sub(r'-0000\d\d\.vmdk"', '.vmdk"', line)
    if "/home/" in line:
        sys.exit(f"host path left in {src}: {line}")
    out.append(line)
Path(dst).write_text("\n".join(out) + "\n", encoding="utf-8")
print(f"{dst}: {len(out) - 3} settings")
