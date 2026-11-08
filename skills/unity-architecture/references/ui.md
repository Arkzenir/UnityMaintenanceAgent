# UI

## Which system

**UGUI** (`UnityEngine.UI`, Canvas-based): mature, prefab-authored, the default
in most existing projects. Every UI element is a GameObject.

**UI Toolkit** (`UnityEngine.UIElements`, UXML/USS): retained-mode, stylesheet
driven, much better for dense editor-like UI and data-heavy lists. Runtime
support is solid in modern Unity but the ecosystem and world-space support lag
UGUI.

Use what the project uses. Mixing both in one screen is painful; mixing per-screen
is workable but doubles the conventions the user has to remember. If the project
has both, find out which is newer and prefer that for new work — then confirm.

## Separation of view and logic

The rule: **a UI component should not contain game rules.** A health bar knows how
to display a 0..1 value; it does not know what health is, when it changes, or what
happens at zero.

The layering that works:

```
Game state / systems   (owns truth, no UI knowledge)
        v   (event / observable / channel)
Presenter / view-model (translates state into display values, handles input intent)
        v   (direct references)
View (MonoBehaviour)   (Images, TMP_Text, Buttons — no rules)
```

Practical consequences:

- The view exposes `SetHealth(float normalized)`, not `SetHealth(Player p)`.
- Buttons raise an intent (`OnAttackPressed`), they don't execute the attack.
- The view is destroyable and reconstructable at any time without losing state,
  because it holds none.
- A screen can be tested by hand in isolation — open its scene, call its setter,
  see the result. If that's impossible, the layering is wrong.

## UGUI performance

Canvas rebuilds are the perennial cost. A canvas rebuilds its entire batch when
*any* graphic on it changes.

- **Split canvases** by update frequency. Static HUD frame on one canvas,
  per-frame-changing numbers on another. This alone fixes most UI performance
  complaints.
- Disable `Raycast Target` on everything that isn't interactive. Graphic Raycaster
  walks the hierarchy per pointer event.
- Prefer `CanvasGroup.alpha` or moving off-screen over `SetActive` for frequent
  show/hide — `SetActive` triggers a rebuild plus `OnEnable` chains.
- Text is expensive to regenerate. A per-frame-updating counter should update
  only when the value actually changes, not every frame.
- Nested layout groups recompute cascading. For long lists, size explicitly or
  virtualise.
- World-space canvases render per-camera; count them.

## Input routing

- With the new Input System, UI input goes through `InputSystemUIInputModule`. A
  project that has the Input System package but a legacy `StandaloneInputModule`
  in the scene will have UI that doesn't respond to gamepad — a very common
  half-migrated state. Check for it.
- Gamepad/keyboard navigation needs explicit `Selectable` navigation setup and a
  default selected object per screen, or focus is lost when a screen opens.
- Modal screens must consume input rather than merely rendering on top. Decide and
  state the mechanism (an input action map swap, a blocking raycast panel, an
  input stack).

## Screen lifecycle

Whatever the project's approach (a UI manager, a screen stack, prefab
instantiation, canvas toggling), the design questions are the same and should be
answered in the proposal:

- Who owns the screen instance's lifetime?
- What happens to the previous screen — hidden or destroyed?
- Is the back-navigation stack explicit, and where does it live?
- What resets on re-show?
