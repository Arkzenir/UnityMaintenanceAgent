# Serialization safety

**This is the highest-risk area in Unity refactoring.** A rename that a C#
compiler considers trivially safe can silently blank out hundreds of authored
values across scenes and prefabs, with no error, no warning, and no undo. The
user finds out when the game misbehaves in play mode three days later.

Treat every change in this file as requiring an explicit callout in the proposal.

## What Unity actually serializes

Serialized:

- `public` non-static fields of a serializable type
- `private`/`protected` fields marked `[SerializeField]`
- primitives, `string`, enums, `UnityEngine.Object` references
- `Vector*`, `Quaternion`, `Color`, `Rect`, `Bounds`, `AnimationCurve`, etc.
- `[Serializable]` plain classes and structs (by value, inline)
- arrays and `List<T>` of the above
- fields marked `[SerializeReference]` (polymorphic, by managed reference)

**Not** serialized:

- properties (unless `[field: SerializeField]` on an auto-property)
- `static`, `const`, `readonly` fields
- `Dictionary<,>`, `HashSet<>`, tuples, nullable value types (`int?`)
- interface-typed fields **unless** `[SerializeReference]`
- multidimensional and jagged arrays (`int[,]`, `int[][]`)
- fields marked `[NonSerialized]`

Serialization identity is **the field name**, matched by string, against a type
identified by assembly + namespace + class name (`m_Script` GUID + fileID for
MonoBehaviours). Anything that changes those strings breaks the link.

## Operations and their risk

| Operation | Risk | Mitigation |
|---|---|---|
| Rename a serialized field | **Data loss** — silent reset to default | `[FormerlySerializedAs("oldName")]`, keep it for at least one full author pass |
| Change a field's type | **Data loss**, sometimes partial garbage | Add the new field alongside, migrate in `OnValidate`/`ISerializationCallbackReceiver`, remove the old field in a *later* approved change |
| Rename a MonoBehaviour class | **Every component reference breaks** — "script missing" on prefabs and scenes | Rename the file identically, let Unity resolve; verify by opening a known prefab. Or add a `MonoBehaviour` rename entry via script-mapping tooling |
| Move a class between namespaces | Same as class rename | Same |
| Move a class between assemblies | Same as class rename | Same; also check asmdef refs |
| Delete a serialized field | Data lost (usually intended) | Confirm nothing authored depends on it — search prefab/scene YAML for the field name |
| Reorder fields | Safe | — |
| Change `public` → `[SerializeField] private` | Safe (same name) | — |
| Add a field | Safe (defaults) | Consider whether default is a valid game value |
| Change a `[SerializeReference]` type's name | **Data loss**, and harder to recover than normal fields | `[MovedFrom]` attribute; treat as high risk |

## The mandatory pre-change check

Before renaming, retyping, or moving anything serialized:

```bash
# does anything actually have this authored?
rg -l "fieldName" "$REPO/Assets" --glob "*.prefab" --glob "*.unity" --glob "*.asset"

# where is this component placed?
rg -l "TypeName" "$REPO/Assets" --glob "*.prefab" --glob "*.unity"
```

If those return nothing, the change is low risk. If they return fifty files, say
so in the proposal with the number, and recommend the additive-migration route.

## Additive migration pattern

The safe way to change a field's type or meaning across authored data:

1. Add the new field. Leave the old one in place, marked `[Obsolete]` in comment
   or `[HideInInspector]`.
2. Migrate on load — `OnValidate` (Editor) plus a runtime path if needed — writing
   old → new when new is at default.
3. Ask the user to open and re-save the affected scenes/prefabs (or provide an
   editor utility that does it in bulk — see the `editor-handoff` skill).
4. In a **separate, later, approved** change, delete the old field.

Never compress this into one step to save a round trip. The round trip is the
point.

## Prefabs and scenes

- Never hand-edit `.prefab` or `.unity` YAML. The format has fileIDs, prefab
  override records, and nested-prefab back-references that are not safely
  editable by text substitution. Reading it to find references is fine.
- Prefab **variants** inherit and override. A change to the base's serialized
  fields propagates only where the variant hasn't overridden — so a field the user
  overrode on a variant will *not* pick up a new base default.
- A field changed in code keeps its authored value on existing instances. So
  changing a default in code does **not** update existing prefabs. If the user
  expects the new default everywhere, that's an editor task, not a code change.
- `.meta` files hold GUIDs. Never delete or regenerate them; a lost `.meta` breaks
  every reference to that asset.

## In the proposal, always state

- Which serialized members change, by name
- How many prefabs/scenes/assets reference them (a real number from a real search)
- Whether authored data will be preserved, and by what mechanism
- What the user must do in the Editor afterwards
