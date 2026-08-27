@AGENTS.md

# Usalingo Claude Code instructions

- `.agents/skills/` is the shared source of truth for project skills.
  `.claude/skills/` contains links to those same skill directories; do not make
  a second independent copy.
- Identify this client as `claude` in Taskspace coordination. Use
  `claude/usl-<number>-<short-name>` for a new ticket branch and
  `claude-<unique-session-value>` for `worker_id`.
- Invoke the shared ticket workflow with `/usalingo-next-ticket`. A skill is an
  instruction set, not a connection: confirm that the required Notion, GitHub,
  Supabase, and local development tools are available before relying on them.
