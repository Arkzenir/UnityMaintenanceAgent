# Data and configuration

## The core distinction

| | Authored configuration | Runtime state |
|---|---|---|
| Lives in | an asset (`ScriptableObject`) | an instance (component field, plain C# object) |
| Lifetime | project lifetime | play session / object lifetime |
| Shared | yes, by every user of the asset | no, per instance |
| Mutable at runtime | **no** | yes |

Violating the last row is the single most common Unity data bug. Mutating a
`ScriptableObject` field at runtime:

- changes the value for every object referencing that asset simultaneously
- persists in the Editor after exiting play mode (the asset is dirtied)
- does **not** persist in a build (assets are read-only there)

So it produces behaviour that differs between Editor and build, and drifts
between play sessions. If you need per-instance values seeded from an asset,
copy them into instance state on `Awake`, or use `Instantiate(soAsset)` to make a
runtime clone and be explicit that it's a clone.

## ScriptableObject patterns worth knowing

**Config / definition assets.** The bread and butter: `WeaponDefinition`,
`EnemyStats`, `AbilityData`. Immutable at runtime, referenced by components.
Designers author variants without touching code. Prefer these over hard-coded
constants and over prefab-only configuration, because they're diffable, greppable
and reusable across prefabs.

**Runtime-set / registry assets.** A ScriptableObject holding a list of active
instances, populated on enable and cleared on disable. Gives systems a
subscriber list without a singleton and without `FindObjectsOfType`. Must be
cleared explicitly on load — the asset survives scene changes and, in the Editor,
play sessions.

**Event channels.** See `communication.md`.

**Strategy / polymorphic behaviour assets.** An abstract SO base with concrete
subclasses, referenced by field. Lets designers pick behaviour in the Inspector.
Combines well with `[CreateAssetMenu]` per concrete type. Costs a little
indirection; buys a lot of authoring flexibility.

**Variable assets.** A shared `FloatVariable` asset read by multiple systems.
Powerful but easily overused — it recreates global mutable state with extra
steps. Reach for it only where the project already does.

## Serialized field discipline

- `[SerializeField] private` over `public`. Public fields are an API promise and
  let anything mutate them; serialized privates are authorable without being
  public. Expose read access with a property where needed.
- `[field: SerializeField]` serialises an auto-property's backing field, if the
  project uses that style.
- Constrain in the Inspector so bad data can't be authored: `[Range]`, `[Min]`,
  `[Tooltip]`, `[Header]`. Tooltips are documentation the designer actually
  reads.
- `[SerializeReference]` allows polymorphic *non-asset* references. Useful, but
  its data is fragile across type renames — see `serialization.md`.
- Validate in `OnValidate` for anything that can be authored wrong. Log with the
  object name so the user can click through to it.

## Asset references

- Direct `[SerializeField]` reference: the asset is loaded whenever its
  referencing object is loaded. Simple, correct for small always-needed data.
- `AssetReference` (Addressables): loaded on demand, ownership must be managed.
  See `scenes-and-assets.md`.
- `Resources.Load`: string-keyed, loads the *entire* `Resources` folder tree into
  the build and its manifest into memory at startup. Avoid for new code. Note
  it as an observation if the project leans on it heavily.

## Where data lives, geometrically

Match the project. Two common layouts:

- by type: `Assets/Data/Weapons/*.asset`
- by feature: `Assets/Features/Combat/Data/*.asset`

If the project has a `[CreateAssetMenu(menuName = ...)]` convention, follow the
existing menu hierarchy exactly — designers navigate it by muscle memory.
