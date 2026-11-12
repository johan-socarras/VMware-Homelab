# Troubleshooting

One write-up per real problem met while building the lab. Each has the same parts:
symptom, cause, fix, result and the lesson.

| | Symptom | Cause | Lesson |
|---|---|---|---|
| [TSH-01](01-kali-network-profile.md) | Kali's first boot had no internet | The installer bound its network profile to no interface, so the address landed on the wrong NIC | A clean install is not a working network: check which interface got which address |
| [TSH-02](02-esxi-ssh-fips-keys.md) | ESXi rejected my SSH key and still accepted passwords | ESXi's SSH server runs in FIPS mode without Ed25519, and the setting used to turn passwords off was ignored | Read the installer's own log before assuming a setting was applied |
| [TSH-03](03-nested-esxi-vmkernel-mac.md) | Nested ESXi could not reach the NFS server | Workstation only delivers frames addressed to the virtual NIC's own MAC, and the new VMkernel port had a generated one | In nested virtualization, the outer hypervisor's switch is part of the network path |
| [TSH-04](04-windows-guest-type-32-bit-efi.md) | The Windows Server VM would not boot any ISO | The guest type gave the VM a 32-bit UEFI firmware | When every boot medium fails the same way, suspect the machine |
| [TSH-05](05-truenas-network-rollback.md) | TrueNAS kept undoing its new IP addresses | The check-in that confirms a network change was sent with the wrong HTTP method, so the rollback timer ran out | A safety net that undoes your change looks exactly like a change that failed |
