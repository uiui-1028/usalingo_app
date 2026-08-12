# Usalingo Codex instructions

## Required rulebook

Before substantial repository exploration, project planning, or using Notion,
web search, GitHub, or another external connector, read:

- `docs/rules/codex-credit-optimization.md`

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
