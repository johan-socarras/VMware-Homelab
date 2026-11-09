# Naming

VMs are named `<system>-<version>-<role>`: lowercase, words joined by hyphens, no spaces.

| Name | System | Version | Role |
|---|---|---|---|
| `debian-13-server` | Debian | 13 | server |
| `rocky-10-server` | Rocky Linux | 10 | server |
| `truenas-25.10-storage` | TrueNAS | 25.10 | storage |
| `esxi-8-host` | ESXi | 8 | host |
| `windows-server-2025-core` | Windows Server | 2025 | Server Core |
| `eve-ng-ce-6.2` | EVE-NG Community Edition | 6.2 | (the product is its role) |
| `kali-linux` | Kali Linux | — | — |

Kali has no version in its name because it is a rolling release: a version would be
out of date within weeks.

**Why this way:**

- The name says what the VM is without opening it, and sorts related VMs together.
- It works everywhere the name ends up: the VM's folder, its `.vmx` and `.vmdk` files,
  the Workstation library, scripts and URLs. All of them use exactly the same string.
- It follows the convention of my [Proxmox homelab](https://github.com/johan-socarras/Proxmox-Homelab#services)
  (`debian-13-client`, `windows-server-2025-dc`), so both labs read the same way.

**Hostnames inside the guests** follow the VM name where the OS allows it
(`debian-13-server.lab.internal`). Two cannot: Windows, because NetBIOS names stop at 15
characters (`win2025-core`), and TrueNAS, because a hostname cannot contain the dot in
`25.10` (`truenas-storage`). `lab.internal` is used as the DNS domain because
`.internal` is reserved for private use and never resolves on the internet.

**Snapshots** have descriptive names: `baseline` is the clean state right after the
install, taken powered off; later ones are named after the change they protect
(`before-rpcbind-fix`) or the state they record (`winrm-closed`).
