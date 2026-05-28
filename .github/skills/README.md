# .github/skills — In-Repo Knowledge Base

Accumulated lessons from real work on this repo. Every agent working here
should read the relevant file before starting in that area.

When you discover a new pattern or fix a recurring mistake, add it here in the
same PR as your change. This is the feedback loop: lessons land here and help
every future agent and contributor — not just you, and not just on one machine.

## Skills

| File | Load when... |
|------|-------------|
| [`ujust-recipes.md`](ujust-recipes.md) | Writing or editing `files/just-overrides/default.just` |
| [`testlab.md`](testlab.md) | Running or scripting ghost → exo-dakota lab builds |

## How to add a lesson

1. Open the relevant skill file (or create a new one)
2. Add a section: `### <pattern name> (YYYY-MM-DD)`
3. What failed → why → the fix → code example
4. Commit it in the same PR as your change

## Related

- Role policies for Hive agents: [`../files/hive/agent-policies/`](../files/hive/agent-policies/)
- Top-level agent rules: [`../../AGENTS.md`](../../AGENTS.md)
