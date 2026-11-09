# truenas-25.10-storage

Shared storage for the lab, the way a company gives its hypervisors a datastore:
a ZFS mirror exported over NFS, reachable only from the isolated `lab` network.
[esxi-8-host](../esxi-8-host/README.md) mounts it as its datastore.

| | |
|---|---|
| Guest OS | TrueNAS Community Edition 25.10.8 (Goldeye), the latest stable release when it was built |
| Hardware | Virtual hardware 22, UEFI **without** Secure Boot (TrueNAS does not support it); NVMe: a 16 GB boot disk and two 20 GB data disks, all thin |
| CPU / RAM | 2 vCPU, 8 GB (ZFS uses RAM as its cache) |
| Network | `ens160` on `nat`: `10.10.8.13` (web UI, updates)<br>`ens192` on `lab`: `10.10.10.13` (storage only) |
| Storage | Pool `tank`, the two data disks in a `MIRROR`; dataset `tank/vmstore`; NFS share `/mnt/tank/vmstore` for `10.10.10.0/24` only, NFS bound to `10.10.10.13` only, `maproot` to root (ESXi needs it) |
| Access | `truenas_admin` (web UI and API); root has no password |
| Power profile | `vsphere`, together with ESXi |

## How it is built

1. Download `TrueNAS-SCALE-25.10.8.iso` and check it against its `.sha256`.
2. The TrueNAS installer takes no answer file, so its few screens (target disk,
   admin password) were answered by sending keys to the VM console over a VNC
   server bound to `127.0.0.1` while it ran, removed afterwards.
3. Everything else is done by [`configure.py`](configure.py) through the TrueNAS
   REST API, with only the Python standard library: it builds the mirror, the
   dataset, the NFS share, the static addresses and enables the service.
   ```bash
   ./configure.py <address-it-got-from-dhcp> /path/to/password-file
   ```
   The REST API has been deprecated since TrueNAS 25.04 and is slated for removal, so
   the script is tied to 25.10; a later release would need the JSON-RPC 2.0 WebSocket API.
4. Take the `baseline` snapshot powered off.

**The network change rolls back by design.** TrueNAS applies interface changes with
`interface/commit` and undoes them after 90 seconds unless `interface/checkin`
arrives from the new address. In the REST API the check-in is a **GET** (a POST
returns 405), which is why the first two attempts rolled back. The script checks in
at the new address with a GET. See
[TSH-05](../../troubleshooting/05-truenas-network-rollback.md).

## Tests

- Debian mounted `10.10.10.13:/mnt/tank/vmstore`, wrote and read a file and
  unmounted it; mounting through the `nat` address `10.10.8.13` failed, as it
  should.
- After a reboot: both addresses, pool `ONLINE`, NFS running, web UI answering.
- ESXi mounted the share as datastore `truenas-vmstore` over NFS 4.1 and ran a
  VM from it ([esxi-8-host](../esxi-8-host/README.md)).

## Verify

```bash
vmrun start ~/vmware/truenas-25.10-storage/truenas-25.10-storage.vmx nogui
curl -sk -u truenas_admin https://10.10.8.13/api/v2.0/pool    # tank, ONLINE, MIRROR
```

## Files

| File | What it is |
|---|---|
| [`configure.py`](configure.py) | Post-install configuration through the REST API |
| [`truenas-25.10-storage.vmx.example`](truenas-25.10-storage.vmx.example) | The VM's configuration, exported with [`scripts/export-vmx.py`](../../scripts/export-vmx.py) |

**Snapshots:** `baseline`.
