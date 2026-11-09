# TSH-05 — TrueNAS kept undoing its new IP addresses

## Symptom

[`configure.py`](../vms/truenas-25.10-storage/configure.py) set static addresses on
both TrueNAS NICs through the REST API. Each time, the new addresses worked for about
a minute and a half, and then TrueNAS went back to its DHCP address.

## Cause

TrueNAS protects you from locking yourself out: `interface/commit` applies network
changes with a rollback timer, and unless `interface/checkin` is called from the new
address before the timer ends (90 seconds here), it restores the old configuration.

The first two runs sent the check-in as a POST, and the API answered **405 Method Not
Allowed**. In the REST API, `interface/checkin` is a **GET**, so the check-in never
counted and the timer ran out both times.

A second, smaller one: `system/reboot` returns 400 unless the request body includes a
`reason`.

## Fix

```python
api("POST", "interface/commit", {"rollback": True, "checkin_timeout": 90}, timeout=10)
# ...then, against the new address:
api("GET", "interface/checkin", at=NAT_IP, timeout=5)    # GET, not POST
```

## Result

The third run kept both addresses. They, the pool and the NFS service were all still
there after a reboot.

## Lesson

A safety net that undoes your change looks exactly like a change that failed. Read the
status code of every call in the sequence: the 405 on the check-in was the whole story.
