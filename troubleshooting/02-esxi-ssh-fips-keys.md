# TSH-02 — ESXi rejected my SSH key and still accepted passwords

## Symptom

After the first kickstart install of [esxi-8-host](../vms/esxi-8-host/README.md),
SSH answered but refused the key that works on every other VM:

```text
root@10.10.1.15: Permission denied (publickey,keyboard-interactive).
```

The key was in `/etc/ssh/keys-root/authorized_keys`, which is where ESXi's
`AuthorizedKeysFile` points, and the file had the right owner and mode. Logging in
with the root password over keyboard-interactive still worked, although the
kickstart was supposed to turn password logins off.

## Cause

Two separate things:

1. **ESXi 8 runs its SSH server in FIPS 140 mode.**
   `esxcli system security fips140 ssh get` returns `Enabled: true`, and
   `/var/log/auth.log` shows `FIPS mode initialized` for every connection. In that
   mode ESXi's SSH server limits itself to the algorithms of its FIPS-validated crypto
   module, which covers ECDSA and RSA but not Ed25519, so the key was never accepted.
2. **`passwordauthentication` is not a setting ESXi lets you change.** The kickstart
   log said so plainly:
   ```text
   Ignored key [passwordauthentication] as it doesn't belong to the list of configurable properties
   ```
   `esxcli system ssh server config list` shows what can be set. ESXi checks
   passwords through PAM over keyboard-interactive, and the setting that controls it is
   `challengeresponseauthentication`.

## Fix

FIPS mode stays on, as ESXi ships it; the client side changes instead:

```bash
ssh-keygen -t ecdsa -b 256 -f ~/.ssh/id_ecdsa     # OpenSSH offers it automatically
```

In [`ks.cfg`](../vms/esxi-8-host/ks.cfg):

```bash
esxcli system ssh server config set -k challengeresponseauthentication -v no
```

[`build-iso.sh`](../vms/esxi-8-host/build-iso.sh) now refuses any key that is not
ECDSA or RSA.

## Result

Reinstalled from scratch with the new ISO: the ECDSA key logs in, and the root
password gets `Permission denied (publickey)`. Both survive a reboot.

## Lesson

Read the installer's own log before assuming a setting was applied, and look at what
a hardened default changes before turning it off: here the secure option was to change
the key type, not to disable FIPS.
