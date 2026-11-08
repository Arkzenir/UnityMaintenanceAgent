# Code style

**The project's style wins, always, in every case.** Style mismatch is the most
visible sign of foreign code, and the user is reviewing by eye. A functionally
perfect change in the wrong style will be rejected on sight, and rightly.

## What to determine during bootstrap

Record the answers in `CONVENTIONS.md` with a file reference as evidence.

| Question | Common variants |
|---|---|
| Private field naming | `_camelCase`, `m_CamelCase`, `camelCase` |
| Serialized field exposure | `[SerializeField] private` / `public` / `[field: SerializeField]` |
| Namespaces | full hierarchy / one root / none at all |
| Braces | Allman (newline) vs K&R (same line) |
| `var` | always / only when type is obvious / never |
| Access modifiers | explicit `private` / omitted |
| Property style | expression-bodied / full / auto |
| Interfaces | `IThing` prefix (near-universal) |
| Regions | used / avoided |
| File header comments | present / absent |
| Comment density and voice | terse and rare / explanatory |
| Async naming | `DoThingAsync` suffix / none |
| `using` placement | inside or outside namespace |
| Nullable reference types | enabled per-file / project-wide / off |
| One type per file | strict / nested helpers allowed |
| Editor script location | `Editor/` folders / separate assembly |
| `#if UNITY_EDITOR` usage | how widely |

Check for tooling that already encodes the answers — `.editorconfig`,
`.idea/`, `Directory.Build.props`, `*.DotSettings`, a `.clang-format`-style
config, or a `stylecop.json`. If one exists, it is authoritative and you should
say so rather than inferring from code.

## Defaults, only when the project is genuinely silent

Fall back to Microsoft C# conventions with Unity adaptations:

- `PascalCase` types, methods, properties, events, constants
- `camelCase` locals and parameters
- `_camelCase` private fields
- `IPascalCase` interfaces
- Allman braces (Unity's own script templates use this)
- Explicit access modifiers
- One public type per file, filename matches the type — **required** for
  MonoBehaviours and ScriptableObjects, or Unity cannot attach them

## Comments

Write comments a human engineer on this project would write. That means:

- Explain *why*, not *what*. `// clamped because the animator blend tree
  breaks above 1` is useful; `// clamp the value` is noise.
- Match the project's density. If the project has almost no comments, adding
  heavy commenting to your file makes it stand out as foreign.
- XML doc comments on public API only if the project already does this.
- **Never** write meta-commentary: no `// AI generated`, no `// TODO: verify
  this`, no `// changed per request`, no `// NEW`, no explanation of the change
  process. The changelog in the harness is where that belongs.
- Never leave commented-out old code "for reference". The user has git.

## Formatting in Rider

If the project has a `.editorconfig` or `.DotSettings`, Rider will reformat on
the user's next edit anyway — so matching it matters for the review diff being
readable. Prefer matching over hoping the formatter fixes it.
