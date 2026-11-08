# Communication between systems

The question is always: **who needs to know about whom?** Pick the loosest
coupling that still lets a reviewer trace the flow. Extremely decoupled systems
where nothing references anything are not maintainable — they're just
undebuggable in a different way.

## The options, from tightest to loosest

### 1. Direct reference (`[SerializeField]`)

Tightest, clearest, best default for objects that genuinely own each other. A
weapon owning its muzzle transform. A health bar owning its fill image.

Use when: the relationship is structural and authored on the same prefab or
scene.

### 2. Interface reference

Same coupling shape, but to a role rather than a concrete type. `IDamageable`,
`IInteractable`. Lets the caller work with anything fulfilling the contract.

Use when: multiple concrete types must be addressed uniformly. This is the
workhorse of clean Unity gameplay code.

### 3. C# event / `Action` on the publisher

The subscriber knows the publisher; the publisher knows nothing. Cheap, typed,
refactor-safe.

```csharp
public event Action<float> HealthChanged;
```

Non-negotiable discipline: subscribe in `OnEnable`, unsubscribe in `OnDisable`.
An event holds a strong reference to the subscriber — a missed unsubscribe keeps
destroyed objects alive and fires handlers on them.

Use when: one publisher, subscribers that can reach it.

### 4. `UnityEvent`

Wired in the Inspector, so designers can connect things without code. Costs:
slower than a C# event, invisible to code search (you cannot `rg` for a
subscriber), and serialised references that break on rename.

Use when: the project uses them, and the connection is genuinely presentational
(button → sound, trigger → animation). **Never** put gameplay logic flow inside
a `UnityEvent` chain — it becomes untraceable.

### 5. ScriptableObject event channel

An asset acts as the meeting point. Publisher raises on the asset; subscribers
register with it. Neither knows the other. Designers can see the channel asset in
the project, and can wire cross-scene connections that direct references cannot
express.

```csharp
[CreateAssetMenu(menuName = "Events/Void Channel")]
public class VoidEventChannel : ScriptableObject
{
    public event Action Raised;
    public void Raise() => Raised?.Invoke();
}
```

Costs: a `.asset` per channel, and the same lifetime hazard as any SO — the
event's subscriber list survives scene loads and, in the Editor, play sessions.
Unsubscribe rigorously.

Use when: cross-scene or cross-assembly communication, and the project already
does this. It's an excellent fit for Unity's asset-centric authoring model.

### 6. Message bus / signal aggregator

One central publish-subscribe hub, typed messages. Everything depends on the bus
and on message types only.

Costs: the flow becomes invisible without tooling — "who handles this message?"
requires a search of handler registrations. Debugging a chain of five messages is
genuinely hard.

Use when: the project has one. Don't introduce one for a single feature.

### 7. Dependency injection container (Zenject, VContainer, Reflex)

Composition root declares bindings; consumers declare needs. Excellent for plain
C# services; awkward for scene-placed MonoBehaviours (which need injection at
instantiation).

Use when: the project already has one — then use it properly rather than routing
around it with singletons.

### 8. Service locator / registry

A static or asset-based registry: `Services.Get<IAudioService>()`. Simpler than
DI, but the dependency is invisible at the type's surface and failures are
runtime.

Use when: the project has one. Register in bootstrap, resolve in `Start` (not per
call, not in `Update`), and cache.

## Choosing, in practice

Ask two questions:

1. **Do they exist at the same time in the same scene?** If yes, a serialized
   reference or interface is almost always right and almost always clearest.
2. **Would a reviewer be able to find the other end?** If your answer requires
   explaining a convention, the coupling is too loose for the benefit.

## Never

- `SendMessage`, `BroadcastMessage`, `Invoke("Name", t)` — stringly-typed,
  unsearchable, silently no-ops on typo.
- Events raised from `OnDestroy` / `OnDisable` during scene teardown without a
  guard. Order is undefined; subscribers may already be destroyed.
- A subscription in `Awake` with no unsubscribe. It leaks and it double-fires
  after pooling.
- Mutating shared state inside an event handler while the publisher is iterating
  its subscriber list. Copy the list, or defer.
