#!/bin/bash
# Builds an unattended Debian 13 install ISO for debian-13-server from the official netinst ISO.
# Usage: build-iso.sh <netinst.iso> <output.iso> <password-hash-file> <ssh-public-key>
set -euo pipefail
[ $# -eq 4 ] || { sed -n 's/^# Usage: /usage: /p' "$0" >&2; exit 1; }

SRC_ISO=$1
OUT_ISO=$2
HASH_FILE=$3
PUBKEY=$4
HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# Preseed with the user's password hash filled in
HASH=$(tr -d '\n' < "$HASH_FILE")
sed "s|@@USER_PASSWORD_HASH@@|${HASH}|" "$HERE/preseed.cfg" > "$WORK/preseed.cfg"
grep -q '@@' "$WORK/preseed.cfg" && { echo "placeholder left in preseed" >&2; exit 1; }

cp "$PUBKEY" "$WORK/authorized_keys"

# UEFI boot menu: one entry that starts the automated install after 3 seconds
cat > "$WORK/grub.cfg" <<'EOF'
set timeout=3
set default=0
insmod all_video
menuentry "Automated install (debian-13-server)" {
    linux /install.amd/vmlinuz auto=true priority=critical preseed/file=/cdrom/preseed.cfg locale=en_US.UTF-8 keymap=us hostname=debian-13-server domain=lab.internal --- quiet
    initrd /install.amd/initrd.gz
}
EOF

rm -f "$OUT_ISO"
xorriso -indev "$SRC_ISO" -outdev "$OUT_ISO" \
    -map "$WORK/preseed.cfg" /preseed.cfg \
    -map "$WORK/authorized_keys" /authorized_keys \
    -map "$WORK/grub.cfg" /boot/grub/grub.cfg \
    -boot_image any replay

echo "Built $OUT_ISO"
