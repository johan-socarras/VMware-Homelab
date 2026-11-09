#!/bin/bash
# Builds an unattended Rocky Linux 10 install ISO for rocky-10-server from the official boot ISO.
# Usage: build-iso.sh <boot.iso> <output.iso> <password-hash-file> <ssh-public-key>
set -euo pipefail
[ $# -eq 4 ] || { sed -n 's/^# Usage: /usage: /p' "$0" >&2; exit 1; }

SRC_ISO=$1
OUT_ISO=$2
HASH_FILE=$3
PUBKEY=$4
HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# The installer finds its own files and the kickstart by the ISO volume label
LABEL=$(xorriso -indev "$SRC_ISO" -pvd_info 2>/dev/null | sed -n "s/^Volume Id *: *//p")
[ -n "$LABEL" ] || { echo "could not read the ISO label" >&2; exit 1; }

# Kickstart with the password hash and SSH key filled in
HASH=$(tr -d '\n' < "$HASH_FILE")
KEY=$(tr -d '\n' < "$PUBKEY")
sed -e "s|@@USER_PASSWORD_HASH@@|${HASH}|" -e "s|@@SSH_PUBLIC_KEY@@|${KEY}|" "$HERE/ks.cfg" > "$WORK/ks.cfg"
grep -q '@@' "$WORK/ks.cfg" && { echo "placeholder left in kickstart" >&2; exit 1; }

# UEFI boot menu: one entry that starts the kickstart install after 3 seconds
cat > "$WORK/grub.cfg" <<EOF
set timeout=3
set default=0
insmod all_video
menuentry "Automated install (rocky-10-server)" {
    linuxefi /images/pxeboot/vmlinuz inst.stage2=hd:LABEL=${LABEL} inst.ks=hd:LABEL=${LABEL}:/ks.cfg inst.text quiet
    initrdefi /images/pxeboot/initrd.img
}
EOF

rm -f "$OUT_ISO"
xorriso -indev "$SRC_ISO" -outdev "$OUT_ISO" \
    -map "$WORK/ks.cfg" /ks.cfg \
    -map "$WORK/grub.cfg" /EFI/BOOT/grub.cfg \
    -boot_image any replay

echo "Built $OUT_ISO (label $LABEL)"
