# TSH-01 — Kali's first boot had no internet

## Symptom

[kali-linux](../vms/kali-linux/README.md) installed from the preseed without errors,
but after the first boot it could not reach the internet. `ip -br a` showed the `nat`
address, `10.10.8.14`, on `eth1`, the NIC connected to the isolated `lab` network,
and nothing on `eth0`.

## Cause

The installer had written a single NetworkManager profile, `Wired connection 1`,
meant for `eth0`. It tried to bind the profile to the NIC by MAC address, but wrote
the key as `mac=`. NetworkManager only knows `mac-address=` and silently ignores
unknown keys, so the profile was bound to no interface and NetworkManager applied it to
`eth1`. The same installer step also replaced the
`/etc/network/interfaces` stanza the preseed had added for `eth1`.

## Fix

On the running VM, through the VNC console and then over SSH:

```bash
nmcli con mod "Wired connection 1" connection.interface-name eth0
# then the two profiles below, and:
nmcli con delete "Wired connection 1"
nmcli con reload && nmcli con up nat && nmcli con up lab
```

For future installs:

- The preseed tells the installer not to copy its network setup to the new system:
  `d-i netcfg/target_network_config select loopback` (an option of Kali's `netcfg`
  that was confirmed in its template).
- [`finish.sh`](../vms/kali-linux/finish.sh) writes two keyfiles, `nat` and `lab`,
  each bound with `interface-name=`, so a profile can never land on the wrong NIC.
  `lab` has `never-default=true`.

## Result

After a reboot: `eth0 10.10.8.14/24` with internet, `eth1 10.10.10.14/24` without a
default route, profiles `nat` and `lab`. A fresh install from the fixed ISO, into a
throwaway VM, gave the same result on its first boot with no manual step.

## Lesson

A successful install does not mean the network is right: check which interface got
which address before anything else. And bind NetworkManager profiles by interface
name when the names are stable, which they are here because the NICs sit in fixed
PCI slots.
