#!/bin/bash
# Post-install configuration of esxi-8-host, run from the Workstation host over SSH (root, key login).
# Mounts the TrueNAS NFS share as a datastore over the lab network (vmk1).
# Kept out of the kickstart because truenas-25.10-storage doesn't have to be running during the install.
# Usage: configure.sh [esxi-address]   (default 10.10.1.15)
set -euo pipefail

ESXI=${1:-10.10.1.15}
NFS_HOST=10.10.10.13
NFS_SHARE=/mnt/tank/vmstore
DATASTORE=truenas-vmstore

# Unquoted heredoc on purpose: the values above are filled in here, before the script
# is sent to ESXi.
# shellcheck disable=SC2087
ssh -o BatchMode=yes "root@$ESXI" sh -s <<EOF
set -e
vmkping -I vmk1 -c 2 $NFS_HOST >/dev/null || { echo "$NFS_HOST not reachable on vmk1: is truenas-25.10-storage running?" >&2; exit 1; }
if esxcli storage nfs41 list | grep -q "^$DATASTORE "; then
    echo "Datastore $DATASTORE already mounted"
else
    esxcli storage nfs41 add -H $NFS_HOST -s $NFS_SHARE -v $DATASTORE
    echo "Datastore $DATASTORE mounted (NFS 4.1)"
fi
esxcli storage nfs41 list
EOF
