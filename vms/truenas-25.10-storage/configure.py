#!/usr/bin/env python3
"""Configures a fresh TrueNAS 25.10 install for the VMware lab through its REST API.

- ZFS pool "tank": the two data disks in a mirror
- dataset tank/vmstore, shared over NFS only to the lab network (10.10.10.0/24)
- static IPs: ens160 10.10.8.13 (nat: web UI, updates), ens192 10.10.10.13 (lab: storage)

Usage: configure.py <current-ip> <password-file>
The admin user is truenas_admin. Uses only the Python standard library.
"""
import base64
import http.client
import json
import ssl
import sys
import time
import urllib.request

NAT_IP, LAB_IP, GATEWAY = "10.10.8.13", "10.10.10.13", "10.10.8.2"
CTX = ssl._create_unverified_context()  # the web UI starts with a self-signed certificate

if len(sys.argv) != 3:
    sys.exit("usage: configure.py <current-ip> <password-file>")
host = sys.argv[1]
with open(sys.argv[2], encoding="utf-8") as f:
    password = f.readline().strip()
AUTH = "Basic " + base64.b64encode(f"truenas_admin:{password}".encode()).decode()


def api(method, path, body=None, at=None, timeout=60):
    url = f"https://{at or host}/api/v2.0/{path}"
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(url, data=data, method=method,
                                 headers={"Authorization": AUTH, "Content-Type": "application/json"})
    with urllib.request.urlopen(req, context=CTX, timeout=timeout) as r:
        raw = r.read()
    return json.loads(raw) if raw else None


def wait_job(job_id):
    while True:
        job = api("GET", f"core/get_jobs?id={job_id}")[0]
        if job["state"] in ("SUCCESS", "FAILED", "ABORTED"):
            if job["state"] != "SUCCESS":
                sys.exit(f"job {job_id} {job['state']}: {job.get('error')}")
            return job["result"]
        time.sleep(2)


# 1. Pool: every disk that is not the boot disk goes into one mirror
boot = set(api("GET", "boot/get_disks"))
data_disks = sorted(d["name"] for d in api("GET", "disk") if d["name"] not in boot)
if not any(p["name"] == "tank" for p in api("GET", "pool")):
    print("creating pool tank, mirror of", data_disks)
    wait_job(api("POST", "pool", {"name": "tank",
                                  "topology": {"data": [{"type": "MIRROR", "disks": data_disks}]}}))

# 2. Dataset and NFS share, limited to the lab network; root is not squashed (ESXi needs that)
if not api("GET", "pool/dataset?id=tank/vmstore"):
    api("POST", "pool/dataset", {"name": "tank/vmstore", "share_type": "GENERIC",
                                 "comments": "Shared VM storage for the lab"})
if not api("GET", "sharing/nfs?path=/mnt/tank/vmstore"):
    api("POST", "sharing/nfs", {"path": "/mnt/tank/vmstore", "networks": ["10.10.10.0/24"],
                                "maproot_user": "root", "maproot_group": "root",
                                "comment": "VM datastore (lab network only)"})
nfs = api("GET", "service?service=nfs")[0]
api("PUT", f"service/id/{nfs['id']}", {"enable": True})

# 3. Static IPs, applied with TrueNAS's commit + check-in (it rolls back if the check-in never arrives)
api("PUT", "interface/id/ens160", {"ipv4_dhcp": False, "ipv6_auto": False,
                                   "aliases": [{"type": "INET", "address": NAT_IP, "netmask": 24}]})
api("PUT", "interface/id/ens192", {"ipv4_dhcp": False, "ipv6_auto": False,
                                   "aliases": [{"type": "INET", "address": LAB_IP, "netmask": 24}]})
try:
    api("POST", "interface/commit", {"rollback": True, "checkin_timeout": 90}, timeout=10)
except (OSError, http.client.HTTPException) as e:  # the old address may drop mid-switch
    print("commit:", e)
for _ in range(30):
    try:
        api("GET", "interface/checkin", at=NAT_IP, timeout=5)  # GET in the REST API, not POST
        break
    except (OSError, http.client.HTTPException):  # not up at the new address yet
        time.sleep(3)
else:
    sys.exit("could not check in at the new address; TrueNAS will roll back")
host = NAT_IP

api("PUT", "network/configuration", {"hostname": "truenas-storage", "domain": "lab.internal",
                                     "ipv4gateway": GATEWAY, "nameserver1": GATEWAY})
api("PUT", "nfs", {"bindip": [LAB_IP]})
api("POST", "service/start", {"service": "nfs"})

print("done:", [(i["name"], [a["address"] for a in i["state"]["aliases"] if a["type"] == "INET"])
                for i in api("GET", "interface")])
print("nfs running:", api("GET", "service?service=nfs")[0]["state"])
