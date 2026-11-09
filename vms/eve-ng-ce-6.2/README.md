# eve-ng-ce-6.2

EVE-NG Community 6.2, the network emulator I use for Cisco routing and switching labs.
The labs themselves are documented in a separate repository,
[EVE-NG-Networking-Labs](https://github.com/johan-socarras/EVE-NG-Networking-Labs).

| | |
|---|---|
| Guest OS | EVE-NG Community 6.2 (Ubuntu based), declared as `ubuntu-64` |
| Hardware | Virtual hardware 22, BIOS, LSI Logic SCSI disk, e1000 NIC |
| CPU / RAM | 8 vCPU, 16 GB, with nested virtualization (`vhv.enable`) so the emulated routers and switches run with hardware acceleration |
| Network | `bridged` (vmnet0): a fixed address on the home LAN, so the web UI and SSH are reachable from any device at home |
| Power profile | `network`, on its own: it needs the RAM of two or three of the other VMs |

## Why it is configured differently

This VM predates the rest of the lab and is kept as it was imported: BIOS
firmware, an e1000 NIC and the bridged network. Changing the NIC model would
rename the interface inside EVE-NG and lose the address the labs depend on, so
the network is deliberately left alone. It was cleaned up on 2026-11-06: renamed
to the naming convention, sound and 3D turned off, an empty disconnected CD, an
English annotation and a `baseline` snapshot taken powered off.

## Verify

```bash
vmrun start ~/vmware/eve-ng-ce-6.2/eve-ng-ce-6.2.vmx nogui
# then open the EVE-NG web UI at the VM's LAN address
```

## Files

| File | What it is |
|---|---|
| [`eve-ng-ce-6.2.vmx.example`](eve-ng-ce-6.2.vmx.example) | The VM's configuration, exported with [`scripts/export-vmx.py`](../../scripts/export-vmx.py) |

**Snapshots:** `baseline` (2026-11-06, powered off).
