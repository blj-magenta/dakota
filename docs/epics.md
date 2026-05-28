# Dakota Epics

Epics group related issues into single shippable goals. Each epic has a clear definition of done and fewer than ten child issues. When all children are closed, the epic closes.

**Boards:**
- [Dakota Epics](https://github.com/orgs/projectbluefin/projects/5) — one row per epic, status at a glance
- [Dakota Flow](https://github.com/orgs/projectbluefin/projects/4) — every issue left-to-right from New to Shipped, filterable by epic

---

## How this works

**Humans decide. Bots build.**

A maintainer owns each epic: they write the acceptance criteria, decide which issues belong, and close the epic when the goal is met. Contributors and agents pick up individual child issues from the Ready column in Dakota Flow.

The epics exist so that:
1. Every issue has a clear parent goal — it is obvious why the work matters
2. Progress is visible at a glance — you can see whether an area is moving or stuck
3. Small contributors know exactly where to start — pick any Ready issue in an epic you care about

**Epic lifecycle:**

```
Defining  →  Active  →  [Blocked]  →  Complete
```

- **Defining** — Acceptance criteria being written. Child issues exist but are not yet Ready.
- **Active** — At least one child is in flight. New children can still be added.
- **Blocked** — The whole epic is waiting on a dependency or decision. See the epic issue for context.
- **Complete** — All children shipped. Epic closed.

---

## Current epics

### P0 — Critical

#### Alpha Stability (#493)
**Goal:** Dakota boots reliably, installs cleanly, and does not surprise users with hardware-specific failures during the alpha period.

**Children:**
- #531 bootc status fails after image rename
- #464 VM fails to boot after bootc upgrade
- #415 Black screen after install on AMD HP ZBook
- #450 First-use issues and install friction
- #367 Increase boot time delay during alpha
- #301 Login keyring not unlocked after reboot
- #275 bootc switch fails on LUKS systems
- #466 Duplicate graphics device in System Details (nvidia)

**Definition of done:** No open P1 or P0 bugs in this list. Dakota can be installed on a fresh machine, booted, and used for a day without hitting any of these issues.

---

#### Testing Infrastructure (#548)
**Goal:** The ghost lab runs fully automatically. `just boot-test` passes in CI without human intervention. `ujust devmode` reliably switches to the developer image.

**Children:**
- #524 Testlab automation should not require manual runner bring-up (P0)
- #527 Ghost lab BST gate fails resolving gnome-build-meta junction
- #180 ujust devmode can't find image (P1)

**Definition of done:** `just boot-test` passes end-to-end in the ghost lab without a human starting the queue runner. `ujust devmode` switches image successfully on a clean system.

**Note:** This epic unblocks Community Verification (#535) — a working lab is a prerequisite for meaningful verify data.

---

#### Community Verification (#535)
**Goal:** Users who hit a bug can confirm a fix works on their hardware with `ujust verify`. Maintainers can publish verify-steps when a fix ships. The feedback loop closes without email threads.

**Children:**
- #536 ujust report: reduce friction for diagnostic donation (P1)
- #537 Add maintainer verify-steps protocol for community testing (P1)
- #538 ujust report: add area-specific diagnostic probes (P1)

**Definition of done:** `ujust verify <issue>` runs the relevant probes, reports pass/fail, and offers to upload results. At least one shipped fix has verify-steps attached and confirmed by a community member.

---

### P1 — High

#### Build System (#547)
**Goal:** BST builds are reproducible across runs and months. Junction bumps merge without human review. CI is fast and not duplicated.

**Children:**
- #504 Build: date +%m breaks reproducibility (P0 — fix first)
- #503 CI: deduplicate bst2 pin check into composite actions
- #501 CI: auto-merge junction bumps from mergeraptor
- #505 Patches: drop pipewire backports once fdsdk ships >= 1.6.1
- #231 chunkah: upstream fakecap-xattr for BuildStream xattr support
- #403 Contribute signing stack to GNOME OS
- #404 Document Dakota as reference architecture for GNOMEOS and bootc
- #55 Implement testing branch setup

**Definition of done:** Monthly cache invalidation (#504) is fixed. Junction bumps from mergeraptor auto-merge when validate passes. CI validate job runs in under 5 minutes.

---

#### Justfile / Dev Workflow (#510)
**Goal:** Every local developer workflow is covered by a `just` recipe. No undocumented workarounds. `just --list` shows a clean, grouped set of commands.

**Children:**
- #514 Justfile: add group annotation to chunkify recipe (XS)
- #511 Justfile: document or default x86_64_v3 flag in bst wrapper (XS)
- #513 Justfile: add push-local recipe for lab zot registry (XS)
- #512 Justfile: export should skip chunkify for local builds (S)

**Definition of done:** All four issues closed. `just --list` shows every recipe in a named group. A new contributor can run the full dev loop (build → export → push to lab → boot-test) using only `just` commands.

---

#### Feature Parity (#546)
**Goal:** Dakota works as a daily driver. Users coming from Fedora or Bluefin do not encounter basic feature gaps.

**Children:**
- #430 Parity: Podman Desktop kubectl setup failure
- #399 Parity: VMM flatpak missing kernel/library bits
- #362 Parity: no way to persistently add kernel parameters
- #353 Parity: user account dinosaur icons are missing
- #237 Cannot automount second hard drive
- #333 Feature: Zen Mode for focused work
- #207 Docker on Dakota via brew

**Definition of done:** All P1 parity items closed. Dakota can be used as a primary workstation for a week without needing a workaround for any item in this list.

---

## Adding an issue to an epic

1. File or find the issue
2. Add a checklist line to the epic's issue body: `- [ ] #NNN short description`
3. Set the **Epic** field on the Dakota Flow board to match
4. A maintainer will add acceptance criteria and move it to Approved when it is ready for a contributor to claim

## Adding a new epic

Epics are opened by maintainers when a cluster of related issues needs a shared goal. Before opening a new epic:

1. Check that at least three related issues already exist
2. Write a one-paragraph goal and a concrete definition of done
3. Keep the child list to ten issues or fewer — split into two epics if it grows beyond that
4. Set Priority and Status on the Epics board

Ping a maintainer in the issue if you think a new epic is warranted.
