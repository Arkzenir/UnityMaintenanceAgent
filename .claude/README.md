# Claude Code wiring

Claude Code is the one tool here with a full wiring directory.

| File | Purpose |
|---|---|
| `../CLAUDE.md` | The fixed filename Claude reads. It imports `AGENTS.md`. |
| `settings.json` | Permissions and the plan-mode default. No hooks: the checks are CLI scripts (`AGENTS.md` §11), so this file stays OS-neutral. |
| `skills/<name>/SKILL.md` | One-line pointers into `../skills/`. They exist only because Claude discovers skills under `.claude/skills`; the content lives in `skills/`. |
| `settings.local.json` | Per-machine permissions, gitignored. Not wiring. |

Add nothing else here: rules belong in `AGENTS.md`, skills in `skills/`.
