# CI reference

## Jobs

| Job | Triggers | What |
|---|---|---|
| `validate` | `pull_request` | `bst show` — graph + patch check (~5 min) |
| `e2e` | `pull_request` (path-filtered) | Smoke test in QEMU via projectbluefin/testsuite |
| `build` | `merge_group`, `schedule`, `workflow_dispatch` | Full OCI build (~60–90 min) |
| `build-aarch64` | disabled | ARM64 — pending investigation |

## Publish pipeline (publish.yml)

`build` success on main triggers publish.yml via `workflow_run`:

```
setup → publish (matrix) → e2e-gate → promote
```

| Job | What |
|---|---|
| `setup` | Resolves SHA and trigger event |
| `publish` | Exports from CAS, pushes `:$sha`, signs, SBOM, attests |
| `e2e-gate` | Smoke-tests `ghcr.io/projectbluefin/dakota:$sha` — schedule/dispatch only |
| `promote` | Re-tags `:$sha` → `:latest` after e2e passes — schedule/dispatch only |

`:latest` is never published without a passing e2e smoke test.

## Schedule

**13:00 UTC** daily — runs after GBM nightly (~08:00 UTC finish).

## Remote cache

`cache.projectbluefin.io:11002` — mTLS via `CASD_CLIENT_CERT` + `CASD_CLIENT_KEY`.

## Published images

`ghcr.io/projectbluefin/dakota:latest` and `ghcr.io/projectbluefin/dakota:<sha>`

Build triggers: `merge_group`, `schedule`, `workflow_dispatch` — **not** `pull_request`.

Never bypass the merge queue with `--admin`.

## e2e path filter

e2e only fires when these paths change:

```
elements/**  files/**  patches/**  Justfile  project.conf
```

PRs touching only `.github/workflows/` (action pins, bst2 bumps) skip e2e — the check is marked skipped, which satisfies the required status check. Junction bumps in `elements/` always run e2e.
