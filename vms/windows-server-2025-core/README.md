# windows-server-2025-core

Windows Server with no desktop, managed remotely: Server Core, installed from an
answer file, reached over SSH with PowerShell as the shell, and with every inbound
port closed except SSH.

| | |
|---|---|
| Guest OS | Windows Server 2025 Standard Evaluation, **Server Core**, build 26100.32230; evaluation activated online right after the install (180 days) |
| Hardware | Virtual hardware 22, guest type `windows2022srvNext-64` (see below), UEFI with Secure Boot, 40 GB NVMe disk (thin) |
| CPU / RAM | 2 vCPU, 4 GB |
| Network | Fixed MACs in the `.vmx` so each NIC can be identified inside Windows:<br>`nat` (`00:50:56:10:08:16`): `10.10.8.16/24`, gateway and DNS `10.10.8.2`<br>`lab` (`00:50:56:10:10:16`): `10.10.10.16/24`, no gateway<br>IPv6 off; computer name `win2025-core` (NetBIOS names stop at 15 characters) |
| Access | OpenSSH Server (included in Windows Server 2025) with keys only, PowerShell as the default shell; the `Administrator` password is only for the console |
| Firewall | Inbound: only `22/tcp`. WinRM, on by default in Windows Server, is disabled |
| Power profile | `servers` |

## How it is built

The Microsoft ISO is used as downloaded; a second, small CD carries everything else.

1. Download the Windows Server 2025 evaluation ISO
   (`26100.32230.260111-0550.lt_release_svc_refresh_SERVER_EVAL_x64FRE_en-us.iso`,
   8.15 GB) from the Microsoft Evaluation Center. Microsoft publishes no checksum
   for it; the size was checked against the download server's.
2. Build the answer CD:
   ```bash
   ./build-iso.sh windows-server-2025-core-answers.iso /path/to/secret-file ~/.ssh/id_ed25519.pub
   ```
   [`build-iso.sh`](build-iso.sh) puts [`autounattend.xml`](autounattend.xml) (with
   the Administrator password filled in), [`setup.ps1`](setup.ps1), the public key
   and VMware Tools (from Workstation's own `windows.iso`) on an ISO labelled
   `ANSWERS`.
3. Create the VM from
   [`windows-server-2025-core.vmx.example`](windows-server-2025-core.vmx.example)
   with the Microsoft ISO on the first CD drive and the answer ISO on a second one.
   At "Press any key to boot from CD or DVD", press a key within a few seconds.
4. Windows Setup finds `autounattend.xml` on its own: it partitions the NVMe disk
   (GPT: EFI, MSR, Windows), installs the Server Core image and logs on once as
   Administrator. That logon runs `setup.ps1`, which:
   - installs VMware Tools (Windows has no driver for the vmxnet3 NIC),
   - finds each NIC by its MAC, renames it `nat` or `lab` and gives it its address,
   - enables OpenSSH Server with the key, `PasswordAuthentication no` and PowerShell
     as the shell, and opens `22/tcp`,
   - disables WinRM and its firewall rules,
   - deletes the password left on disk by the answer file and the automatic logon,
   - powers the VM off. On an error it stays on and logs to `C:\Windows\Temp\setup.log`.

   The whole install takes about 10 minutes.
5. Detach both CDs and take the `baseline` snapshot.

## What it took

- **No ISO would boot, not even ESXi's.** The guest type first used,
  `windows2025srvNext-64`, means "the Windows Server after 2025" to VMware.
  Workstation 26 does not fully know it and gave the VM a **32-bit** UEFI firmware,
  which cannot start a 64-bit boot loader. Windows Server 2025 is
  `windows2022srvNext-64`
  ([TSH-04](../../troubleshooting/04-windows-guest-type-32-bit-efi.md)).
- **The image name inside `install.wim` is `Windows Server 2025 SERVERSTANDARDCORE`**,
  not "Standard Evaluation". The ISO's files are on UDF, which `xorriso` cannot read,
  so the names were read from the WIM header of the ISO mounted read-only
  (`udisksctl loop-setup -r`).
- **WinRM listens on `5985/tcp` out of the box.** The port scan from Kali found it;
  this server is managed over SSH, so it was disabled. The change was made on the
  running VM (snapshot `winrm-closed`) and added to `setup.ps1`. A fresh install into a
  throwaway VM created from the example `.vmx` confirmed it: WinRM `Stopped` and
  `Disabled`, its firewall rules off, nothing listening on `5985`.

## Tests

- SSH with the key works; with the real password, by `password` and by
  `keyboard-interactive`, it gets `Permission denied`.
- `InstallationType` is `Server Core`; the license is activated (`LicenseStatus=1`).
- No `unattend.xml` left in `C:\Windows\Panther` and no `DefaultPassword` in Winlogon.
- From the `lab` address there is no way out (`ping -S 10.10.10.16 1.1.1.1` fails).
- From Kali on `lab`, after closing WinRM and rebooting: only `22/tcp` open; `5985`,
  `5986`, `3389`, `445` and `135` filtered.

## Verify

```bash
vmrun start ~/vmware/windows-server-2025-core/windows-server-2025-core.vmx nogui
```

```text
$ ssh Administrator@10.10.8.16 "(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').InstallationType; (Get-Service WinRM).StartType"
Server Core
Disabled
```

## Files

| File | What it is |
|---|---|
| [`autounattend.xml`](autounattend.xml) | Windows Setup answer file: language, disk layout, edition, computer name, Administrator password placeholder, one automatic logon that runs `setup.ps1` |
| [`setup.ps1`](setup.ps1) | First-logon script: VMware Tools, network, OpenSSH, WinRM off, cleanup, power off |
| [`build-iso.sh`](build-iso.sh) | Builds the answer CD |
| [`windows-server-2025-core.vmx.example`](windows-server-2025-core.vmx.example) | The VM's configuration, exported with [`scripts/export-vmx.py`](../../scripts/export-vmx.py) |

**Snapshots:** `baseline` (fresh install), `winrm-closed`.
