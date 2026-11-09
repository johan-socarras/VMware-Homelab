# rocky-10-server

The Red Hat family, as most companies run it: a minimal Rocky Linux server with
SELinux enforcing, firewalld allowing only SSH, and SSH with keys only. It was
also the first VM on the isolated `lab` network, so it was used to prove that
`lab` connects the VMs to each other and to nothing else.

| | |
|---|---|
| Guest OS | Rocky Linux 10.2 (Red Quartz), `minimal-environment` plus `open-vm-tools` |
| Hardware | Virtual hardware 22, UEFI with Secure Boot, 20 GB NVMe disk (thin), LVM |
| CPU / RAM | 2 vCPU, 2 GB |
| Network | `ens160` on `nat`: `10.10.8.12/24` (NetworkManager profile `nat`)<br>`ens192` on `lab`: `10.10.10.12/24`, no default route (profile `lab`) |
| Security | SELinux `Enforcing`; firewalld zone `public` with only `ssh`; root locked; SSH key login only |
| Power profile | `servers` |

## How it is built

1. Download `Rocky-10.2-x86_64-boot.iso` from download.rockylinux.org and check it
   against the official `CHECKSUM`.
2. Build the unattended ISO (the password hash and the public key are filled in at
   build time):
   ```bash
   ./build-iso.sh Rocky-10.2-x86_64-boot.iso rocky-10-server-auto.iso \
       /path/to/rocky-10-server.hash ~/.ssh/id_ed25519.pub
   ```
   [`build-iso.sh`](build-iso.sh) reads the ISO's volume label, adds
   [`ks.cfg`](ks.cfg) and a GRUB entry with `inst.ks=hd:LABEL=<label>:/ks.cfg`.
3. Create the VM from [`rocky-10-server.vmx.example`](rocky-10-server.vmx.example)
   and boot it from the ISO. Packages come from `dl.rockylinux.org` during the
   install; it takes about 4 minutes and the VM powers itself off.
4. Detach the ISO and take the `baseline` snapshot powered off.

**Interface names come from PCI slots.** The kickstart refers to `ens160` and
`ens192`, which only holds if the `.vmx` pins the NICs to slots 160 and 192
(`ethernetN.pciSlotNumber`); the example configuration does. On the first install
the kickstart said `ens224` (Debian's name for its second NIC, where the disk took
slot 192), so the `lab` address was added afterwards with `nmcli`.
`firewall --service=ssh` also leaves `cockpit` and `dhcpv6-client` open; the
kickstart now removes them. Both fixes were confirmed with a fresh install into a
throwaway VM created from the example `.vmx`: `ens160` and `ens192` came up with their
addresses, and a scan from Kali found only `22/tcp` (Cockpit's `9090` filtered).

## The `lab` network test

With Debian and Rocky running, each one pinged the other's `lab` address
(about 0.2 ms), and from Debian's `lab` interface neither `1.1.1.1` nor the home
router answered: the VMs on `lab` see each other and nothing else.

## Verify

```bash
vmrun start ~/vmware/rocky-10-server/rocky-10-server.vmx nogui
ssh johan@10.10.8.12 'ip -br addr; getenforce; sudo firewall-cmd --list-services'
# ens160 10.10.8.12/24, ens192 10.10.10.12/24, Enforcing, ssh
```

## Files

| File | What it is |
|---|---|
| [`ks.cfg`](ks.cfg) | Kickstart: static network on both NICs, LVM, locked root, SELinux, firewalld, SSH hardening |
| [`build-iso.sh`](build-iso.sh) | Builds the unattended ISO from the official boot ISO |
| [`rocky-10-server.vmx.example`](rocky-10-server.vmx.example) | The VM's configuration, exported with [`scripts/export-vmx.py`](../../scripts/export-vmx.py) |

**Snapshots:** `baseline`.
