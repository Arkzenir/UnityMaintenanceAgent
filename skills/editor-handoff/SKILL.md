---
name: editor-handoff
description: Write the numbered Unity Editor action checklist the user follows to wire up a change, decide what must be done by hand versus by a temporary editor script, and manage the lifecycle of any temp script so nothing is left in the repo. Use this after applying any change that requires prefab, scene, inspector, asset, or project-settings work — which is most changes.
---

# Editor handoff

The user does the Editor work by hand. Your code is inert until they wire it up,
so the checklist is not an afterthought — it is half the deliverable. A change
with a vague handoff is a change that doesn't work.

---

## The checklist

### Format

Numbered, imperative, in execution order. One action per step. Every step names
the exact asset, the exact component, and the exact field.

**Good:**

```
1. Open Assets/Prefabs/Player/Player.prefab.
2. Add component "Stamina Controller" (Game.Features.Movement).
3. On Stamina Controller, set Max Stamina to 100 and Regen Delay to 1.5.
4. Drag the existing Player Movement component into the Movement field.
5. Save the prefab (Ctrl+S).
6. Open Assets/Scenes/Game.unity and confirm no console errors on play.
```

**Bad:**

```
1. Add the new component to the player and hook up the references.
2. Configure as appropriate.
```

The difference is whether the user has to re-derive your intent.

### What every checklist must include

- **Exact asset paths**, relative to the repo root. Not "the player prefab."
- **The component's display name** as it appears in the Add Component menu (Unity
  splits PascalCase into words), plus the namespace if the name is ambiguous.
- **Field values**, if the change assumes non-default values. If a field must be
  set for the feature to work at all, say so — "required" — so a skipped step
  produces a question rather than a silent bug.
- **Which asset to save**, explicitly, per step group. Prefab edits especially:
  Unity does not autosave prefab-mode changes.
- **A verification step at the end.** Something concrete and observable: "enter
  play mode, hold shift, the stamina bar should drain over ~4 seconds." Without
  this the user can't tell success from a missed step.
- **Order sensitivity**, where it exists. "Do step 4 before step 3 or the field
  won't appear."

### What to include when relevant

- Project Settings changes (exact path: `Edit > Project Settings > Physics >
  Layer Collision Matrix`)
- New assets the user must create: `Assets > Create > ...` menu path, target
  folder, and naming convention
- Input action map additions, with action name, type, and bindings
- Addressables group assignment
- Layer, tag, or sorting-layer additions
- Scene-specific wiring, per scene, if more than one scene is affected
- Reimport / reserialize steps after a serialization migration
- "Nothing to do in the Editor" — say it explicitly when true. Silence reads as an
  omission.

### Keep it as short as the change allows

If a design needs fourteen manual steps and a different design needs three,
that's a design input, not a handoff problem. Mention it in the proposal
(`Editor work implied`) so the user can weigh it *before* approving.

---

## Temporary editor scripts

Some editor work is mechanical and error-prone by hand: setting the same field on
forty prefabs, migrating a renamed serialized field across scenes, bulk-assigning
Addressables labels, regenerating asset references. Offer a script for that.

### When to offer

Offer when the work is repetitive across many assets, or precise in a way that's
easy to get wrong by hand, or would require the user to open dozens of files.

Don't offer for a handful of steps — the script plus its review plus its removal
costs more than doing it by hand, and hand-wiring keeps the user's mental model of
their own project accurate.

### The rules, without exception

1. **Always optional.** Present it as an alternative to the manual steps, and
   always give the manual steps too. Never make the script the only path.
2. **Never write it without approval.** It's a repo modification like any other.
   Propose, wait, then write.
3. **Agree the path first.** It must go in an `Editor/` folder (or the project's
   Editor assembly) or it will break the player build. If the project has an
   existing home for one-off tooling, use that. Otherwise propose something like
   `Assets/Editor/Migrations/` and let the user confirm.
4. **It must be reviewable.** Small, single-purpose, readable in one screen if
   possible. No cleverness. The user is approving something that will mass-modify
   their authored data.
5. **Dry run first.** Anything that writes to assets gets a preview mode that logs
   exactly what it *would* change, and the user runs that first. Make dry run the
   default so an accidental click is harmless.
6. **It must be removed.** Log it in `EDITOR_TASKS.md` under "Temp scripts
   pending removal" the moment you write it. In your report, tell the user
   plainly: *"delete `Assets/Editor/Migrations/StaminaFieldMigration.cs` and its
   `.meta` when done."* At the start of every subsequent session, check whether
   any are still listed and remind them once — once, not every turn.
7. **It is not an AI artifact.** It's a project utility the user requested.
   Written in the project's style, with a normal human comment explaining what it
   does and that it's a one-off migration. No mention of agents, prompts, or
   sessions.

### Shape of a safe migration script

```csharp
// One-off: migrates the pre-1.4 `speed` field to `baseSpeed` on all
// MovementConfig assets. Delete after running.
public static class MovementConfigMigration
{
    [MenuItem("Tools/Migrations/Migrate MovementConfig speed (dry run)")]
    private static void DryRun() => Run(commit: false);

    [MenuItem("Tools/Migrations/Migrate MovementConfig speed (APPLY)")]
    private static void Apply() => Run(commit: true);

    private static void Run(bool commit)
    {
        // find assets, log every intended change, only write when commit is true,
        // AssetDatabase.SaveAssets() once at the end
    }
}
```

Points that matter: two menu items with dry run listed first and clearly labelled,
`Undo.RecordObject` where applicable, `EditorUtility.SetDirty` on each modified
object, one `SaveAssets` at the end rather than per-asset, and a final summary log
with the count.

### Doing editor work yourself

**Never edit `.unity`, `.prefab`, or `.asset` YAML directly.** fileIDs, prefab
override records, and nested prefab back-references are not safely text-editable,
and a corrupted scene is a bad day for the user. Reading that YAML to find
references is fine; writing it is not.

The user has declined `com.unity.pipeline`, so there is no route to a *running*
Editor. The only mechanism available for you to execute editor work is a temp
editor script driven headlessly:

```bash
"$UNITY_BIN" -batchmode -nographics -quit \
  -projectPath "$REPO" \
  -executeMethod MyMigration.Run \
  -logFile "$HARNESS/logs/migration-<date>.log"
```

Everything in the temp-script rules above applies, plus:

- The Editor **must be closed**, same as a batch compile. Ask; don't assume.
- `-executeMethod` requires a `static`, parameterless method in a class inside an
  `Editor/` folder or Editor assembly.
- Run the dry-run method first, show the user the log, and only then run the
  applying method with their go-ahead.
- Read the log and report what actually changed, with counts.
- Then still tell the user what to verify by hand.

That's a heavyweight path. It earns its cost for a bulk migration across dozens of
assets and almost never otherwise.

The user's stated preference is to do editor work themselves, and there's good
reason for it — they stay fluent in their own project, and they're the one
verifying runtime behaviour. **Default to the checklist.**
