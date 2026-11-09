#!/bin/bash
# Builds the answer ISO for windows-server-2025-core: autounattend.xml, setup.ps1, the SSH key and VMware Tools.
# It goes in the VM's second CD drive; Microsoft's ISO stays untouched in the first one.
# Usage: build-iso.sh <output.iso> <secret-file> <ssh-public-key>
#   <secret-file> has a "password: ..." line with the Administrator password.
set -euo pipefail
[ $# -eq 3 ] || { sed -n 's/^# Usage: /usage: /p' "$0" >&2; exit 1; }

OUT_ISO=$1
SECRET=$2
PUBKEY=$3
TOOLS_ISO=/usr/lib/vmware/isoimages/windows.iso   # ships with VMware Workstation
# Image name inside sources/install.wim of the evaluation ISO (26100.32230): index 1 of
# SERVERSTANDARDCORE, SERVERSTANDARD, SERVERDATACENTERCORE, SERVERDATACENTER. CORE = no desktop.
EDITION='Windows Server 2025 SERVERSTANDARDCORE'
HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

PASSWORD=$(sed -n 's/^password: //p' "$SECRET")
[[ "$PASSWORD" =~ ^[A-Za-z0-9]{12,}$ ]] || { echo "password missing or not alphanumeric" >&2; exit 1; }
mkdir "$WORK/cd"
sed -e "s|@@ADMIN_PASSWORD@@|${PASSWORD}|g" -e "s|@@IMAGE_NAME@@|${EDITION}|" "$HERE/autounattend.xml" > "$WORK/cd/autounattend.xml"
grep -q '@@' "$WORK/cd/autounattend.xml" && { echo "placeholder left in autounattend.xml" >&2; exit 1; }
cp "$HERE/setup.ps1" "$WORK/cd/"
cp "$PUBKEY" "$WORK/cd/authorized_keys"
xorriso -osirrox on -indev "$TOOLS_ISO" -extract / "$WORK/cd/vmware-tools" 2>/dev/null
chmod -R u+w "$WORK/cd"

rm -f "$OUT_ISO"
xorriso -as mkisofs -quiet -J -joliet-long -R -V ANSWERS -o "$OUT_ISO" "$WORK/cd"
echo "Built $OUT_ISO"
