---
name: unity-architecture
description: Advanced Unity game architecture and systems design — separation of concerns, assembly definitions, ScriptableObject data, composition over inheritance, event and dependency patterns, serialization safety, performance, scene and asset loading, UI layering. Use this whenever designing or reviewing any Unity C# implementation: new features, new systems, refactors, and bug fixes that touch structure. Load the matching file in references/ for the specific subsystem before writing code.
---

# Unity architecture

The governing constraint: **the project's existing architecture wins.** These are
the principles you apply *within* whatever the project already does, and the
vocabulary you use to explain trade-offs to the user. They are not a target state
to migrate the project toward.

---

## The design procedure

Every time, before writing code:

1. **Name the responsibilities.** List them as separate nouns. "Read input",
   "decide movement", "apply movement", "play footstep audio", "update stamina
   bar". You now know how many types you're likely dealing with.
2. **Find the project's existing home for each.** One of those responsibilities
   probably already has a system. Use it.
3. **Decide where state lives** and who is allowed to mutate it. One owner per
   piece of state. Everyone else reads or requests.
4. **Decide how the pieces find each other.** Use the project's existing
   mechanism (see `references/communication.md`).
5. **Decide the assembly.** (see `references/assemblies.md`)
6. **Check serialization impact.** (see `references/serialization.md`) — this is
   the step most likely to silently destroy the user's scene data, and the step
   most easily skipped.
7. **Check the editor impact.** What must the user do by hand afterwards? If the
   answer is "a lot", consider whether a different design needs less.
8. **Then write.** Smallest change that is architecturally correct.

---

## The principles

### Separation of concerns is the primary axis

A type should have one reason to change. In Unity terms, the recurring
separations that pay off:

- **Data** (`ScriptableObject`, plain serializable structs) from **behaviour**
  (`MonoBehaviour`, plain C# services) from **presentation** (renderers, UI,
  audio, VFX).
- **Decision** from **execution**. A component that decides *what* should happen
  should generally not be the one that makes it happen. This is what makes
  behaviour testable by hand in the Editor and swappable per-character.
- **Runtime state** from **authored configuration**. Authored config is an asset,
  shared and immutable at runtime. Runtime state is per-instance. Mutating a
  `ScriptableObject` at runtime mutates the asset in the Editor and persists
  between play sessions — that is a bug generator, and one of the most common
  sources of "it works in build but not in editor" confusion.
- **Engine-facing glue** from **domain logic**. Domain logic in plain C# classes
  is easier to reason about, reuse, and move between assemblies. MonoBehaviours
  become thin adapters that own lifetime and serialized references.

### Composition over inheritance

Deep MonoBehaviour inheritance hierarchies are the classic Unity trap: they force
unrelated concerns into a shared base and make prefab variants painful. Prefer:

- small components that each do one thing, combined on a GameObject
- interfaces for capability (`IDamageable`, `IInteractable`) so systems talk to
  roles rather than concrete types
- `ScriptableObject` strategies for swappable behaviour authored per-asset
- a shallow base class only for genuinely shared *mechanism* (not shared
  *meaning*), one level deep

Two levels of inheritance is a smell worth mentioning; three is a problem.

### Explicit wiring over discovery

`FindObjectOfType`, `GameObject.Find`, and singleton-of-convenience make the
dependency graph invisible and the failure mode a `NullReferenceException` at an
unpredictable time. Prefer, in descending order:

1. `[SerializeField]` reference assigned in the Editor — visible, validated,
   fails at author time
2. Explicit injection from a composition root / installer / bootstrap
3. The project's registry, service locator, or DI container
4. Discovery at initialisation only, cached, with a clear error if absent
5. Discovery per-frame — effectively never

When a serialized reference is required, guard it: `OnValidate` warning, or a
null check with a specific message naming the object and field. Silent failures
cost hours in the Editor.

### No hidden global mutable state

Statics survive domain reload inconsistently, break "enter play mode without
reload", leak between test runs, and make load order matter invisibly. If the
project already uses statics, follow suit, but reset them deliberately
(`RuntimeInitializeOnLoadMethod`, or an explicit reset on bootstrap) and say so.

### Fail loudly at author time, gracefully at runtime

A missing reference should scream in the Editor console with the offending
object's name, and degrade without crashing in a build. `OnValidate`,
`[RequireComponent]`, and custom editor warnings are cheap and save the user
enormous amounts of Editor debugging.

### Determinism and frame independence

Anything gameplay-affecting scales by `Time.deltaTime`; anything physics-affecting
lives in `FixedUpdate` and scales by `Time.fixedDeltaTime`. Reading input in
`FixedUpdate` drops inputs. Writing to a `Rigidbody`'s transform directly fights
the physics engine. These are correctness bugs, not style.

---

## Reference files

Load the one you need. Don't work from memory.

| File | Covers |
|---|---|
| `references/assemblies.md` | asmdef design, dependency direction, Editor assemblies, compile time |
| `references/data-and-config.md` | ScriptableObject patterns, authored vs runtime data, asset references |
| `references/lifecycle.md` | Awake/OnEnable/Start order, initialisation, domain reload, update strategy, coroutines vs async |
| `references/communication.md` | events, UnityEvent, SO channels, message bus, DI, service locator — and when each is right |
| `references/serialization.md` | what Unity serializes, safe rename/move/retype, prefab and scene impact, migration |
| `references/performance.md` | allocation, GC, physics, rendering, profiling discipline, when to reach for Jobs |
| `references/scenes-and-assets.md` | additive scenes, Addressables vs Resources, loading, memory ownership |
| `references/ui.md` | UGUI vs UI Toolkit, view/logic separation, binding, input routing |
| `references/code-style.md` | how to match the project's C# style, and the defaults to fall back on |

---

## Anti-patterns to flag when you see them

You are not authorised to fix these unprompted. You *are* expected to name them
if they're relevant to the current task, in one line, and let the user decide.

- God manager holding unrelated subsystems
- `Update` on hundreds of near-identical components with no central ticker
- Runtime mutation of `ScriptableObject` config assets
- `Resources/` used as the general asset store (loads eagerly, bloats builds)
- `SendMessage` / `Invoke("MethodName", …)` — stringly-typed, unrefactorable
- `async void` in Unity code without an exception boundary
- Circular assembly references worked around by moving code to `Assembly-CSharp`
- Business logic inside a `UnityEvent` chain configured in the Inspector, where
  it's invisible to search and to code review
- `Camera.main` and `GetComponent` in `Update`
- Coroutines owning long-lived state on an object that gets disabled
