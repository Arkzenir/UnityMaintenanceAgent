# Performance

Two rules frame everything below:

1. **Don't optimise without a measurement.** "This could be slow" is not a
   reason to complicate a design. If you believe something is a real problem,
   say what you'd measure and how.
2. **But don't author known-bad patterns either.** Allocating in `Update` isn't
   a premature-optimisation question; it's just wrong, and it's free to avoid.

## Allocation and GC

Unity's default GC is incremental but still causes frame spikes. The goal in
per-frame code is *zero* managed allocation.

Common per-frame allocation sources:

- `string` concatenation and interpolation — including inside `Debug.Log` calls
  that are "off" (the string is built before the call). Guard with a conditional
  or a `[Conditional]`-attributed logging wrapper.
- LINQ — every `Where`/`Select`/`ToList` allocates an enumerator and often a
  collection.
- `foreach` over an interface-typed or `IEnumerable`-typed collection (boxes the
  enumerator). `foreach` over a concrete `List<T>` or array does not allocate.
- `GetComponents<T>()`, `FindObjectsOfType<T>()` — allocate an array each call.
  Use the `NonAlloc`/`List<T>` buffer overloads, or cache.
- `Physics.RaycastAll`, `OverlapSphere` — use the `NonAlloc` variants with a
  pre-sized buffer.
- Lambdas that capture locals — allocate a closure per call.
- Boxing: passing a struct as `object`, or as an interface it implements.
- `new Vector3[]` / `new List<>` inside a method called per frame.

Pool anything spawned frequently: projectiles, VFX, damage numbers, UI list rows.
`ObjectPool<T>` (`UnityEngine.Pool`) exists in modern Unity; use the project's
pool if it has one.

## Cached lookups

`GetComponent`, `Camera.main` (a tagged `Find` under the hood),
`Shader.PropertyToID`, `Animator.StringToHash` — resolve once in `Awake`, store,
reuse. Passing string names to `Animator`/`Material` APIs hashes the string on
every call.

`transform` is itself a property lookup; caching it is a habit worth having in
hot loops, though the modern cost is small.

## Physics

- Layer collision matrix first, always. Removing unnecessary layer pairs is the
  single highest-leverage physics optimisation and costs nothing.
- Non-convex `MeshCollider` is expensive. Compose primitives instead.
- Never move a `Rigidbody` by setting `transform.position` — it teleports without
  informing the solver, breaking collision. Use `MovePosition` in `FixedUpdate`,
  or set `position` on the Rigidbody for genuine teleports.
- `Rigidbody.isKinematic` for objects moved by code but participating in
  collision.
- Fixed timestep is a global cost multiplier. Check `Time.fixedDeltaTime` before
  concluding physics is slow.

## Rendering

The usual culprits, in order of how often they're the actual problem:

- Draw call / SRP batch count — check the Frame Debugger. Material variety and
  per-instance material properties break batching. `Renderer.material` (as
  opposed to `sharedMaterial`) instantiates a material copy, breaking batching
  and leaking.
- Overdraw from transparency, especially full-screen particle effects on mobile.
- Realtime shadow cascades and light count.
- Canvas rebuilds — see `ui.md`.

## When to reach for Jobs / Burst / DOTS

Only when: the work is over thousands of homogeneous items, is genuinely
parallelisable, has no managed dependencies in the inner loop, and the profiler
shows it as the bottleneck. Introducing Jobs into an OOP project brings
`NativeArray` lifetime management, memory-leak diagnostics, and a hard split
between the DOTS and MonoBehaviour halves of the codebase.

If the project has no DOTS today, adding it is its own project, not a step in a
feature. Say so.

## Profiling discipline

If asked to fix performance, ask for or produce evidence first:

- Unity Profiler with **Deep Profile off** first (deep profiling distorts), on the
  target platform, on a build not the Editor. Editor numbers mislead badly.
- Profile Analyzer package for comparing before/after captures.
- The frame timing to care about is the 99th percentile, not the mean. Spikes are
  what players feel.

If no data is available, say what you'd instrument and propose adding markers
(`ProfilerMarker` / `Profiler.BeginSample`) as a separate small change.
