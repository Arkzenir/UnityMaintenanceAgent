---
name: unity-project-audit
description: Read and map an unfamiliar Unity repo — engine version, render pipeline, input system, assembly definitions, folder conventions, existing architectural patterns — and produce or refresh the harness project documents. Use this on first contact with a project (bootstrap), whenever you need to locate the systems a task touches, and before designing any change. Also use it when the project documents look stale or you are about to claim something "doesn't exist" in the project.
---

# Unity project audit

Two modes. **Bootstrap** is the full first-contact read. **Targeted** is locating
what a specific task touches. Both matter; bootstrap happens once, targeted
happens constantly.

The purpose of an audit is not to form opinions about the project. It is to learn
the project's language so your changes read as if the project's own author wrote
them.

---

## Bootstrap

Work through these in order. Record findings as you go into
`projects/<slug>/` using `templates/`. Tell the user you're auditing and roughly
how far along you are, but don't narrate every file.

### 1. Engine and toolchain facts

Cheap, high-value, do these first.

| Fact | Where |
|---|---|
| Unity version | `ProjectSettings/ProjectVersion.txt` |
| Packages + versions | `Packages/manifest.json`, `Packages/packages-lock.json` |
| Render pipeline | presence of URP/HDRP packages; `ProjectSettings/GraphicsSettings.asset` render pipeline asset reference |
| Input | is `com.unity.inputsystem` present? Are there `.inputactions` files? Or legacy `Input.GetKey` calls? |
| Scripting backend, API level | `ProjectSettings/ProjectSettings.asset` |
| Target platforms | `ProjectSettings/ProjectSettings.asset`, build folder names |
| Compiled assemblies | `Library/ScriptAssemblies/*.dll` — the ground truth for what assemblies actually exist |
| Local packages / submodules | `Packages/manifest.json` `file:` refs, `.gitmodules` |
| Third-party asset store code | large vendor folders under `Assets/` |
| VCS state | `git status`, `.gitignore` completeness (is `Library/` ignored?) |

`Library/ScriptAssemblies` is the most useful single directory in the repo for
understanding structure. If it's absent, the project hasn't been opened/compiled
on this machine — note that, it affects your verification options.

### 2. Assembly and folder topology

- Find every `*.asmdef` and `*.asmref`. Build the dependency graph: who
  references whom, which are Editor-only (`includePlatforms: [Editor]`), which
  allow unsafe code, which have `autoReferenced: false`.
- If there are **no** asmdefs, everything is in `Assembly-CSharp` /
  `Assembly-CSharp-Editor`. That is a legitimate state for many projects. Note
  it. Do not propose introducing asmdefs as part of an unrelated task.
- Map the top two or three levels of `Assets/`. Identify the organising
  principle: by type (`Scripts/`, `Prefabs/`, `Materials/`) or by feature
  (`Features/Combat/`, `Features/Inventory/`). Projects often mix both — record
  which is dominant and where the exceptions are.
- Note where `Resources/`, `StreamingAssets/`, `Editor/`, `Plugins/`, and
  `Addressables` groups live.

### 3. Architectural patterns actually in use

This is the important part. Read real code — pick the two or three largest
gameplay systems and read them properly, not just their signatures.

Answer each of these concretely, with a file reference as evidence:

- **Entry point and bootstrap.** How does the game start? A bootstrap scene? A
  `RuntimeInitializeOnLoadMethod`? A big `GameManager`?
- **Service access.** Singletons? A service locator? A DI container (Zenject /
  VContainer / Reflex)? Manual wiring via serialized references? Static classes?
- **Communication.** C# events? `UnityEvent`? A `ScriptableObject` event/channel
  pattern? A message bus? Direct method calls between MonoBehaviours?
- **Configuration data.** `ScriptableObject` configs? Hard-coded constants?
  JSON/CSV in `Resources`? Addressables?
- **State machines.** Hand-rolled enum switches? A state pattern? An asset-based
  FSM? Animator-driven?
- **Update strategy.** Every MonoBehaviour has its own `Update`? A central
  ticker? Coroutines? UniTask/async? Jobs/Burst anywhere?
- **Scene strategy.** One big scene? Additive loading? Scene per level?
- **UI.** UGUI or UI Toolkit? MVP/MVVM-ish or logic in the view?
- **Save/persistence.** Where and how?
- **Naming and style.** `_camelCase` vs `m_CamelCase` private fields.
  `[SerializeField] private` vs `public`. Namespace usage — or none. Brace style.
  `var` usage. Region usage. File header comments. **Record these precisely**,
  they're the most visible signal of whether your code fits.
- **Nullability, asserts, logging.** Is there a logging wrapper? Are
  `Debug.Log` calls stripped in release? Any custom assertion helpers?

Where the project is inconsistent — and it will be — record the dominant pattern
*and* the exception, and note which parts of the codebase are newer. Newer code
usually reflects current intent better. If you can tell from git history which
convention is trending, that's the one to follow.

### 4. Health observations

Note without fixing. These become Open Observations in `CURRENT_STATUS.md`.

- Compile warnings visible in `Library` logs or existing build logs
- Obvious tight coupling, circular assembly references
- `FindObjectOfType` / `GameObject.Find` in hot paths
- Allocations in `Update` (LINQ, string concat, `new` per frame)
- Missing script references / broken prefab links you can detect from
  `.prefab`/`.unity` YAML with `guid: 0000...` or missing `m_Script`
- Assets in `Resources/` that shouldn't be (Resources is loaded eagerly)
- Duplicated logic across systems

Cap this list. Ten items maximum, ordered by likely impact. A 60-item list is
noise the user will never action.

### 5. Write the documents

Create from `templates/`: `PROJECT.md`, `CURRENT_STATUS.md`, `ARCHITECTURE.md`,
`CONVENTIONS.md`, `CHANGELOG.md`, `EDITOR_TASKS.md`.

Then determine your compile-verification tier (see `compile-verification`
skill) and record it in `PROJECT.md`. Do this during bootstrap, not later when
you urgently need it.

### 6. Report

Short. Engine/pipeline/input facts, the architectural pattern summary in a few
lines, the top three health observations, your verification tier, and any
question you need answered before you can work well. Then ask what the user
wants to do.

---

## Targeted audit

Before designing any change, for every system the task touches:

1. **Find every call site**, not just the definition. `rg` for the type name,
   the method names, and the serialized field names. Serialized field names
   matter because scenes and prefabs reference them by string.
2. **Search the scene and prefab YAML** for references to the components you're
   changing. `rg -l "TypeName" --glob "*.prefab" --glob "*.unity"` finds where
   a component is actually placed. This is how you know the editor impact.
3. **Read the nearest analogous system.** If asked for an inventory system and
   there's already an equipment system, read the equipment system. That's your
   template.
4. **Check the asmdef boundary.** Which assembly will your new code live in?
   Does it need a reference that doesn't exist yet? Adding an asmdef reference is
   a real architectural change with a real risk of a circular reference —
   surface it in the proposal.
5. **Check for a `.meta` file** for every asset you reference. A missing meta
   means an unimported asset.

### Useful commands

```bash
# assembly graph
find "$REPO/Assets" -name "*.asmdef" -exec sh -c 'echo "== $1"; cat "$1"' _ {} \;

# what assemblies actually compiled
ls "$REPO/Library/ScriptAssemblies"/*.dll

# which prefabs/scenes reference a component
rg -l "MyComponent" "$REPO/Assets" --glob "*.prefab" --glob "*.unity"

# private field style census
rg -o --no-filename "private\s+\w+\s+(_\w+|m_\w+)" "$REPO/Assets" | head -50

# per-frame allocation smells
rg -n "Update\(\)" -A 20 "$REPO/Assets" --glob "*.cs" | rg "\.ToList\(|\.Where\(|new \w+\(|\+ \""

# find-object smells
rg -n "FindObjectOfType|FindObjectsOfType|GameObject\.Find" "$REPO/Assets" --glob "*.cs"
```

Adjust for the platform's shell. On Windows PowerShell, prefer `rg` (which is
bundled) over `find`/`grep`.

---

## Never do this

- Never conclude something doesn't exist in the project after one search. Try
  the plural, the abbreviation, the likely legacy name, and a case-insensitive
  search before saying so.
- Never modify anything during an audit. Auditing is read-only.
- Never open or rewrite `.unity` or `.prefab` YAML by hand as part of an audit.
  Reading it to find references is fine; editing it is not (see
  `editor-handoff`).
- Never treat `Library/` contents as project source. It's generated.
