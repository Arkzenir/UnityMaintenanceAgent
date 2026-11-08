---
name: status-docs
description: Maintain and audit the harness project documents — CURRENT_STATUS, ARCHITECTURE, CONVENTIONS, CHANGELOG, EDITOR_TASKS, PROJECT — and reconcile them against the actual repo so they never drift out of date. Use this at the start of every session before trusting anything you previously wrote, and after every applied change. Also use it whenever you are about to state a fact about the project that came from a document rather than from the files.
---

# Status documents

These documents exist so a fresh session can be productive in two minutes instead
of twenty. That value collapses the moment they're wrong — and worse, a stale
document is more dangerous than no document, because you'll act on it with
confidence.

They all live in `projects/<slug>/`. **None of them ever go in the repo.**

---

## The set

| Document | Contains | Updated |
|---|---|---|
| `PROJECT.md` | Immutable-ish facts: repo path, Unity version, render pipeline, input system, packages, toolchain, compile-verification tier, standing user decisions | On bootstrap; when a fact changes |
| `CURRENT_STATUS.md` | Live state: what works, what's in progress, known issues, open observations, last-verified timestamp | Every session, every change |
| `ARCHITECTURE.md` | System map: each system, its files, its assembly, how it connects to others | When structure changes |
| `CONVENTIONS.md` | The project's own style and patterns, with file references as evidence | On bootstrap; when you notice a correction |
| `CHANGELOG.md` | Append-only log of every applied change | Every applied change |
| `EDITOR_TASKS.md` | Outstanding manual editor work; temp scripts pending removal | When handing off; when the user confirms completion |

---

## Session-start reconciliation

**This is the part that keeps the system honest.** Do it before accepting a task,
every session.

The user edits this project by hand between sessions — new prefabs, new scripts,
refactors, reverted changes. Your documents describe a repo that may no longer
exist.

Run these cheap checks:

```bash
# has anything changed since your last recorded state?
git -C "$REPO" log --oneline -20
git -C "$REPO" status --short

# do the assemblies still match ARCHITECTURE.md?
ls "$REPO/Library/ScriptAssemblies"/*.dll
find "$REPO/Assets" -name "*.asmdef"

# engine or package changes?
cat "$REPO/ProjectSettings/ProjectVersion.txt"

# script count as a rough drift signal against your last recorded number
find "$REPO/Assets" -name "*.cs" | wc -l
```

Then:

1. **Spot-check three claims** from `ARCHITECTURE.md` against the actual files —
   ideally the three most load-bearing ones, or whatever is closest to the task at
   hand. Do the named files still exist? Do they still do what you wrote?
2. **Check `EDITOR_TASKS.md`** for outstanding items. If any temp scripts are
   listed as pending removal, verify whether they're still present. Mention
   outstanding items **once**, briefly, then move on.
3. **Check the last entry in `CHANGELOG.md`** against `git log`. If there are
   commits or working-tree changes after your last entry that you didn't make, the
   user has been working — note it and look at what they changed before assuming
   anything.
4. **Update the reconciliation stamp** in `CURRENT_STATUS.md` with today's date
   and what you checked.

If reconciliation finds meaningful drift — a system was rewritten, files moved,
conventions changed — **say so and offer a re-audit** rather than patching the
docs from inference. Re-run the relevant part of `unity-project-audit`.

Report reconciliation in one or two lines. "Docs match the repo; two commits
since last session, both in `Assets/Art/`, no code impact." That's enough.

---

## After every applied change

Update, in this order:

1. **`CHANGELOG.md`** — append. Date, one-line summary, files touched,
   verification tier and result, editor actions handed off. Never edit or delete a
   past entry; if something was wrong, add a correcting entry.
2. **`CURRENT_STATUS.md`** — revise the affected sections. Move anything from "in
   progress" to "working" only when the user has confirmed it works, not when you
   finished writing it. That distinction is the whole point of the document.
3. **`ARCHITECTURE.md`** — only if structure changed: a new system, a new
   assembly reference, a changed dependency direction, a system removed. Don't
   rewrite it for a bug fix.
4. **`EDITOR_TASKS.md`** — add the handed-off actions as pending. They're not done
   until the user says so.
5. **`CONVENTIONS.md`** — only if you *learned* something about the project's
   existing conventions. Never record your own change as a new convention.

Keep these edits small. A changelog entry is three or four lines, not a report.

---

## Writing rules

- **State facts, with evidence.** "Movement is in `Game.Features.Movement`
  (`Assets/Features/Movement/*.asmdef`)" beats "movement is well organised."
- **Date anything time-sensitive.** Every claim in `CURRENT_STATUS.md` has an
  implicit "as of" — make it explicit where it matters.
- **Distinguish what you know from what you inferred.** Mark inferences: "appears
  to be", "not verified". You will read this later and trust it.
- **Distinguish user decisions from your suggestions.** If the user approved
  something, write "user approved X on <date>". If you recommended something and
  they didn't respond, write it as an open recommendation. Never let your own past
  suggestion harden into a recorded decision.
- **Keep `CURRENT_STATUS.md` short enough to read fully.** Two pages maximum. When
  it grows past that, the detail belongs in `ARCHITECTURE.md` and the history in
  `CHANGELOG.md`. A status document nobody reads is worse than none.
- **Cap Open Observations at ten items,** ordered by impact. Prune resolved and
  stale ones each session. An ever-growing list of unactioned observations is
  noise the user will start ignoring wholesale.
- No AI meta-commentary anywhere. These are engineering documents.

---

## Naming note

The user asked for a `CURREN_STATUS` document (typo in the original request). Use
`CURRENT_STATUS.md`. Mention the correction once, the first time, so they know
where to look.
