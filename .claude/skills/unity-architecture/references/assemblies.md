# Assembly definitions

## Why they matter

Assembly definitions (`.asmdef`) split `Assembly-CSharp` into real compilation
units. Three consequences, in order of practical importance:

1. **Compile time.** Unity recompiles only the changed assembly and its
   dependents. On a large project this is the difference between a 2-second and a
   40-second iteration loop.
2. **Enforced dependency direction.** An assembly cannot reference something that
   doesn't reference it back. This is the only mechanism in Unity that makes
   architectural layering *impossible to violate by accident* rather than merely
   discouraged.
3. **Platform and Editor stripping.** Editor-only code physically cannot enter a
   player build.

## Dependency direction

Dependencies point inward, toward stability. A workable default layering:

```
Game.Bootstrap        (composition root; references everything)
    v
Game.Features.*       (Combat, Inventory, Dialogue — siblings, no cross-refs)
    v
Game.Core             (domain types, interfaces, math, utilities)
    ^
Game.Data             (ScriptableObject definitions; referenced by Core consumers)
```

Two feature assemblies must not reference each other. When Combat needs to tell
Inventory something, both depend on an abstraction in `Core` — an interface, an
event type, a channel asset. If you find yourself wanting a sibling reference,
the shared concept belongs one layer down.

The failure mode to watch for: a developer hits a circular reference, gets stuck,
and moves the file into `Assembly-CSharp` (which references everything). That's
the layering silently collapsing. If you see files that "should" be in an
assembly sitting outside all of them, that's usually why.

## Rules of thumb

- **One assembly per feature**, not per folder. Assemblies have overhead; dozens
  of tiny ones slow down the initial compile and clutter the reference lists.
- **Editor code gets its own assembly**, with `includePlatforms: ["Editor"]`.
  Runtime assemblies must never reference an Editor assembly.
- **Set `autoReferenced: false`** on assemblies that shouldn't be visible to
  `Assembly-CSharp` — this prevents accidental coupling from loose scripts.
- **Third-party/vendor code**: if it has no asmdef, it lands in
  `Assembly-CSharp`, which means your asmdef'd code cannot see it. This is a
  common and confusing breakage. Options: add an `.asmdef` inside the vendor
  folder (breaks on vendor update), or use an `.asmref`, or keep the consuming
  code outside asmdefs. Flag this trade-off rather than silently picking.
- **`rootNamespace`** on the asmdef makes Rider and the Unity script templates
  generate the right namespace automatically. Set it if the project uses
  namespaces.
- **Version defines** (`versionDefines`) let an assembly compile conditionally on
  a package's presence. Useful for optional integrations.

## Before adding an assembly reference

Adding a reference is an architectural change. Check:

1. Would this create a cycle? Trace the existing graph first.
2. Is the reference pointing inward (toward more stable code)?
3. Would an interface in a lower assembly serve instead?
4. Does the referenced assembly's platform list include this one's?

State the answer in the proposal. "Added `Game.Features.Combat` →
`Game.Core` reference" is a line the user should see, not infer.

## When the project has no asmdefs

That is a legitimate state. Everything is in `Assembly-CSharp` /
`Assembly-CSharp-Editor`, ordering is handled by Unity, and there is no enforced
layering. Work within it: use namespaces and folder discipline for logical
separation, and keep `Editor/` folders (which Unity special-cases even without
asmdefs) for editor code.

Do not introduce asmdefs as a side effect of another task. Introducing them to an
established project is a multi-hour job with a long tail of reference errors, and
it deserves to be its own approved piece of work.
