# Project: <NAME>

> Stable facts about the project and the toolchain. Update when a fact changes,
> not every session. Anything time-sensitive belongs in CURRENT_STATUS.md.

## Location

- **Repo path:** `<absolute path>`
- **Slug:** `<slug>`
- **VCS:** git / none  · default branch: `<branch>`
- **Bootstrapped:** <YYYY-MM-DD>

## Engine

| | |
|---|---|
| Unity version | <from ProjectSettings/ProjectVersion.txt> |
| Editor binary | `<absolute path, for batch mode>` |
| Render pipeline | Built-in / URP <ver> / HDRP <ver> |
| Input | Input System <ver> / legacy / both |
| Scripting backend | Mono / IL2CPP |
| API compatibility | .NET Standard 2.1 / .NET Framework |
| Target platforms | |
| Enter Play Mode Options | domain reload on/off, scene reload on/off |

## Key packages

| Package | Version | Notes |
|---|---|---|
| | | |

## Assemblies

<list from Library/ScriptAssemblies + asmdef graph, or "no asmdefs — all in Assembly-CSharp">

## Verification

> No experimental Unity packages — `com.unity.pipeline` is declined project-wide,
> so there is no live-Editor route. Do not re-propose it.

- **Per-change tier:** 2 (`dotnet build`) / 3 (scratch Roslyn) / 4 (static only)
- **Authoritative tier:** 1 (batch mode) — available when the Editor is closed
- **Determined:** <YYYY-MM-DD>
- **Unity binary:** `<absolute path, version-matched>`
- **Solution file:** `<Name>.sln` — present / absent
- **Working commands:**
  - `dotnet build <Name>.sln -v quiet -nologo`
  - `"<unity bin>" -batchmode -nographics -quit -projectPath "<repo>" -logFile "<harness>/logs/compile.log"`
- **Known blind spots:** new files absent from generated csproj until Unity
  regenerates; solution stale after asmdef/package changes

## Standing decisions

> Answers the user has given once that shouldn't be asked again. Date each one.

- 2026-08-08 — experimental Unity packages (incl. `com.unity.pipeline`): **declined**
- 2026-08-08 — runtime verification: **user does it by hand**; no automated tests
- <YYYY-MM-DD> — temp editor scripts: allowed at `<path>` / not wanted
- <YYYY-MM-DD> — agent may run editor actions itself: yes after review / never

## Third-party / vendor code

<folders under Assets/ that are not the user's own code and should not be modified>
