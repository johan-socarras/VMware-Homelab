# TSH-04 — The Windows Server VM would not boot any ISO

## Symptom

The new [windows-server-2025-core](../vms/windows-server-2025-core/README.md) VM never
showed "Press any key to boot from CD or DVD". The firmware gave up on the CD within a
second of power-on:

```text
EFI VMware Virtual SATA CDROM Drive (1.0)... No compatible bootloader found.
```

## What it was not

| Test | Result |
|---|---|
| Secure Boot off | Same error |
| Only the Microsoft ISO connected | Same error: drive `1.0` is the Microsoft ISO |
| The ISO's El Torito catalog (`xorriso -report_el_torito`) | A normal UEFI entry |
| The EFI boot image extracted from the ISO | A valid FAT12 image with a signed x64 `BOOTX64.EFI` |
| A small test ISO with that same boot image | Same error |
| The ESXi installer ISO, which boots fine in another VM | **Same error** |

The last test moved the problem from the ISO to the VM.

## Cause

`vmware.log` named it:

```text
... EFI2.7 32-bit.
... ROM version: ... (32-bit RELEASE)
```

The VM was running a **32-bit UEFI firmware**, which cannot load any 64-bit boot loader.
The guest type had been set to `windows2025srvNext-64`, read as "Windows Server 2025".
To VMware, `windows<year>srvNext` means the release *after* that year:
`windows2019srvNext-64` is Windows Server 2022 and `windows2022srvNext-64` is
Windows Server 2025. Workstation 26 does not fully know the newer ID (its VMware Tools
map did not list it either) and fell back to 32-bit firmware.

## Fix

```text
guestOS = "windows2022srvNext-64"
```

After deleting the VM's `nvram` file so the firmware started fresh, the log showed
`EFI2.7 64-bit`, the CD booted and the unattended install ran.

## Lesson

When every boot medium fails the same way, suspect the machine rather than the media.
`vmware.log` reports the firmware it loaded, and that line answered in seconds what the
ISO tests could not.
