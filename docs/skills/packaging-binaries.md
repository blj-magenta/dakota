---
name: packaging-binaries
description: Packages a project using official pre-built static binaries (GitHub Releases). Use when upstream provides release binaries and building from source is unnecessary. Covers arch-conditional sources, kind:remote with filename, and strip-binaries placement.
---

# Packaging Pre-Built Binaries

Load when packaging a project that provides official pre-built static binaries (GitHub Releases, official downloads), or when building from source is impractical.

## When to Use Pre-Built Binaries

| Situation | Pre-built? |
|---|---|
| Official static binary available from upstream | ✅ Yes |
| Upstream has no build system we can use in BST | ✅ Yes |
| Bootstrap compiler needed (e.g., Zig for Zig builds) | ✅ Yes |
| Source available and build system is standard | ❌ Build from source instead |

## Element Template

```yaml
kind: manual
description: <Package name>

build-depends:
- freedesktop-sdk.bst:bootstrap-import.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  version: '1.2.3'
  strip-binaries: ""   # required — pre-built binaries are already stripped

sources:
- kind: tar
  url: alias:releases/owner/project/v%{version}/project-linux-amd64.tar.gz
  ref: sha256hex...

install-commands:
- install -Dm755 project "%{install-root}%{bindir}/project"
- '%{install-extra}'
```

## Architecture Dispatch

For projects with architecture-specific binaries:

```yaml
variables:
  version: '1.2.3'
  (?):
  - arch == "x86_64":
      arch-tag: "amd64"
  - arch == "aarch64":
      arch-tag: "arm64"

sources:
- kind: tar
  url: alias:releases/owner/project/v%{version}/project-linux-%{arch-tag}.tar.gz
  ref: sha256hex...
```

## Source Kinds for Binaries

| Source kind | Use when |
|---|---|
| `tar` | Binary is inside a `.tar.gz`/`.tar.xz` archive |
| `remote` | Single file download (not extracted) |

For `remote` sources, use `directory:` to control placement in the staging dir:
```yaml
sources:
- kind: remote
  url: alias:releases/owner/project/v%{version}/project-linux-amd64
  ref: sha256hex...
  directory: bin
```

## Adding URL Aliases

Binary download domains need an alias in `include/aliases.yml`:

```yaml
aliases:
  github: 'https://github.com/'
  releases: 'https://github.com/'    # for /releases/ paths
  objects-gh: 'https://objects.githubusercontent.com/'
```

Use the alias in the element URL:
```yaml
url: releases:owner/project/releases/download/v%{version}/binary.tar.gz
```

## Checklist

- [ ] `strip-binaries: ""` set (non-ELF content won't strip cleanly)
- [ ] `ref:` is a pinned SHA256 hash (for tarballs) or commit SHA (for git sources)
- [ ] URL alias added to `include/aliases.yml` if domain is new
- [ ] Element added to `elements/bluefin/deps.bst`
- [ ] `just bst show bluefin/<name>.bst` passes
- [ ] `just bst build bluefin/<name>.bst` passes

## Lessons Learned

### `strip-binaries: ""` belongs under `variables:`, not `public: bst:` (2026-06-07)

Real elements (`tailscale.bst`, `glow.bst`, `gum.bst`, `fzf.bst`, `tealdeer.bst`) all declare
`strip-binaries: ""` under `variables:`. `public: bst:` is for `overlap-whitelist` entries only.
Placing `strip-binaries` under `public: bst:` causes a YAML error at element parse time.

```yaml
# ✅ correct
variables:
  strip-binaries: ""

# ❌ wrong — YAML parse error
public:
  bst:
    strip-binaries: ""
```

### `base-dir: ""` required when tarball has no wrapping directory (2026-06-07)

Some projects (e.g., `fzf`) release tarballs where the binary sits at the archive root with no
wrapping directory. Without `base-dir: ""`, BST expects a top-level directory and fails. Example
from `fzf.bst`:

```yaml
sources:
- kind: tar
  base-dir: ""
  url: github_files:junegunn/fzf/releases/download/v0.73.1/fzf-0.73.1-linux_amd64.tar.gz
  ref: f3252c2c366bc1700d3c85781ec8c9695998927ac127870eb049ceea2d540f8a
```

### Multiple `kind: remote` sources for binary + completions (2026-06-07)

When an upstream release provides separate files for the binary and shell completions, use one
`kind: remote` source per file. Give each a `filename:` to rename it on extraction. Example from
`tealdeer.bst`:

```yaml
sources:
  - kind: remote
    filename: tealdeer          # renames the download
    url: github_files:tealdeer-rs/tealdeer/releases/download/v1.8.1/tealdeer-linux-x86_64-musl
    ref: sha256hex...
  - kind: remote
    filename: completions_bash
    url: github_files:tealdeer-rs/tealdeer/releases/download/v1.8.1/completions_bash
    ref: sha256hex...
```

The `filename:` field is required when the URL path has no recognizable extension or conflicts
with another source file in the same staging directory.

### Arch-conditional sources use `(?)` inside the source block, not at top level (2026-06-07)

Architecture-specific download URLs live inside the `(?):` conditional directly within the
`sources:` list item. The `kind:` is outside the conditional:

```yaml
sources:
- kind: tar
  (?):
  - arch == "x86_64":
      url: alias:project_1.0_amd64.tgz
      ref: sha256hex...
  - arch == "aarch64":
      url: alias:project_1.0_arm64.tgz
      ref: sha256hex...
```

This pattern is used in `tailscale.bst`, `glow.bst`, `gum.bst`, and `fzf.bst`.
