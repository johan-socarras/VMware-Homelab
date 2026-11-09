#!/bin/bash
# Builds an unattended ESXi 8.0 U3e install ISO for esxi-8-host from the official installer ISO.
# Usage: build-iso.sh <VMware-VMvisor-Installer.iso> <output.iso> <root-password-hash-file> <ssh-public-key>
# The SSH key must be ECDSA or RSA: ESXi's sshd runs in FIPS 140 mode and rejects Ed25519 keys.
set -euo pipefail
[ $# -eq 4 ] || { sed -n 's/^# Usage: /usage: /p' "$0" >&2; exit 1; }

SRC_ISO=$1
OUT_ISO=$2
HASH_FILE=$3
PUBKEY=$4
HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# Kickstart with the root password hash and the SSH key filled in
HASH=$(tr -d '\n' < "$HASH_FILE")
KEY=$(tr -d '\n' < "$PUBKEY")
case "$KEY" in ecdsa-sha2-*|ssh-rsa*) ;; *) echo "SSH key must be ECDSA or RSA (FIPS mode)" >&2; exit 1 ;; esac
sed -e "s|@@ROOT_PASSWORD_HASH@@|${HASH}|" -e "s|@@SSH_PUBLIC_KEY@@|${KEY}|" "$HERE/ks.cfg" > "$WORK/KS.CFG"
grep -q '@@' "$WORK/KS.CFG" && { echo "placeholder left in ks.cfg" >&2; exit 1; }

# Boot config (same file for BIOS and UEFI): run the kickstart instead of the interactive installer
xorriso -indev "$SRC_ISO" -osirrox on -extract /BOOT.CFG "$WORK/BOOT.CFG" 2>/dev/null
chmod u+w "$WORK/BOOT.CFG"
sed -i 's|^kernelopt=.*|kernelopt=cdromBoot ks=cdrom:/KS.CFG|; s|^title=.*|title=Automated install (esxi-8-host)|' "$WORK/BOOT.CFG"

rm -f "$OUT_ISO"
xorriso -indev "$SRC_ISO" -outdev "$OUT_ISO" \
    -map "$WORK/KS.CFG" /KS.CFG \
    -map "$WORK/BOOT.CFG" /BOOT.CFG \
    -map "$WORK/BOOT.CFG" /EFI/BOOT/BOOT.CFG \
    -boot_image any replay

echo "Built $OUT_ISO"
