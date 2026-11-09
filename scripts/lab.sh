#!/bin/bash
# Power profiles for the lab: start, stop or snapshot a group of VMs with vmrun.
# The host has 32 GB of RAM, so only one profile runs at a time.
#
# Usage: lab.sh list
#        lab.sh status
#        lab.sh start <profile>
#        lab.sh stop <profile>
#        lab.sh snapshot <profile> <name>
#
# VMs are expected in $VM_DIR/<name>/<name>.vmx (default ~/vmware).
set -euo pipefail

VM_DIR=${VM_DIR:-$HOME/vmware}

# Order matters: VMs start left to right and stop right to left
# (TrueNAS before ESXi, so the NFS datastore is there when ESXi boots).
declare -A PROFILES=(
    [network]="eve-ng-ce-6.2"
    [vsphere]="truenas-25.10-storage esxi-8-host"
    [servers]="debian-13-server rocky-10-server windows-server-2025-core"
    [security]="debian-13-server rocky-10-server windows-server-2025-core kali-linux"
)
declare -A RAM_GB=(
    [network]=16 [vsphere]=16 [servers]=8 [security]=12
)

usage() { sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 1; }

vmx() { echo "$VM_DIR/$1/$1.vmx"; }

# vmrun without its AppLoader/libaio notices. On failure its message goes to stderr
# and its exit status is passed on, so the script stops there.
vmrun_q() {
    local out rc=0
    out=$(vmrun "$@" 2>&1) || rc=$?
    out=$(grep -vE 'AppLoader|libaio' <<<"$out" || true)
    if ((rc)); then echo "${out:-vmrun $1 failed (exit $rc)}" >&2; return "$rc"; fi
    if [[ -n "$out" ]]; then echo "$out"; fi
}

running() { vmrun list 2>/dev/null | grep -F -- "$(vmx "$1")" >/dev/null; }

profile_vms() {
    [[ -n "$1" ]] || usage
    [[ -n "${PROFILES[$1]:-}" ]] || { echo "unknown profile '$1' (try: lab.sh list)" >&2; exit 1; }
    echo "${PROFILES[$1]}"
}

case "${1:-}" in
    list)
        for p in network vsphere servers security; do
            printf '%-9s %3s GB  %s\n' "$p" "${RAM_GB[$p]}" "${PROFILES[$p]}"
        done
        ;;
    status)
        for dir in "$VM_DIR"/*/; do
            name=$(basename "$dir")
            [[ -f "$(vmx "$name")" ]] || continue
            if running "$name"; then state=running; else state=off; fi
            printf '%-26s %s\n' "$name" "$state"
        done
        ;;
    start)
        list=$(profile_vms "${2:-}")
        read -ra vms <<<"$list"
        log=$(mktemp)
        trap 'rm -f "$log"' EXIT
        for vm in "${vms[@]}"; do
            if running "$vm"; then echo "$vm: already running"; continue; fi
            echo "$vm: starting"
            # Output to a file, not a pipe, so the script never waits on the running VM
            if ! vmrun start "$(vmx "$vm")" nogui >"$log" 2>&1 </dev/null; then
                grep -vE 'AppLoader|libaio' "$log" >&2 || true
                exit 1
            fi
        done
        ;;
    stop)
        list=$(profile_vms "${2:-}")
        read -ra vms <<<"$list"
        for ((i = ${#vms[@]} - 1; i >= 0; i--)); do
            vm=${vms[i]}
            if ! running "$vm"; then echo "$vm: already off"; continue; fi
            echo "$vm: shutting down"
            vmrun_q stop "$(vmx "$vm")" soft    # asks the guest OS to shut down cleanly
        done
        ;;
    snapshot)
        list=$(profile_vms "${2:-}")
        [[ -n "${3:-}" ]] || usage
        read -ra vms <<<"$list"
        for vm in "${vms[@]}"; do
            echo "$vm: snapshot $3"
            vmrun_q snapshot "$(vmx "$vm")" "$3"
        done
        ;;
    *)
        usage
        ;;
esac
