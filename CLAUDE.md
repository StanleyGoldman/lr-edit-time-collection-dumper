# lr-edit-time-collection-dumper

## Pull requests

Every change reaches `main` through a PR (a GitHub ruleset protects it). Your work ends at the hand-off: open the PR, report it, and leave the merge to the reviewer.

## Lua

Writing or reviewing Lua: read docs/coding-standards.md

## Writing for agents

Writing anything an agent reads (this file, `docs/agents/`, skills, memory): load the `mattpocock-skills:writing-for-agents` skill first.

## Agent skills

### Issue tracker

Issues are tracked in GitHub Issues (StanleyGoldman/lr-edit-time-collection-dumper) via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Default vocabulary: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `CONTEXT.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.
