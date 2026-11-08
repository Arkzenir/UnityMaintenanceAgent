# Wiring an agent

The harness has one contract, one skill set, and one set of checks. An agent's
wiring is only what its tool needs in order to load them — never a second copy.

## The rules

1. **Shared by default.** A tool that reads `AGENTS.md` and can run a shell
   command needs no wiring. Codex, Cursor, Copilot, DSH and most CLIs are in
   this group.
2. **A root shim only for a fixed filename.** Claude Code looks for `CLAUDE.md`
   and Gemini CLI for `GEMINI.md`. Those files exist for that reason and contain
   a pointer to `AGENTS.md`, not rules.
3. **A tool directory only for that tool's own configuration and wiring notes.**
   Claude's `.claude/settings.json` and `.claude/skills` are there because Claude
   reads those paths. The directory holds no copy of the contract or the skills.
4. **Anything else gets `agents/<id>/`.** If a tool needs something that is
   neither a fixed root filename nor an existing tool directory, create
   `agents/<id>/README.md`, describe it, and add it to the table. That directory
   is the only place its files live.

## Shared pieces

| Piece | Where |
|---|---|
| Contract | `AGENTS.md` |
| Skills | `skills/` |
| Checks | `scripts/harness.ps1`, `scripts/harness.sh` |
| Templates, project memory | `templates/`, `projects/` |

## Current wirings

| Agent | Entry point | Directory | Notes |
|---|---|---|---|
| Claude Code | `CLAUDE.md` → `AGENTS.md` | `.claude/` | Settings, plan mode, skill pointers. See `.claude/README.md`. |
| Gemini CLI | `GEMINI.md` → `AGENTS.md` | — | Shim only. |
| Codex CLI | `AGENTS.md` | — | Native. |
| Cursor | `AGENTS.md` | — | Native. |
| GitHub Copilot | `AGENTS.md` | — | Native. |
| DSH / anything else | `AGENTS.md` | — | Native. |

## Adding an agent

1. Copy `agents/_template/` to `agents/<id>/` and fill in its README. The
   `_template` directory is the skeleton, not an agent.
2. If the tool requires a fixed root filename, add a shim that points at
   `AGENTS.md` and nothing else.
3. If the tool needs configuration, put it in the tool's own directory
   (`.cursor/`, …) or, when the tool has no convention, under `agents/<id>/`.
4. Add the row to the table here and to the table in `README.md`.
5. Run `check-repo`: none of this may appear in the game repo.

## Do not

- Copy `AGENTS.md` or `skills/` into a second location.
- Add a root file for a tool that already reads `AGENTS.md`.
- Put rules or skills under `agents/<id>/`; point at the shared paths.
