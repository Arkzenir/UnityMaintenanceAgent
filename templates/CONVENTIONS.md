# Project conventions

> **Observed from the project's own code, not imposed.** Every entry cites a file
> as evidence. When the project is inconsistent, record the dominant pattern and
> the exception. Newer code wins ties.
>
> This file is the reference for making new code look like it belongs.

## Tooling that already encodes style

- `.editorconfig`: present / absent — <path>
- Rider `.DotSettings`: present / absent
- Analyzers / StyleCop: <none>

<If tooling exists, it is authoritative and the table below is descriptive only.>

## C# style

| Aspect | Convention | Evidence |
|---|---|---|
| Private fields | | |
| Serialized fields | | |
| Properties | | |
| Namespaces | | |
| Braces | | |
| `var` usage | | |
| Access modifiers | | |
| Interfaces | | |
| Async naming | | |
| `using` placement | | |
| Nullable context | | |
| Regions | | |
| File headers | | |
| Comment density/voice | | |

## Unity patterns

| Aspect | Convention | Evidence |
|---|---|---|
| MonoBehaviour vs plain C# | | |
| Inheritance depth tolerated | | |
| Reference acquisition | | |
| Event style | | |
| ScriptableObject usage | | |
| `[CreateAssetMenu]` menu hierarchy | | |
| Editor script location | | |
| `#if UNITY_EDITOR` usage | | |
| Validation (`OnValidate` etc.) | | |
| Logging | | |

## Naming

| Kind | Pattern | Example |
|---|---|---|
| Scripts | | |
| Prefabs | | |
| ScriptableObject assets | | |
| Scenes | | |
| Materials / textures | | |
| Animation clips | | |
| Layers / tags / sorting layers | | |

## Folder structure

```
Assets/
  <actual observed tree, 2-3 levels>
```

- Organising principle: by type / by feature / mixed (<where>)
- New scripts for feature X go: `<path>`
- New data assets go: `<path>`

## Known inconsistencies

| Where | Pattern A | Pattern B | Which to follow |
|---|---|---|---|
| | | | |
