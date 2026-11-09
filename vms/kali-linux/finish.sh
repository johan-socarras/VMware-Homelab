#!/bin/sh
# Runs inside the installed system at the end of the kali-linux install (preseed late_command).
set -e

# Keep the eth0/eth1 names after the install, as the installer used them
if ! grep -q 'net.ifnames=0' /etc/default/grub; then
    sed -i 's/^GRUB_CMDLINE_LINUX="/&net.ifnames=0 /' /etc/default/grub
    update-grub
fi

# Network: one NetworkManager profile per NIC, each bound to its interface.
# (The installer's own profile is skipped with netcfg/target_network_config: it binds with "mac=",
# a key NetworkManager ignores, so it could land on the lab NIC.)
nm_profile() { # name interface address gateway-and-dns|""
    f=/etc/NetworkManager/system-connections/$1.nmconnection
    {
        printf '[connection]\nid=%s\ntype=ethernet\ninterface-name=%s\nautoconnect-priority=10\n\n' "$1" "$2"
        printf '[ipv4]\nmethod=manual\naddress1=%s\n' "$3"
        if [ -n "$4" ]; then
            printf 'gateway=%s\ndns=%s;\ndns-search=lab.internal;\n' "$4" "$4"
        else
            printf 'never-default=true\n'
        fi
        printf '\n[ipv6]\nmethod=disabled\n'
    } > "$f"
    chmod 600 "$f"
}
nm_profile nat eth0 10.10.8.14/24 10.10.8.2   # nat (vmnet8): updates, SSH from the host
nm_profile lab eth1 10.10.10.14/24 ""         # lab (vmnet10): isolated, no gateway

# SSH: Kali ships it disabled; enable it with key login only
install -d -m 700 -o johan -g johan /home/johan/.ssh
install -m 600 -o johan -g johan /root/authorized_keys /home/johan/.ssh/authorized_keys
printf 'PasswordAuthentication no\nKbdInteractiveAuthentication no\nPermitRootLogin no\n' > /etc/ssh/sshd_config.d/10-hardening.conf
chmod 600 /etc/ssh/sshd_config.d/10-hardening.conf
systemctl enable ssh
