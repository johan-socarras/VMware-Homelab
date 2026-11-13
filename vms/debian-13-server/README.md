# debian-13-server

A headless Debian server, hardened the usual way: SSH with keys only, no root
login, Secure Boot on. It was the first VM built with an unattended install and
became the template for the others.

| | |
|---|---|
| Guest OS | Debian 13.7 (trixie): `standard` + `ssh-server` tasks, plus `open-vm-tools`, `sudo`, `curl` |
| Hardware | Virtual hardware 22, UEFI with Secure Boot, 20 GB NVMe disk (thin), LVM |
| CPU / RAM | 2 vCPU, 2 GB |
| Network | `ens160` on `nat`: `10.10.8.11/24`, gateway and DNS `10.10.8.2`<br>`ens224` on `lab`: `10.10.10.11/24`, no gateway |
| Access | User `johan` (sudo); SSH with a public key only (`PasswordAuthentication no`, `KbdInteractiveAuthentication no`, `PermitRootLogin no`); root locked |
| Power profile | `servers` |

## How it is built

1. Download `debian-13.7.0-amd64-netinst.iso` from cdimage.debian.org and check it
   against the official `SHA256SUMS`.
2. Build the unattended ISO. The password hash is a SHA-512 crypt string
   (`openssl passwd -6`) kept outside the repository:
   ```bash
   ./build-iso.sh debian-13.7.0-amd64-netinst.iso debian-13-server-auto.iso \
       /path/to/debian-13-server.hash ~/.ssh/id_ed25519.pub
   ```
   [`build-iso.sh`](build-iso.sh) uses `xorriso` to add [`preseed.cfg`](preseed.cfg)
   (with the hash filled in), the public key and a GRUB menu that starts the
   automated install after 3 seconds. Debian's signed boot chain is untouched, so
   Secure Boot keeps working.
3. Create the VM from [`debian-13-server.vmx.example`](debian-13-server.vmx.example),
   a 20 GB disk (`vmware-vdiskmanager -c -s 20GB -a lsilogic -t 0 debian-13-server.vmdk`)
   and boot it from the ISO. It installs in about 4 minutes and powers itself off.
4. After the install: detach the ISO, add the second NIC on `lab`
   (`vmnet10`) and give it its address in `/etc/network/interfaces.d/ens224`, then
   take the `baseline` snapshot powered off. The `lab` NIC is a manual step here;
   the VMs built after this one configure both NICs during the install.

## What it took

Two changes after the `baseline` snapshot:

- `nfs-common`, installed to test the NFS share of
  [truenas-25.10-storage](../truenas-25.10-storage/README.md).
- That package also brought `rpcbind`, which listened on `111/tcp` on every
  network. The port scan from [kali-linux](../kali-linux/README.md) found it,
  so it was disabled and masked (`rpcbind.socket` and `rpcbind.service`). NFSv4
  does not need it: Debian still mounts the TrueNAS share with `vers=4.2`, and
  a full port scan now shows only `22/tcp`. See the
  [security audit](../../docs/security-audit.md).

## Verify

```bash
vmrun start ~/vmware/debian-13-server/debian-13-server.vmx nogui
```

```text
$ ssh johan@10.10.8.11 'ip -br addr; mokutil --sb-state; systemctl is-enabled rpcbind.socket'
lo               UNKNOWN        127.0.0.1/8 ::1/128
ens160           UP             10.10.8.11/24 fe80::20c:29ff:fe3b:6209/64
ens224           UP             10.10.10.11/24 fe80::20c:29ff:fe3b:6213/64
SecureBoot enabled
masked

$ ssh -o PubkeyAuthentication=no johan@10.10.8.11
johan@10.10.8.11: Permission denied (publickey).
```

## Files

| File | What it is |
|---|---|
| [`preseed.cfg`](preseed.cfg) | Debian installer answers: locale, static network, user, LVM on the NVMe disk, packages, SSH hardening |
| [`build-iso.sh`](build-iso.sh) | Builds the unattended ISO from the official netinst ISO |
| [`debian-13-server.vmx.example`](debian-13-server.vmx.example) | The VM's configuration, exported with [`scripts/export-vmx.py`](../../scripts/export-vmx.py) |

**Snapshots:** `baseline` (fresh install), `before-rpcbind-fix`.
