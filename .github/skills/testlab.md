# Testlab Patterns — Lessons Learned

> Patterns from the ghost → exo-dakota hardware validation loop.
> Read before running or scripting lab builds.

---

## bootc switch same-content trap

`bootc switch <tag>` silently does nothing if the tag resolves to the
already-booted digest. Always force the upgrade with the exact digest:

```bash
DIGEST=$(curl -sI http://<zot-registry>/v2/dakota/manifests/<TAG> \
  -H 'Accept: application/vnd.oci.image.manifest.v1+json' \
  | grep -i docker-content-digest | awk '{print $2}' | tr -d '\r')
sudo bootc switch --transport registry <zot-registry>/dakota@${DIGEST}
```

---

## Assertions must execute — not just check file presence

`test -f /path/to/file` is not a functional test. Any recipe that runs in a
terminal must also be tested via SSH assertions that **execute it** and check
output:

```bash
# ❌ BAD — only confirms the file exists
--assert 'installed:test -f /usr/share/ublue-os/just/default.just'

# ✅ GOOD — confirms the recipe actually runs
--assert 'recipe-runs:echo n | TERM=dumb ujust report 2>&1 | grep -qiE "Collecting"'
```

Do not mark PASS until the recipe has executed on hardware and produced
expected output.

---

## BUILD_SKIP_NVIDIA

Skip the nvidia variant for local builds to cut build time from ~20 min to
~3 min:

```bash
export BUILD_SKIP_NVIDIA=1
just build default
```

CI still builds both variants. Same pattern as `BUILD_SKIP_CHUNKIFY`.

---

## BST failure cache trap

When BST caches a failed build, retrying without clearing the cache will
immediately fail again with `[00:00:00]` elapsed — the dead giveaway.

```bash
# Clear the cached failure and retry
just bst artifact delete elements/bluefin/myelement.bst
just bst build elements/bluefin/myelement.bst
```

---

## Pre-existing failures vs your changes

Before attributing a build failure to your branch, confirm the same element
fails on `upstream/main`:

```bash
git stash
git checkout upstream/main
just bst build elements/bluefin/<failing-element>.bst
git checkout -
git stash pop
```

If it fails on upstream too, file an issue immediately and continue. Do not
block your PR on a pre-existing failure.
