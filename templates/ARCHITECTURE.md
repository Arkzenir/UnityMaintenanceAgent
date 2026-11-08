# Architecture

> The system map. Facts with file references. Update when structure changes —
> not for bug fixes.

## Assembly graph

```
<ascii graph of asmdefs and their reference direction, or a note that there are none>
```

## Bootstrap and entry point

- How the game starts: <mechanism>, at `<file>`
- Initialisation order: <ordered list>
- Composition root: `<file>` / none

## Cross-cutting mechanisms

| Concern | Mechanism | Where | Notes |
|---|---|---|---|
| Service access | | | |
| Inter-system messaging | | | |
| Configuration data | | | |
| Persistence / save | | | |
| Logging | | | |
| Scene loading | | | |
| Asset loading | | | |
| Update / ticking | | | |
| Object pooling | | | |

## Systems

### <System name>

- **Assembly:** `<assembly>`
- **Location:** `Assets/...`
- **Responsibility:** <one sentence>
- **Key types:** `<Type>` (`<file>`) — <role>
- **Depends on:** <systems / abstractions>
- **Depended on by:** <systems>
- **Data assets:** `<paths>`
- **Scene/prefab presence:** <where instances live>
- **Notes:** <quirks, known debt, deliberate design choices>

<repeat per system>

## Scenes

| Scene | Role | Loaded | Contains |
|---|---|---|---|
| | | | |

## Dependency rules in force

> The constraints a change must not violate.

-
