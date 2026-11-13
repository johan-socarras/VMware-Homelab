# kali-linux

The security VM: Kali with its default tool set, sitting on the `lab` network to
audit the other VMs from the inside. Its first scan found two services that should
not have been reachable, and both were closed (see the
[security audit](../../docs/security-audit.md)).

| | |
|---|---|
| Guest OS | Kali Linux Rolling (ISO 2026.3), Xfce desktop with LightDM, `kali-linux-default` (nmap, Wireshark, Metasploit, Burp Suite, Hydra, sqlmap, John the Ripper...) |
| Hardware | Virtual hardware 22, UEFI **without** Secure Boot (Kali does not support it), 40 GB NVMe disk (thin), LVM |
| CPU / RAM | 2 vCPU, 4 GB |
| Network | `eth0` on `nat`: `10.10.8.14/24` (NetworkManager profile `nat`)<br>`eth1` on `lab`: `10.10.10.14/24`, no default route (profile `lab`)<br>Kali keeps the classic `eth0`/`eth1` names (`net.ifnames=0`), which is what its users expect |
| Access | User `johan` (sudo, zsh, `wireshark` group); SSH enabled (Kali ships it off) with keys only; root has no password |
| Power profile | `security`, together with the servers it audits |

The name has no version because Kali is a rolling release.

## How it is built

1. Download `kali-linux-2026.3-installer-netinst-amd64.iso` from cdimage.kali.org and
   check it against the official `SHA256SUMS`.
2. Build the unattended ISO:
   ```bash
   ./build-iso.sh kali-linux-2026.3-installer-netinst-amd64.iso kali-linux-auto.iso \
       /path/to/kali-linux.hash ~/.ssh/id_ed25519.pub
   ```
   [`build-iso.sh`](build-iso.sh) adds [`preseed.cfg`](preseed.cfg),
   [`finish.sh`](finish.sh), the public key and a GRUB entry that also loads Kali's
   own installer profile (`simple-cdd/profiles=kali`, which sets up the
   `kali-rolling` sources, zsh and the groups).
3. Create the VM from [`kali-linux.vmx.example`](kali-linux.vmx.example) and boot it
   from the ISO. About 2,500 packages are downloaded during the install, which took
   11 minutes; the VM powers itself off.
4. Detach the ISO and take the `baseline` snapshot powered off.

## What it took

**The installer's network profile was broken.** Kali's installer writes its
NetworkManager profile with the key `mac=`, which NetworkManager ignores (the real
key is `mac-address=`). The profile ended up bound to no interface and the `nat`
address landed on the `lab` NIC, so the first boot had no internet. The preseed now
tells the installer not to copy its network setup
(`netcfg/target_network_config select loopback`) and [`finish.sh`](finish.sh) writes
one profile per NIC, each bound by `interface-name`. On this VM the fix was applied by
hand with the same code; a fresh install from the fixed ISO, into a throwaway VM created
from [`kali-linux.vmx.example`](kali-linux.vmx.example), had `nat` on `eth0`, `lab` on
`eth1` and internet from its first boot. See
[TSH-01](../../troubleshooting/01-kali-network-profile.md).

## Verify

```bash
vmrun start ~/vmware/kali-linux/kali-linux.vmx nogui
```

```text
$ ssh johan@10.10.8.14 'ip -br a; nmcli -f NAME,DEVICE con show'
lo               UNKNOWN        127.0.0.1/8 ::1/128
eth0             UP             10.10.8.14/24
eth1             UP             10.10.10.14/24
NAME  DEVICE
nat   eth0
lab   eth1
lo    lo

$ ssh johan@10.10.8.14 nmap -n 10.10.10.11      # with Debian running
Nmap scan report for 10.10.10.11
Host is up (0.000031s latency).
Not shown: 999 closed tcp ports (reset)
PORT   STATE SERVICE
22/tcp open  ssh
MAC Address: 00:0C:29:3B:62:13 (VMware)

Nmap done: 1 IP address (1 host up) scanned in 0.10 seconds
```

## Files

| File | What it is |
|---|---|
| [`preseed.cfg`](preseed.cfg) | Installer answers: Kali profile, static network during the install, user, LVM, Xfce + default tools |
| [`finish.sh`](finish.sh) | Runs at the end of the install: `eth0`/`eth1` names, one NetworkManager profile per NIC, SSH on with keys only |
| [`build-iso.sh`](build-iso.sh) | Builds the unattended ISO from the official netinst ISO |
| [`kali-linux.vmx.example`](kali-linux.vmx.example) | The VM's configuration, exported with [`scripts/export-vmx.py`](../../scripts/export-vmx.py) |

**Snapshots:** `baseline`.
