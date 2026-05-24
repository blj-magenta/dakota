# Dakota — Agent Instructions

> This file tells AI coding agents (GitHub Copilot, Claude, Gemini, etc.) how to
> contribute safely and test PRs in this repository. Human contributors can
> follow the same steps.

Dakota is a [BuildStream 2](https://buildstream.build/) project that produces
**Bluefin** — a bootc OCI desktop image built entirely from source using
freedesktop-sdk and gnome-build-meta as upstream foundations. No RPMs. No dnf.
BST elements only.

---

## Requirements

| Tool | Why | Install |
|---|---|---|
| `podman` (rootful + rootless) | BST runs inside a container; export + boot need rootful | Pre-installed on Bluefin ✓ |
| `just` | All build and test commands | Pre-installed on Bluefin ✓ |
| `qemu` | VM boot | `brew install qemu` |
| `virtiofsd` | Required for `just boot-fast` only | `rpm-ostree install virtiofsd` then reboot |
| `bcvk` | Fast ephemeral VM from container (no disk image) | Auto-installed by `just boot-fast` via cargo — or install manually: `cargo install --locked --git https://github.com/bootc-dev/bcvk bcvk` |
| ~100 GB free disk | BST cache + image | — |
| ~16 GB RAM | BST builds are parallel and hungry | — |

---

## Repo layout

| Path | Purpose |
|---|---|
| `elements/freedesktop-sdk.bst` | fdsdk junction — pinned to a release tag |
| `elements/gnome-build-meta.bst` | GBM junction — tracks `gnome-50` branch |
| `elements/bluefin/` | Bluefin-specific elements (~40 elements) |
| `elements/oci/` | OCI image assembly — layers + final image |
| `patches/freedesktop-sdk/` | Patches applied to fdsdk via `patch_queue` |
| `patches/gnome-build-meta/` | Patches applied to GBM via `patch_queue` |
| `patches/linux/` | Kernel patches (via fdsdk linux element) |
| `files/` | Static files installed by elements |
| `.github/workflows/build.yml` | CI: `validate` on PRs, full `build` on merge queue |
| `Justfile` | All local dev commands — run `just --list` first |

---

## Quick start — build and boot in one command

```bash
just show-me-the-future
```

This runs the full loop: BST build → export → bootable disk image → QEMU VM.
Expect 45–90 minutes on first run (cold BST cache). Subsequent runs are fast
because BST caches artifacts by content hash.

---

## Standard dev loop

### 1. Validate — fast, no build

Always run this first. It checks the full element dependency graph without
building anything. Same check CI runs on every PR.

```bash
BST_FLAGS="-o x86_64_v3 true --no-interactive" just bst show --deps all oci/bluefin.bst
```

Exits non-zero if any element has a missing dep, bad ref, or patch that fails
to apply. If this passes, the graph is structurally sound.

### 2. Build

```bash
export BUILD_SKIP_NVIDIA=1    # skip nvidia variant — saves ~15 min
export BUILD_SKIP_CHUNKIFY=1  # skip layer reorg — faster local iteration

just build default
```

BST pulls cached artifacts from upstream caches (`cache.freedesktop-sdk.io`,
`gbm.gnome.org`) for anything it hasn't built locally. Most elements will be
cache hits. A warm-cache build of a small element change takes 2–5 minutes.

### 3. Lint

```bash
just lint
```

Runs `bootc container lint` on the built image. Must pass before any PR is ready.

### 4. Boot and verify

**Fast path — ephemeral VM, no disk image (preferred for quick checks):**

```bash
just boot-fast
```

Boots directly from the container via virtiofs. No install step. Requires
`bcvk`, `qemu-kvm`, and `virtiofsd`.

**Full path — installed disk image:**

```bash
just generate-bootable-image   # installs image to bootable.raw (~5 min)
just boot-vm                   # boots in QEMU (native) or container fallback
```

### 5. Verify what's running inside the VM

Once booted, open a terminal and check:

```bash
uname -r                       # kernel version
bootc status                   # booted image + digest
systemctl is-active gdm        # desktop session healthy
```

---

## PR review checklist

### Any PR

- [ ] Validate passes: `BST_FLAGS="-o x86_64_v3 true --no-interactive" just bst show --deps all oci/bluefin.bst`
- [ ] `just lint` passes on a built image
- [ ] `just boot-fast` or `just boot-vm` — desktop comes up, no regressions
- [ ] Commit has exactly one `Assisted-by:` or `Signed-off-by:` trailer — no `Co-authored-by:`
- [ ] PR body references the issue it closes (`Closes #NNN`)

### Junction bumps (`gnome-build-meta.bst` or `freedesktop-sdk.bst`)

- [ ] Only junction `.bst` files changed — no `patches/` modifications in the same commit
- [ ] CI `validate` passes
- [ ] Validate that existing patches in `patches/freedesktop-sdk/` and `patches/gnome-build-meta/` still apply cleanly after the bump (a patch that targeted an old `ref:` will now fail)

Junction-only bumps from `mergeraptor[bot]` that touch no patch files are
pre-approved once `validate` passes. See issue #501 for the auto-merge roadmap.

### Patch additions or removals (`patches/`)

- [ ] Patch has a clear `Upstream-Status:` line: `Submitted` / `Accepted` / `Pending` / `Not-applicable`
- [ ] If backporting a fix: upstream commit or PR linked in the patch header
- [ ] If the fix is already upstream in the new junction ref: **drop the patch** rather than keep it
- [ ] Patch filename is numbered sequentially (patches apply alphabetically)
- [ ] Patch adds an exit condition comment: "Drop when fdsdk ships X" or "Drop after GBM gnome-50 reaches Y"

### Element changes (`elements/bluefin/`)

- [ ] `ln -sf` commands are preceded by `mkdir -p` for the target directory
- [ ] `kind: manual` binary elements have a `ref:` pinned to a specific tag or commit — not a branch
- [ ] No `date`, `hostname`, `whoami`, `curl`, or other non-reproducible / network calls in `install-commands`
- [ ] New systemd units are enabled via the BST install commands, not via a post-install script

---

## Label protocol

### Triage labels

| Label | What it means |
|---|---|
| `needs-human/agent-ready` | Issue is scoped with clear acceptance criteria. Ready for an agent or contributor to pick up and open a PR. |
| `lgtm` | PR approved by a maintainer. |
| `help wanted` | Good for any contributor, including agents. |
| `kind:bug` | Something is broken and needs fixing. |
| `kind:improvement` | Enhancement or cleanup — no spec required for small items. |
| `kind:tech-debt` | Cleanup with no user-visible change. |
| `kind:github-action` | CI or automation changes. |
| `oops` | An agent made a mistake here — wrong assumption, bad output, filed a spurious issue, broke something. This label builds a learning corpus. |

### `needs-human/agent-ready` — how to use it

When you see this label on an issue:
1. Read the full issue — the acceptance criteria are there
2. Run `just --list` to understand the build system
3. Make the change, validate, build, boot, lint
4. Open a PR with `Closes #NNN` in the body
5. CI `validate` must pass

### `oops` — how to use it

When an agent makes an error:
- A maintainer adds `oops` to the relevant issue or PR
- Do **not** remove this label — it is intentional signal
- If you are the agent that made the error, note what went wrong in your response to the maintainer (so the pattern can be captured in agent skill files)
- Examples: filed a duplicate issue, proposed a fix for something already upstream, broke a patch apply, failed to check the NUC after a build

---

## Patch management rules

Patches in `patches/freedesktop-sdk/` and `patches/gnome-build-meta/` are
applied in **alphabetical filename order** via BuildStream's `patch_queue`
source. The numbers in filenames control application order.

**When bumping a junction ref:**
1. Check every existing patch in the relevant `patches/` directory
2. If a patch targets a `ref:` that no longer exists in the new junction — the patch will fail to apply. Either update the patch to match the new context or drop it if the fix is upstream.
3. Kernel patches (`patches/linux/`) are applied to the kernel source by fdsdk's linux element — verify they still apply against the new kernel version

**Patch lifecycle:**
```
Add patch → document Upstream-Status → track upstream PR →
upstream merges → junction bump includes fix → drop patch
```

Never carry a patch longer than needed. Every patch is maintenance debt.

---

## CI overview

| Job | Fires on | What it does |
|---|---|---|
| `validate` | `pull_request` | `bst show` — checks element graph, applies patches, validates deps. Fast (~5 min). |
| `build` | `merge_group`, `schedule`, `workflow_dispatch` | Full OCI build + push artifact to remote CAS. Slow (~60–90 min). |
| `build-aarch64` | disabled | ARM64 build — disabled pending investigation (issue #276) |

The daily cron fires at **13:00 UTC** — after gnome-build-meta nightly (~08:00 UTC).

**Never** bypass the merge queue with `--admin`. The queue's `build` job is the
gate. If `validate` passes on a PR but `build` fails in the queue, that failure
is real and must be fixed.

---

## What NOT to do

| Don't | Why |
|---|---|
| `rpm-ostree`, `pip install`, `apt-get` in element commands | This is a BST-only build. All deps come from junctions. |
| `$(date)`, `$(hostname)`, `$(curl ...)` in `install-commands` | Breaks BST's content-addressed caching and reproducibility |
| Patch junction files directly | Use the `patch_queue` source in the junction `.bst` element |
| Force-push to `main` | The merge queue owns merges |
| Close issues via API or comment | Use `Closes #NNN` in the PR body — the issue closes automatically on merge |
| Open a PR without running `validate` first | Saves everyone time |

---

## Useful BST commands

```bash
# Check if your element changes are sound before building
BST_FLAGS="-o x86_64_v3 true --no-interactive" just bst show --deps all oci/bluefin.bst

# Build just one element (faster iteration)
BST_FLAGS="-o x86_64_v3 true --no-interactive" just bst build elements/bluefin/tailscale.bst

# Open a shell inside the build sandbox for an element
BST_FLAGS="-o x86_64_v3 true --no-interactive" just bst shell --build elements/bluefin/tailscale.bst

# Check what depends on an element (reverse deps)
just reverse-deps elements/bluefin/tailscale.bst
```

---

## Links

- BuildStream docs: https://docs.buildstream.build/
- freedesktop-sdk: https://gitlab.com/freedesktop-sdk/freedesktop-sdk
- gnome-build-meta (GitHub mirror): https://github.com/GNOME/gnome-build-meta — branch `gnome-50`
- Existing issues: https://github.com/projectbluefin/dakota/issues
- Project board: https://github.com/orgs/projectbluefin/projects/2
