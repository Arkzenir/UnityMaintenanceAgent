# Lifecycle, initialisation, and update strategy

## Order of operations

Within a scene load, for all objects:

```
Awake         (all objects, order undefined between objects)
OnEnable      (all objects)
Start         (all objects, before first Update)
  ... first frame ...
FixedUpdate   (0..n times per frame, fixed timestep)
Update
LateUpdate
```

The rules that follow from this:

- **`Awake`: set up yourself.** Cache `GetComponent`, allocate, build internal
  state. Never reach out to another object's state — it may not be initialised.
- **`Start`: reach out.** By `Start`, every object's `Awake` has run. This is
  where cross-object wiring is safe.
- **`OnEnable`/`OnDisable`: subscribe/unsubscribe.** Always symmetric. An
  unsubscribed-on-disable, resubscribed-on-enable pair is the only reliable way to
  survive object pooling and scene reloads without duplicate handlers or leaks.
  Subscribing in `Awake` and never unsubscribing is a leak *and* a source of
  double-fire after pooling.
- **`Awake` does not run on a disabled GameObject.** A component waiting for
  `Awake` on an inactive object waits forever. This trips up bootstrap sequences.
- Instantiating a prefab runs its `Awake` and `OnEnable` *immediately, inside the
  `Instantiate` call*, before it returns. So a component can't rely on its
  spawner having assigned fields yet. Pass data via an explicit `Initialize(...)`
  called after `Instantiate`, or instantiate inactive, configure, then activate.

## Deterministic initialisation

`Awake` order between objects is undefined. If order matters, don't fight it —
make it explicit:

- A single bootstrap/composition-root object that initialises subsystems in a
  written order and hands out references. This is the most maintainable approach
  and the easiest to explain to a reviewer.
- `[DefaultExecutionOrder(n)]` for a genuine ordering requirement. Works, but the
  dependency is invisible from the consuming code — comment it.
- Script Execution Order in Project Settings — same objection, worse
  discoverability. Avoid for new code.
- `[RuntimeInitializeOnLoadMethod]` for pre-scene setup that needs no scene
  objects.

## Domain reload and enter-play-mode options

Many projects enable "Enter Play Mode Options" with domain/scene reload disabled
for faster iteration. If so, statics are **not** reset between play sessions.
Code that relies on static default values will behave differently on the second
play. Check `ProjectSettings/EditorSettings.asset` for this and record it in
`PROJECT.md` — it changes what code is safe to write.

Where statics are unavoidable, reset them explicitly:

```csharp
[RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
static void ResetState() => _instance = null;
```

## Update strategy

`Update` on a MonoBehaviour has a per-call managed↔native transition cost. One
`Update` is free; two thousand is measurable before any of your logic runs.

- Under a hundred updating objects: individual `Update` is fine and clearer.
- Hundreds to thousands of homogeneous objects: a central ticker (one `Update`
  iterating a list of plain C# objects or a registry) is the standard answer, and
  is also a natural place to add time-slicing (`update 1/4 of the list per
  frame`) for anything that doesn't need per-frame precision.
- Follow the project's existing choice. If it has a ticker, register with it.

**`FixedUpdate` is for physics only.** Read input in `Update` (buffer it), apply
forces in `FixedUpdate`. Reading input in `FixedUpdate` drops presses on frames
where it doesn't run.

**`LateUpdate` is for reacting to other objects' completed movement** — cameras,
IK, anything that must observe the final position for the frame.

## Coroutines vs async

Coroutines: tied to the MonoBehaviour's lifetime and enabled state. Stop when the
object is disabled — often what you want, occasionally a silent bug when the
sequence needed to finish. No return values, awkward error handling. Zero
dependencies.

`async`/`await` with UniTask (or plain `Task` with care): composable, returns
values, real try/catch. **But** nothing cancels it automatically — you must pass
a `CancellationToken` tied to object lifetime (`destroyCancellationToken` on newer
Unity, or a manually-disposed `CancellationTokenSource` in `OnDestroy`).
Otherwise the continuation runs against a destroyed object.

`async void` has no exception boundary — the exception vanishes. Never use it
except in an outermost handler that catches everything itself.

Match the project. Mixing both idioms in one system is worse than either.
