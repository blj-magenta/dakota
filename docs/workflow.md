# Community workflow

## Issue flow

`filed → approved → queued → claimed → done`

| Stage | Meaning |
|---|---|
| `filed` | Issue opened and `needs-triage` applied |
| `approved` | `status/approved` |
| `queued` | `queue/agent-ready` |
| `claimed` | `queue/claimed` |
| `done` | Issue closed |

## Actionadon bot

| Comment | Who can use it | Effect |
|---|---|---|
| `/claim` | anyone | Adds `queue/claimed`, assigns the commenter |
| `/unclaim` | assignee or write+ | Removes `queue/claimed`, unassigns |
| `/ready` | write+ | Adds `queue/agent-ready` once `status/approved` and acceptance criteria are present |
| `/approve` or `/lgtm` | write+ | Adds `lgtm` |

**`kind:agent-donation` issues:** write the report as a comment, cite sources, close the issue. Do not open a PR.

## Hive

Copy `files/hive/hive-project.yaml.example` to `/etc/hive/hive-project.yaml` and load `files/hive/agent-policies/` as per-agent CLAUDE.md overrides.

## Labels

| Label | Meaning |
|---|---|
| `needs-triage` | Needs human review — set kind, priority, and area |
| `status/discussing` | Not ready for the agent queue |
| `status/approved` | Approved for the build queue — add acceptance criteria then `/ready` |
| `queue/agent-ready` | Has a spec, ready to claim — comment `/claim` |
| `queue/claimed` | In active work — comment `/unclaim` to return |
| `agent/blocked` | Blocked — needs human input before work can continue |
| `hold` | Do not touch |
| `do-not-merge` | Do not merge or automate |
| `lgtm` | Maintainer approved — ready to merge |
| `lab:pass` | Lab validation passed; enables label-gated auto-merge |
| `kind:bug` / `kind:improvement` / `kind:tech-debt` / `kind:github-action` | Change type |
| `kind:agent-donation` | Investigation request — report comment, not code |
| `flow/project-report` / `flow/issue-review` / `flow/pr-review` | Hive scanner flow routing |
| `needs-human/agent-oops` | Agent error — do not touch; humans only |

**Hive exempt** (do not touch): `hold`, `do-not-merge`, `status/discussing`, `status/approved`, `queue/claimed`, `agent/blocked`, `needs-human/agent-oops`, `duplicate`, `wontfix`, `stale`

## Links

- [BuildStream docs](https://docs.buildstream.build/)
- [freedesktop-sdk](https://gitlab.com/freedesktop-sdk/freedesktop-sdk)
- [gnome-build-meta](https://github.com/GNOME/gnome-build-meta) — branch `gnome-50`
- [Dakota issues](https://github.com/projectbluefin/dakota/issues)
- [Dakota board](https://github.com/orgs/projectbluefin/projects/3)
- [All Bluefin projects](https://github.com/orgs/projectbluefin/projects/2)
