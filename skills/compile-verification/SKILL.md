---
name: compile-verification
description: Establish that Unity C# changes actually compile, using the best method available — dotnet build on the generated solution, Unity batch-mode compile, a scratch Roslyn check for new files, or a disciplined static review. Use this after every code change to the project, and during bootstrap to determine and record which verification tier the environment supports. Never report a change as done without running this and stating the result honestly.
---

# Compile verification

The user does not run unit or integration tests, and verifies runtime behaviour by
hand. Compilation is therefore the only automated signal either of you gets, which
makes it disproportionately valuable — and makes claiming a check you didn't run
disproportionately damaging.

**Standing constraint: no experimental Unity packages.** The user has declined
`com.unity.pipeline`, which is the only way the `unity` CLI can drive a running
Editor. Do not propose it again. The `unity` CLI is still useful for locating
editor installs and diagnosing the environment, but not for talking to a live
Editor.

**Determine your tier during bootstrap and record it in `PROJECT.md`.** Don't
discover it for the first time when you urgently need it.

---

## The recommended combination

In practice you want two of these, not one:

- **Tier 2 (`dotnet build`) as the per-change loop** — seconds, works with the
  Editor open, no repo changes. This is what you run after every edit.
- **Tier 1 (batch mode) as the authoritative check** — when the user has the
  Editor closed, or after any change to asmdefs, packages, or project settings,
  where the generated solution can't be trusted.

Say which one you ran, every time.

---

### Tier 1 — Unity batch-mode compile (ground truth)

Launching the Editor headless forces a real compile through Unity's own pipeline
and writes the result to a log.

```bash
"$UNITY_BIN" -batchmode -nographics -quit \
  -projectPath "$REPO" \
  -logFile "$HARNESS/logs/compile-$(date +%Y%m%d-%H%M%S).log"
echo "exit=$?"
```

```powershell
& $UnityBin -batchmode -nographics -quit `
  -projectPath $Repo `
  -logFile "$Harness\logs\compile.log"
```

Then parse:

```bash
rg -n "error CS|Compilation failed|Scripts have compiler errors" "$LOG"
```

Exit code 0 with no `error CS` lines means it compiled. A non-zero exit with no
`error CS` usually means something else went wrong (license, lock, version
mismatch) — read the log rather than reporting a compile failure.

**Locating the editor binary.** Use the `unity` CLI if it's installed:

```bash
unity --version
unity editors --format json     # installed versions and their paths
unity doctor                    # diagnoses license/config problems
```

Match the version in `ProjectSettings/ProjectVersion.txt` exactly and record the
resolved absolute path in `PROJECT.md`. Typical fallbacks:

- macOS: `/Applications/Unity/Hub/Editor/<VERSION>/Unity.app/Contents/MacOS/Unity`
- Windows: `C:\Program Files\Unity\Hub\Editor\<VERSION>\Editor\Unity.exe`
- Linux: `~/Unity/Hub/Editor/<VERSION>/Editor/Unity`

`unity --help` is the authoritative list of what the installed CLI can do; if you
need a CLI capability, check there rather than assuming a command exists.

**Constraints you must respect:**

- **The Editor must not be open on the same project.** Unity locks it; batch mode
  will fail, or two instances will fight over `Library/`. Ask the user to close it,
  or use Tier 2 instead. Never launch batch mode against a project you have reason
  to believe is open — and default to assuming it is, since the user works in it.
- Slow: tens of seconds to minutes, longer if `Library/` is cold, because it may
  reimport assets.
- Needs a valid activated license on the machine.
- **Never invoke a different Unity version than the project's.** A newer editor
  will silently upgrade and reserialize project assets. Check
  `ProjectVersion.txt` against the binary before every invocation.
- It writes to `Library/` — that's fine, `Library/` is generated and gitignored.

---

### Tier 2 — `dotnet build` on the generated solution (the working loop)

Unity, with the Rider or Visual Studio Editor package installed, generates
`.csproj` and `.sln` files at the repo root. Roslyn compiles them directly in a few
seconds, without Unity running.

```bash
cd "$REPO"
ls *.sln *.csproj
dotnet build <Solution>.sln -v quiet -nologo 2>&1 | rg "error|warning CS"
```

Fast, no repo modification, works while the user has the Editor open in front of
them. This is the default per-change check.

**Its blind spots — state the relevant ones whenever you report using it:**

- **New files may not be compiled at all.** Unity's generated `.csproj` lists
  source files explicitly. A `.cs` file you just created is *not in the csproj*
  until Unity regenerates it, so a clean build proves nothing about that file.
  Two honest routes:
  - Ask the user to focus the Unity Editor once (it recompiles and regenerates the
    projects), then rebuild. Reliable.
  - Run the Tier 3 scratch check on the new file. Catches syntax and type errors;
    does not validate assembly boundaries.
- **Staleness generally.** After any change to an `.asmdef`, `Packages/manifest.json`,
  or scripting-define settings, the generated solution is stale. Prefer Tier 1, or
  ask the user to focus the Editor first.
- Roslyn version and preprocessor defines may differ subtly from Unity's own
  compilation (`UNITY_EDITOR`, platform defines, package `versionDefines`). Errors
  it reports are almost always real; a clean build is slightly weaker evidence
  than Tier 1.
- It cannot catch what Unity's asset pipeline validates: filename/class-name
  mismatch on a MonoBehaviour, invalid `[CreateAssetMenu]` paths, duplicate GUIDs.

If `.sln`/`.csproj` are absent, the project lacks the Rider/VS Editor package or
has never generated them. Note it in `PROJECT.md` and fall back to Tier 1 or 3
rather than asking the user to add a package.

---

### Tier 3 — Scratch Roslyn check for new or isolated files

For new files that Tier 2 can't see, compile them directly against the assemblies
Unity already produced.

Build the throwaway project **in the harness** — `$HARNESS/scratch/syntaxcheck/` —
never in the repo. Reference `$REPO/Library/ScriptAssemblies/*.dll` plus the Unity
managed DLLs from the editor install (`.../Editor/Data/Managed/UnityEngine/*.dll`),
and compile only the specific `.cs` files in question.

Treat the result as a **syntax and type gate only**. Because it flattens
everything into one compilation unit, it will *hide* asmdef boundary violations
rather than invent false ones — so a pass does not prove the assembly references
are correct. Check those by reading the asmdefs
(`unity-architecture/references/assemblies.md`).

If `Library/ScriptAssemblies` is empty or absent, the project has never been
compiled on this machine and this tier is unavailable.

---

### Tier 4 — Static review (not verification)

When nothing above is available. Work the checklist explicitly and report the
result as **"not compile-verified"** with the reason. Never phrase it as if a
check ran.

- [ ] Every type referenced is in an assembly this file's assembly can see
- [ ] Every `using` resolves; no namespace guessed from memory
- [ ] Method signatures match at every call site you changed
- [ ] Interface implementations complete — every member, correct signature
- [ ] `abstract`/`override`/`new` correct against the base class you actually read
- [ ] Generic constraints satisfied
- [ ] No Unity API newer than the project's Unity version — check
      `ProjectVersion.txt` and verify the API against docs, not memory
- [ ] `UnityEditor.*` only inside an Editor assembly or `#if UNITY_EDITOR`
- [ ] Filename matches the public type name for MonoBehaviour/ScriptableObject
- [ ] No duplicate type names in the same namespace
- [ ] Nullable context consistent with the project

---

## Reporting the result

State the tier and the outcome plainly, in one or two lines. The right register:

- "Verified: `dotnet build` clean (Tier 2). `StaminaController.cs` is new so it
  isn't in the generated csproj yet — I type-checked it separately against the
  existing assemblies. Focus the Editor once and it'll be covered properly."
- "Verified: Unity batch compile clean, exit 0, log at
  `logs/compile-20260808-1431.log`."
- "**Not compile-verified.** You had the Editor open so batch mode wasn't safe, and
  the generated solution is stale after the asmdef change. Static review found no
  issues, but treat your first Editor recompile as the real check."

Never:

- imply verification you didn't do
- report "should compile" as though it were a result
- omit which tier ran
- bury a failed verification below the change summary

If verification failed and you fixed it, say so: "First build failed on two
missing usings; fixed and rebuilt clean." That's useful information, not an
admission.

## Runtime behaviour

The user verifies runtime behaviour by hand and has explicitly taken that on. So
never imply you tested behaviour — you compiled it. Where a change has a runtime
risk that compilation cannot catch (order-of-initialisation, null references on
unwired fields, physics timing), name it in the report so the user knows what to
watch for, and put a concrete observable check in the editor handoff.
