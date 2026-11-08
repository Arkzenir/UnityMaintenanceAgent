# `<Agent>` wiring

- Tool / version:
- Entry point: `<file the tool loads automatically, or AGENTS.md>`
- Tool directory: `<path, or "none">`
- Extra setup: `<permissions, hooks, launch flags — or "none">`

## Why this shape

[What the tool requires. If it reads `AGENTS.md`, say so and stop: extra files
are justified only by a fixed filename or a tool-owned config path.]

## Checklist

- [ ] The agent reads `AGENTS.md`; nothing is duplicated.
- [ ] Skills are referenced from `skills/`, not copied.
- [ ] Any directory is listed here and in `agents/README.md`.
- [ ] `check-repo` passes.
