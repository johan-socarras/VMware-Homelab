# Virtual machines

Seven VMs, each in its own folder with a page that says what it is, how it was built,
how it was tested and how to check it, next to the files that build it.

| VM | What it demonstrates | OS | Built with | Networks |
|---|---|---|---|---|
| [esxi-8-host](esxi-8-host/README.md) | vSphere: nested ESXi, `esxcli`, NFS datastore, a VM running inside | VMware ESXi 8.0 U3e (free) | ESXi kickstart | `mgmt` .15, `lab` .15 |
| [truenas-25.10-storage](truenas-25.10-storage/README.md) | Shared storage: ZFS mirror, NFS limited to the lab network | TrueNAS CE 25.10 | Installer answered over VNC, then the REST API | `nat` .13, `lab` .13 |
| [debian-13-server](debian-13-server/README.md) | Headless Linux server with Secure Boot and SSH keys only | Debian 13 | Preseed | `nat` .11, `lab` .11 |
| [rocky-10-server](rocky-10-server/README.md) | The Red Hat family: SELinux enforcing, firewalld | Rocky Linux 10 | Kickstart | `nat` .12, `lab` .12 |
| [windows-server-2025-core](windows-server-2025-core/README.md) | Windows Server with no desktop: PowerShell over SSH, only port 22 open | Windows Server 2025 Core (evaluation) | Answer file and a first-logon script | `nat` .16, `lab` .16 |
| [kali-linux](kali-linux/README.md) | Security auditing of the lab from inside the isolated network | Kali Linux Rolling | Preseed | `nat` .14, `lab` .14 |
| [eve-ng-ce-6.2](eve-ng-ce-6.2/README.md) | Cisco network labs | EVE-NG Community 6.2 | Imported as it was | `bridged` |

The pages share one order: a summary table, **How it is built**, **What it took** (the
problems met and what changed because of them), **Tests**, **Verify** and **Files**; a
page leaves out the sections it has nothing for. EVE-NG was imported as it was, so its
page explains why it is configured differently instead of how it was built.

Each `<vm>.vmx.example` was exported from the working VM by
[`scripts/export-vmx.py`](../scripts/export-vmx.py). The names follow
[one convention](../docs/naming.md), the networks are in [docs/network.md](../docs/network.md)
and the method behind the builds is in [docs/unattended-installs.md](../docs/unattended-installs.md).
