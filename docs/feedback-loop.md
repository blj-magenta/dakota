# Dakota Feedback Loop Architecture

Dakota's primary design goal is a **built-in quality feedback loop** where every
layer of the system — users, contributors, agents, maintainers, and hardware —
produces structured evidence that flows back into the next iteration.

This is not telemetry. Dakota never phones home. Every piece of data is donated
by a human who reviews it first and owns it afterward.

---

## Principle

> The intelligence of a from-source OS lives not in any single build, but in
> the infrastructure of feedback loops that surround it. Users are the sensor
> network. Contributors are the actuators. The issue tracker is the bus.

---

## The Three Evidence Sources

```
┌─────────────────────────────────────────────────────────────────┐
│                     DAKOTA FEEDBACK LOOP                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────┐    ┌──────────────┐    ┌───────────────────────┐ │
│  │  USERS   │    │ CONTRIBUTORS │    │     GHOST LAB         │ │
│  │          │    │              │    │                       │ │
│  │ ujust    │    │ just build   │    │ ghost build           │ │
│  │ report   │───▶│ just boot-   │───▶│ zot publish           │ │
│  │ confirm  │    │      test    │    │ exo-dakota bootc      │ │
│  │ verify   │◀───│ just lint    │◀───│      switch           │ │
│  │          │    │              │    │ PASS/FAIL report      │ │
│  └──────────┘    └──────────────┘    └───────────────────────┘ │
│       │                │                       │                │
│       ▼                ▼                       ▼                │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              ISSUE TRACKER (the bus)                     │   │
│  │                                                         │   │
│  │  Bug filed → discussed → approved → claimed →           │   │
│  │  PR opened → CI validates → lab:pass → merged →         │   │
│  │  nightly ships → community verifies → closed            │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Evidence by Role

### Users (running Dakota on real hardware)

| Verb | When | Evidence produced |
|------|------|-------------------|
| `ujust report` | Hit a bug | System state → gist → issue |
| `ujust confirm <issue>` | Same bug, different hardware | Hardware fingerprint → issue comment |
| `ujust verify <issue>` | Fix shipped, testing | Attestation + system context → gist + issue comment |

Users are the ground truth. They have the hardware the lab doesn't. Their
reports tell us what works and what doesn't across the real fleet.

### Contributors (building from source)

| Command | When | Evidence produced |
|---------|------|-------------------|
| `just validate` | Before any PR | Element graph is sound |
| `just build default` | After changes | Image builds successfully |
| `just boot-test` | After build | Desktop boots, GDM starts (exit 0/1) |
| `just lint` | Before PR | bootc container lint passes |
| `just boot-fast` | Deep debugging | Interactive SSH into ephemeral VM |

Contributors can verify fixes on their own machines before merge. For
hardware-specific bugs, contributors with the affected hardware build the
PR branch and test directly.

### Ghost Lab (automated hardware-in-the-loop)

| Step | What happens | Evidence produced |
|------|-------------|-------------------|
| ghost build | Full BST build on dedicated hardware | Build success/failure |
| zot publish | Image pushed to local OCI registry | Image available for testing |
| exo-dakota bootc switch | NUC boots into new image | Real hardware boot |
| Verification | `uname -r` + `bootc status` + GDM active | PASS/FAIL report on PR |

The ghost lab produces the `lab:pass` label that gates merge. It is the
maintainer's hardware proxy — confirming that the image boots and the desktop
works on physical iron, not just in QEMU.

---

## How Evidence Flows Through the Lifecycle

```
Stage              User evidence          Contributor evidence     Lab evidence
─────              ──────────────         ────────────────────     ────────────
Bug filed          ujust report gist      —                        —
Discussion         ujust confirm (me too) —                        —
Fix in PR          —                      just validate/build/test CI validate
Lab gate           —                      —                        lab:pass
Merged             —                      —                        —
Nightly ships      —                      —                        —
Verification       ujust verify           —                        —
Closed             3x verified-fixed      —                        —
```

Each stage has a structured way to produce evidence. No stage requires blind
trust — there is always a command to run and a result to share.

---

## Design Rules

1. **Every bot comment includes the next command.** When actionadon moves an
   issue forward, it tells the relevant role exactly what to type next.

2. **Evidence is always user-owned.** Gists belong to the user. Lab reports
   belong to the maintainer. Nothing is aggregated into a central database.

3. **The Justfile is the single source of truth.** Every verification step is a
   `just` or `ujust` command. No loose shell. No "run this incantation."

4. **Three tiers of verification confidence:**

   | Tier | Who | How | Confidence |
   |------|-----|-----|-----------|
   | 1 | User | Reboot into nightly + `ujust verify` | Good |
   | 2 | Contributor | `just build` + `just boot-fast` | Better |
   | 3 | Lab | Ghost build + exo-dakota hardware boot | Best |

   Most issues need Tier 1. Hardware bugs need Tier 2 or 3.

5. **The lab supplements, never replaces, community feedback.** The ghost lab
   has one machine. Users have hundreds of different hardware combinations.
   Both signals matter.

6. **No telemetry. No metrics. No phone-home.** Dakota's feedback loop is
   human-initiated, human-reviewed, and human-owned. The user decides what
   to share, when to share it, and can delete it anytime.

---

## What This Enables

- **Upstream bugs get closed with confidence.** When kernel 6.18.5 ships and 3
  users with affected hardware run `ujust verify` and attest "fixed," the
  maintainer closes with evidence, not hope.

- **Contributors can verify on affected hardware before merge.** A Framework
  laptop owner can build the PR branch, boot it, confirm the logout bug is
  fixed, and post structured evidence — all from their couch.

- **The lab catches what users can't.** Build regressions, boot failures, and
  service crashes are caught by ghost + exo-dakota before they ever reach
  users.

- **Agents produce the same evidence as humans.** An agent claiming an issue
  runs the same `just validate → build → boot-test → lint` pipeline. The
  evidence is identical in structure to what a human contributor produces.

---

## Related

- [AGENTS.md](../AGENTS.md) — Full contributor workflow and PR checklist
- [Justfile](../Justfile) — All commands (`just --list`)
- Issues: #535 (verify epic), #536 (report friction), #537 (verify-steps), #538 (probes)
