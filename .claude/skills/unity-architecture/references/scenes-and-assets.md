# Scenes, loading, and asset ownership

## Scene composition

**Single monolithic scene**: simple, but merge-hostile (two people editing one
`.unity` = unresolvable conflict) and loads everything at once.

**Additive scenes**: a persistent bootstrap/systems scene plus content scenes
loaded on top. This is the standard structure for anything beyond a small
project, because it separates "the game's services" from "this level's content"
and lets multiple people work without conflict.

Consequences of additive loading that must be designed for:

- Cross-scene references cannot be authored in the Inspector. A component in
  Level scene cannot serialize a reference to an object in the Systems scene.
  This is *the* reason projects adopt SO channels, registries, or a service
  locator — not fashion.
- Object activation order across scenes is not guaranteed. Explicit
  initialisation from a bootstrap is the reliable answer.
- `SceneManager.sceneLoaded` fires after the scene's `Awake`/`OnEnable`, so it's
  a valid place to do post-load wiring.
- Unloading a scene destroys its objects — anything subscribed to a longer-lived
  publisher must unsubscribe, or you get exceptions on destroyed objects.

## Resources vs Addressables vs direct references

**Direct `[SerializeField]` reference.** The asset loads when its referrer loads.
Correct for anything small and always needed. Zero API surface. Default choice.

**`Resources/`.** Everything under any `Resources` folder is included in the build
regardless of use, and its lookup manifest is loaded at startup. Heavy use inflates
build size and startup time, and the string keys can't be refactored or verified.
Acceptable for a handful of tiny always-needed assets; wrong as a general
strategy. Note heavy use as a health observation, don't unilaterally migrate.

**Addressables.** On-demand loading with reference counting, remote content, and
memory that can actually be reclaimed. The cost is real: every load must be
matched by a release, and getting ownership wrong produces leaks (never unloaded)
or premature unloads (null references mid-gameplay).

The ownership rules that matter:

- Whoever loads, releases. Write the release at the same time as the load, not
  later.
- Release on `OnDestroy` for anything loaded per-object; on scene unload for
  anything loaded per-scene.
- `Addressables.InstantiateAsync` must be released via
  `Addressables.ReleaseInstance`, not `Destroy`. `Destroy` leaks the reference
  count.
- `AsyncOperationHandle` is a struct holding a refcount — copying it and releasing
  twice is a bug, releasing zero times is a leak.
- Loading the same key twice returns a refcounted handle; both need releasing.

If a task involves Addressables, state explicitly in the proposal who owns each
load and where the release happens. That sentence prevents the majority of
Addressables bugs.

## Async loading UX

`SceneManager.LoadSceneAsync` with `allowSceneActivation = false` lets you hold at
90% until ready. Note that Unity reports progress in coarse steps, so a smooth
progress bar needs interpolation — don't promise smoothness you can't deliver.

Never block the main thread waiting on a load handle. `.WaitForCompletion()` on an
Addressables handle stalls the frame; it's acceptable at a loading screen and
nowhere else.

## Build and memory notes worth flagging

- `DontDestroyOnLoad` objects accumulate across scene loads if bootstrap runs more
  than once. Guard with a duplicate check, or better, load the bootstrap scene
  exactly once.
- Texture import settings dominate build size far more than code. If asked about
  build size, look there first (max size, compression, mipmaps, read/write
  enabled).
- `Read/Write Enabled` on meshes and textures doubles memory. Usually off.
- Asset bundles/Addressables group layout determines download granularity and
  duplicated dependencies. Check the build report before claiming a size win.
