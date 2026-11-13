# Security audit from Kali

Once the servers were built, [kali-linux](../vms/kali-linux/README.md) scanned them from
inside the isolated `lab` network, the way an attacker who got into that network would
see them. The goal for every server was the same: only SSH reachable, with keys only.

## Findings

| Server | Scan | Found | Expected | Action | After |
|---|---|---|---|---|---|
| rocky-10-server | `nmap -sV` | `22/tcp` | `22/tcp` | None: firewalld filters the rest | `22/tcp` |
| debian-13-server | `nmap -sV`, `nmap -p-` | `22/tcp`, **`111/tcp` (rpcbind)** | `22/tcp` | `rpcbind` disabled and masked | `22/tcp` |
| windows-server-2025-core | `nmap -Pn -sV` | `22/tcp`, **`5985/tcp` (WinRM over HTTP)** | `22/tcp` | WinRM disabled, its firewall rules off | `22/tcp` |

### Debian: rpcbind

`rpcbind` came with `nfs-common`, installed to test the TrueNAS NFS share, and listened
on every interface. NFSv4 does not need it, so it was turned off:

```bash
sudo systemctl disable --now rpcbind.socket rpcbind.service
sudo systemctl mask rpcbind.socket rpcbind.service
```

After a reboot Debian still mounted the TrueNAS share (`vers=4.2`), and `nmap -p-` from
Kali showed only `22/tcp`. A snapshot, `before-rpcbind-fix`, was taken first.

### Windows Server: WinRM

Windows Server enables WinRM out of the box, with firewall rules for every profile. This
server is managed over SSH, so it was disabled:

```powershell
Disable-PSRemoting -Force
Stop-Service WinRM -Force
Set-Service WinRM -StartupType Disabled
Disable-NetFirewallRule -DisplayGroup 'Windows Remote Management'
```

After a reboot the service was still `Disabled`, and a scan from Kali found `22/tcp`
open and `135`, `445`, `3389`, `5985` and `5986` filtered. The same commands are now part
of the install script, and a fresh install confirmed they work.

## Also checked

- **No password logins over SSH.** With public keys disabled on the client, Debian, Rocky and
  Kali answer `Permission denied (publickey...)`: they do not even offer a password method.
  ESXi and Windows were tried with their real passwords (Windows by both `password` and
  `keyboard-interactive`) and refused them.
- **`lab` has no way out.** From the `lab` interfaces of Debian, Kali and Windows, `1.1.1.1`
  does not answer; from Debian's, the home router does not either.
- **Storage is only on `lab`.** TrueNAS's NFS service is bound to `10.10.10.13` and the share
  is limited to `10.10.10.0/24`; mounting through its `nat` address fails.

## Reproduce

Start the targets and Kali, then from the host:

```text
$ ssh johan@10.10.8.14 'nmap -Pn -n -sV --top-ports 1000 10.10.10.11 10.10.10.12 10.10.10.16'
Nmap scan report for 10.10.10.11
Host is up (0.00015s latency).
Not shown: 999 closed tcp ports (reset)
PORT   STATE SERVICE VERSION
22/tcp open  ssh     OpenSSH 10.0p2 Debian 7+deb13u4 (protocol 2.0)
MAC Address: 00:0C:29:3B:62:13 (VMware)
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel

Nmap scan report for 10.10.10.12
Host is up (0.00035s latency).
Not shown: 988 filtered tcp ports (no-response), 11 filtered tcp ports (admin-prohibited)
PORT   STATE SERVICE VERSION
22/tcp open  ssh     OpenSSH 9.9 (protocol 2.0)
MAC Address: 00:0C:29:F9:A8:56 (VMware)

Nmap scan report for 10.10.10.16
Host is up (0.00025s latency).
Not shown: 999 filtered tcp ports (no-response)
PORT   STATE SERVICE VERSION
22/tcp open  ssh     OpenSSH for_Windows_9.5 (protocol 2.0)
MAC Address: 00:50:56:10:10:16 (VMware)

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 3 IP addresses (3 hosts up) scanned in 6.30 seconds
```
