---
name: change-workflow
description: The mandatory propose-then-confirm-then-apply procedure for every change to the Unity project, including the proposal format, scope discipline, and how to apply approved changes cleanly. Use this before touching any file in the game repo, when writing up a planned change for review, and when applying changes the user has already approved. Always use it — there is no change small enough to skip the proposal.
---

# Change workflow

Three phases, strictly ordered, never merged: **propose → wait → apply.**

The user reviews every implementation by hand in the Editor. The proposal exists
so they can catch a wrong approach before it costs them a review cycle. A
proposal that's vague enough to approve without thinking has failed at its job.

---

## Phase 1 — Propose

### Before you write it

You must already have done the targeted audit (`unity-project-audit`). A proposal
written without reading the affected files is a guess, and the user cannot tell
the difference between a guess and a plan until they've already approved it.

You need concrete answers to:

- every file you will touch, and why
- the existing pattern you're following, with a file reference
- serialized members affected, and the real count of prefabs/scenes referencing
  them (from an actual search)
- what the user will have to do in the Editor afterwards
- what could break

### Write it

Use `templates/proposal.md`. Save to
`projects/<slug>/proposals/YYYY-MM-DD-short-slug.md` and present it inline in
chat. Keep the inline version tight — the user is reading it, not archiving it.

Required sections:

1. **Goal** — one or two sentences restating the request in your words. This is
   where a misunderstanding gets caught, so be specific rather than agreeable.
2. **Approach** — the design in a short paragraph. Name the pattern. Say which
   existing system it mirrors.
3. **Files** — a table: path, new/modified/deleted, one line of intent each.
4. **Architecture notes** — why this shape rather than the obvious alternative.
   Include the alternative you rejected and why, in one line. If the change adds
   an assembly reference, changes a dependency direction, or introduces a new
   pattern to the project, that goes here in bold.
5. **Risks** — serialization impact (with counts), scene/prefab impact,
   performance implications, anything that could break existing behaviour. If
   there are genuinely none, write "None identified" — don't pad.
6. **Editor work implied** — a preview of what section 4 of the post-apply report
   will contain. The user needs this to judge whether the design is worth it.
7. **Out of scope** — what you noticed but are deliberately not doing. This is
   how you honour Rule 3 without losing information.

### Offer options when the choice is genuinely the user's

If there are two reasonable designs with different trade-offs — a quick in-pattern
fix versus addressing the underlying structure, or two valid places for the new
code to live — present both, briefly, with a recommendation and a reason. Don't
manufacture false choices, and don't present five options; that's offloading the
design work back onto the user.

### Then stop

End your turn. Do not begin implementing. Do not write "I'll start with…". Do not
ask a rhetorical confirmation question and then proceed. Wait for an actual reply.

If the user's reply is a clarification rather than an approval, revise the
proposal and stop again. As many times as it takes.

---

## Phase 2 — The wait

Approval means the user said to proceed. It doesn't mean:

- they said "sounds good" about one part of a multi-part proposal
- they asked a question that you answered
- they approved a similar change earlier in the session
- silence

If the approval is partial or ambiguous, apply only the unambiguous part, or ask.

---

## Phase 3 — Apply

### Scope

Apply **exactly** the approved proposal. If, while implementing, you discover the
proposal was wrong — a file you didn't know about, a pattern that doesn't work
as you assumed — **stop and say so**. Do not improvise a different design mid-
apply. A revised proposal costs one message; a surprise architectural change
costs the user's trust in every future proposal.

Specifically, do not while applying:

- rename or reformat anything not in the proposal
- "tidy up" adjacent code
- fix unrelated bugs or warnings you notice
- add logging, comments, or defensive code the proposal didn't mention
- upgrade a package, change project settings, or add a dependency

### Order of operations

1. `git status` in the repo. Note pre-existing modifications so you can report
   accurately on what's yours. If the tree is dirty in the files you're about to
   touch, say so *before* editing.
2. Make the edits. Prefer editing in place over rewriting whole files — the user
   reviews diffs.
3. Verify compilation (`compile-verification` skill). Do not skip. Do not report
   as if you did it when you didn't.
4. If verification fails, fix the compile errors — that's within scope, it's the
   same change — and re-verify. If fixing requires a design change, stop and
   report.
5. `git diff --stat` to confirm the change set matches the proposal exactly. If a
   file appears that wasn't in the proposal, explain why in the report.
6. Update the harness docs (`status-docs` skill).
7. Write the report (format in `AGENTS.md` §6) with the editor checklist
   (`editor-handoff` skill).

### Writing code that fits

- Match `CONVENTIONS.md` precisely — naming, braces, `var`, namespaces, comment
  density. Re-read it if you're unsure; don't approximate from memory.
- Reuse the project's existing utilities rather than writing new equivalents.
  Check before writing any helper.
- New files go where the project's structure says they go, with the project's
  namespace, and — for MonoBehaviours and ScriptableObjects — a filename matching
  the type exactly.
- Every new asset file needs Unity to generate its `.meta`. You cannot create
  valid `.meta` files; the user's next Editor focus will generate them. Mention it
  if it matters for their next step.
- No commented-out code. No `// TODO` unless the project uses them and the user
  agreed to one. No meta-commentary.

### If you have to abandon mid-apply

Say so immediately, list exactly what was already written, and recommend either
completing a coherent subset or reverting. Never leave the project in a state
that doesn't compile without saying so in the first line of your report.
