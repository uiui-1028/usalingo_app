# Usalingo agent instructions

## Required rulebook

Before substantial repository exploration, project planning, or using Notion,
web search, GitHub, or another external connector, read:

- `docs/README.md` — 文書の入口。どの棚に何があるか
- `docs/operations/credit-optimization.md` — 調査と出力のルール

この2つ以外の文書は、必要になったときだけ開きます。

For a simple self-contained question, the summary in this file is sufficient.
Use the smallest reliable amount of context, but never trade away correctness,
security, required testing, or the user's explicit request merely to reduce
credit usage.

## Project baseline

- Treat `apps/ios-swiftui/` as the current application unless the user explicitly
  asks about the legacy Flutter implementation.
- Preserve existing uncommitted changes as user work.
- Do not write to Notion or other external services unless the user requested the
  write. Read-only inspection does not authorize an external mutation.

## Multi-agent baseline

- Treat existing uncommitted changes as user or another agent's work. Never
  reset, stash, overwrite, or include them in an unrelated commit.
- Before editing, inspect `git status --short --branch` and
  `git worktree list --porcelain`.
- Codex, Claude Code, Cursor, and other agents must not edit the same checkout or
  worktree concurrently. Use one ticket-specific branch and, when another agent
  may be active, a separate worktree for each agent.
- For Taskspace work, acquire a unique `worker_id` and unexpired `lease_until`,
  then re-fetch the ticket and confirm ownership before creating or continuing
  changes. Re-check ownership before commit, push, PR, merge, or Notion updates.
- If another agent owns the lease, branch, worktree, or overlapping uncommitted
  files, do not take over or merge the work implicitly. Stop or choose a
  different ticket unless the documented handoff conditions are satisfied.
