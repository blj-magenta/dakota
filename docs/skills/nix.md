---
name: nix
description: Dakota's Nix package manager integration. Read when modifying elements/bluefin/nix.bst, bumping the Nix version, or debugging the /nix → var/nix symlink or the dakota-nix-firstboot oneshot.
---

# Nix on Dakota

Dakota ships the upstream multi-user Nix release as a BST element. The
store is not extracted at image build time — the tarball is staged
verbatim under `/usr/share/dakota-nix/nix.tar.xz` and expanded into
`/var/nix` on first boot by a oneshot systemd service. `/nix` is a
symlink to `var/nix`, so the hardcoded `/nix/store/<hash>-nix-<ver>/...`
paths baked into the upstream binaries resolve once the store is in
place.

## Files

| Path | What it does |
|---|---|
| `elements/bluefin/nix.bst` | Fetches the upstream tarball, ships sysusers/profile/preset, defines `dakota-nix-firstboot.service` and `nix-daemon.{service,socket}` |
| `elements/oci/layers/bluefin-stack.bst` | Adds `/nix → var/nix` relative symlink alongside `/home`, `/opt`, etc. |
| `elements/bluefin/deps.bst` | Includes `bluefin/nix.bst` in the image manifest |
| `include/aliases.yml` | Defines `nix_releases:` alias pointing at `https://releases.nixos.org/nix/` |

## Why a firstboot oneshot and not factory-var

A `/usr/share/factory/var/nix/store/...` factory mechanism would also
work, but it bakes ~600 MB of unpacked store into the OCI image and
makes the artifact size hostile. Shipping the compressed `.tar.xz`
(~25 MB) and unpacking it on the device is the brew-tarball.bst
pattern and the user-preferred approach here.

The firstboot service is idempotent via the `/var/nix/.dakota-nix-initialized`
sentinel. It also runs `nix-store --load-db < /nix/.reginfo` to populate
the SQLite store database, which is required for Nix to consider any of
the staged store paths valid.

## Updating the Nix version

1. List upstream releases:
   ```
   curl -fsSL 'https://nix-releases.s3.amazonaws.com/?delimiter=/&prefix=nix/' \
     | grep -oE '<Prefix>nix/nix-[^<]*' | sort -V | tail
   ```
2. For each arch (x86_64, aarch64) grab the SHA256:
   ```
   curl -fsSL https://releases.nixos.org/nix/nix-<VER>/nix-<VER>-x86_64-linux.tar.xz.sha256
   curl -fsSL https://releases.nixos.org/nix/nix-<VER>/nix-<VER>-aarch64-linux.tar.xz.sha256
   ```
3. Update `nix-version`, both source URLs, and both `ref:` values in
   `elements/bluefin/nix.bst`.
4. `just validate` and a full image build before opening the PR.

The firstboot script does not encode the Nix store hash — it discovers
the `*-nix-<version>` directory via `find`. Version bumps that don't
add new install steps should not need script changes.

## Why nix-daemon.{service,socket} aren't pulled from the staged store

Upstream ships systemd units inside `store/<hash>-nix-<version>/lib/systemd/system/`,
but those paths only resolve after the firstboot service materializes
`/var/nix`. systemd reads units at boot from `/usr/lib/systemd/system`,
so we ship our own copies there. They reference
`/nix/var/nix/profiles/default/bin/nix-daemon`, a stable path set up by
the firstboot oneshot via `nix-env -p .../profiles/default -i .../store/<hash>-nix-<ver>`.

## Ordering and conditions

```
sysusers.d/dakota-nix.conf  (creates nixbld group + nixbld1..32 users)
        │
        ▼
dakota-nix-firstboot.service  (oneshot; ConditionPathExists=!sentinel)
        │
        ▼
nix-daemon.socket  (Requires=dakota-nix-firstboot.service)
        │
        ▼
nix-daemon.service  (socket-activated)
```

`nix-daemon.socket` carries `ConditionPathIsReadWrite=/nix/var/nix/daemon-socket`,
which the firstboot service creates with the rest of the per-store layout.

## Common mistakes

| Mistake | Fix |
|---|---|
| Removing `/nix → var/nix` from `bluefin-stack.bst` | Hardcoded store paths inside Nix binaries will dangle |
| Setting `nix-version` but not refreshing the SHA256 refs | `kind: remote` will fetch the new file then fail hash check |
| Adding a new install-command after `%{install-extra}` | `%{install-extra}` must remain the final command in the list |
| Trying to extract the tarball in the BST sandbox | The sandbox has no `/nix` — hardcoded paths in the staged binaries won't resolve until runtime |

## Lessons Learned

### Don't extract the Nix store at BST build time (2026-06-13)

The Nix binaries inside the upstream tarball contain hardcoded
`/nix/store/<hash>-...` paths. The BST sandbox cannot meaningfully run
`nix-store --load-db` because `/nix` does not exist in the sandbox.
Stage the tarball verbatim and run extraction + DB load in a oneshot
systemd service on the device, where `/nix → var/nix` is in place.

### `/nix → var/nix` symlink belongs in bluefin-stack.bst (2026-06-13)

`/var/nix` is per-deployment writable; `/nix` is the path Nix expects.
Adding the symlink in `elements/oci/layers/bluefin-stack.bst`'s
`integration-commands` block — next to the existing `/home → var/home`,
`/opt → var/opt`, etc. — keeps the FHS-via-/var convention consistent
and survives `bootc switch`/deploy cycles.
