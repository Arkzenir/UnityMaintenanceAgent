# Unity engineering harness

An agent workspace for auditing, maintaining, and extending a Unity project that
lives somewhere else on disk. Nothing in here ever gets copied into your game
repo, and the agent is instructed and mechanically prevented from writing its own
files there.

## Setup

1. **Extract this folder** wherever you like — next to your projects, not inside
   one. `~/dev/unity-agent` is fine.
2. **Open `PROJECT_PATH.txt` and paste the path to your Unity project.** Replace
   the `PASTE_YOUR_UNITY_PROJECT_PATH_HERE` line, save, done. That's the only
   setup step.

   The path is the folder containing `Assets/` and `ProjectSettings/` — the project
   root, not the `Assets` folder. Quotes, trailing slashes, spaces and a leading
   `~` are all handled, so paste whatever your file manager gives you. Windows
   "Copy as path" output works as-is.

   Optional sanity check before you start:

   ```bash
   node check-path.mjs
   ```

   It confirms the folder exists, is a Unity project root, and prints the Unity
   version it found.
3. **Install Claude Code** if you haven't:
   <https://docs.claude.com/en/docs/claude-code/overview>
4. **Keep Rider.** No IDE change is needed. The agent edits files on disk and
   Rider picks them up on focus. (There are JetBrains and VS Code integrations if
   you ever want inline diffs, but the desktop app is enough for this workflow.)

To switch projects later, just edit `PROJECT_PATH.txt` again.

## Running it — Claude Desktop

1. Open Claude Desktop and go to the **Code** tab.
2. **Open this folder** (`unity-agent`) as the working directory. Not your game
   repo — this one. The working directory is what determines whether the harness's
   `CLAUDE.md` and skills load, so opening the game repo instead would silently
   give you a generic agent.
3. Grant access to your game repo as an additional directory when prompted, or add
   it in the session's directory settings.
4. Say anything — "let's start", or just your first task.

The agent reads `PROJECT_PATH.txt` as its first action, so it already knows where
the project is. Nothing to paste into the chat. The repo-purity hooks read the same
file, so they're protecting the right directory from the first turn.

If you ever want to work on a different project for one session without editing the
file, just name the path in chat — that wins for that session, and the agent will
offer to persist it.

## Running it — terminal (optional)

If you'd rather use the CLI, the launchers take the path as an argument and write
it into `PROJECT_PATH.txt` for you:

```bash
./agent.sh /path/to/MyUnityProject          # macOS / Linux
.\agent.ps1 C:\dev\MyUnityProject           # Windows PowerShell
```

Or, with `PROJECT_PATH.txt` already filled in:

```bash
cd /path/to/unity-agent
claude --add-dir /path/to/MyUnityProject
```

## First session

The agent will detect there's no `projects/<slug>/` folder and run a full
bootstrap audit — engine facts, assembly graph, architectural patterns actually in
use, your code conventions, and a short health list. It writes all of that into
`projects/<slug>/` and reports a summary. Expect this to take a while on a large
project. After that, ask for whatever you want.

Every subsequent session it re-reads those documents and reconciles them against
the actual repo before trusting them, since you'll have been working by hand in
between.

## What it will and won't do

- **Plan mode is the default.** It reads and analyses freely, then proposes, then
  waits. Nothing is written to your project until you approve. Approve with the
  plan prompt or just tell it to go ahead.
- **One task at a time.** It won't run off through a backlog. Things it notices
  get recorded as observations and mentioned once.
- **Editor work comes back to you** as a numbered checklist. It'll offer a
  temporary editor script when the work is genuinely bulk, but only as an option,
  and it tracks that script until you delete it.
- **It won't claim to have tested anything.** It compiles; you verify behaviour.
  Where a change has a runtime risk compilation can't catch, it names it and gives
  you something concrete to look for.
- **It won't commit, push, or reset git.** Those are denied in settings. `unity
  pipeline` is denied too, so no experimental package can sneak in.

## Layout

```
PROJECT_PATH.txt       ← paste your Unity project path here before you start
check-path.mjs         optional: validates that path
CLAUDE.md              the agent's operating contract — read this to know what it will do
README.md              you are here
agent.sh / agent.ps1   optional terminal launchers
.claude/
  settings.json        permissions, plan-mode default, hooks
  skills/              six skills: audit, architecture, workflow, verification, handoff, docs
hooks/                 repo-purity guards + shared path resolver (see below)
templates/             document templates the agent fills in
projects/<slug>/       per-project memory: PROJECT, CURRENT_STATUS, ARCHITECTURE,
                       CONVENTIONS, CHANGELOG, EDITOR_TASKS, proposals/
logs/                  compile logs
scratch/               throwaway analysis — safe to delete anytime
```

The two documents worth reading yourself are `projects/<slug>/CURRENT_STATUS.md`
(where things stand) and `CHANGELOG.md` (what was done).

## Repo-purity hooks

Two Node scripts enforce the "nothing of mine in your repo" rule mechanically
rather than relying on the model to remember:

- `hooks/repo-guard.mjs` — blocks writes of harness/planning/backup files into
  the repo, and any write into `Library/`, `Temp/`, `obj/`, `Logs/`,
  `UserSettings/`.
- `hooks/repo-hygiene.mjs` — scans the repo before the agent finishes a turn and
  blocks it from stopping if it left something behind.

Both read the repo path from `PROJECT_PATH.txt` (or `UNITY_AGENT_PROJECT_PATH` if
you used a launcher) via `hooks/project-path.mjs`. Both **fail open**: if Node
isn't on your `PATH`, or the path file is still unfilled, they do nothing rather
than blocking legitimate work — so an unfilled `PROJECT_PATH.txt` means no
protection, which is the other reason to fill it in first. The instruction
in `CLAUDE.md` still applies either way. To disable them, delete the `hooks`
block from `.claude/settings.json`. If a pattern ever produces a false positive on
one of your own filenames, edit the pattern lists at the top of the two scripts —
they're plain arrays of regexes.

Neither hook deletes anything. If the hygiene scan flags a file that's genuinely
yours, the agent is told to say so and leave it alone.

## Compile verification

There are no unit or integration tests, and you verify runtime behaviour yourself,
so compilation is the only automated signal. The agent works out during bootstrap
what's available and records the exact working commands in `PROJECT.md`.

**No experimental packages**, per your call — which rules out `com.unity.pipeline`
and therefore any route to a *running* Editor. Unity's docs are explicit that
controlling the Editor from the `unity` CLI requires that package. So the ladder is:

1. **`dotnet build` on Unity's generated `.sln`** — the per-change loop. Seconds,
   works with the Editor open, no repo changes. One blind spot worth knowing: a
   `.cs` file the agent just created isn't in the generated `.csproj` until Unity
   regenerates it, so **focusing the Editor once after a new file is added** makes
   the next build meaningful. The agent is required to flag this rather than
   quietly claim a clean build.
2. **Headless batch compile** — `-batchmode -nographics -quit` against the
   version-matched editor binary, log parsed for `error CS`. Ground truth, and the
   fallback whenever the generated solution is stale (after asmdef or package
   changes). Requires the **Editor to be closed**; the agent asks rather than
   assumes, since it defaults to assuming you have it open.
3. **Scratch Roslyn check** against `Library/ScriptAssemblies` for new files.
   Syntax and types only — it flattens assemblies, so it can't validate asmdef
   boundaries.
4. **Static review** — reported explicitly as *not verified*.

The `unity` CLI is still used where it's genuinely useful: `unity editors --format
json` to locate the version-matched binary, `unity doctor` for license and config
problems. `unity pipeline` is in the deny list so it can't be run by accident.

Whichever tier ran, the agent states it in every report. If it says "not verified",
believe it. And it's instructed never to imply it tested behaviour — where a change
carries a runtime risk that compilation can't catch, it names the risk and puts a
concrete observable check at the end of your editor checklist.

## Tuning

- **Permissions:** `.claude/settings.json`. Add commands you get prompted for
  repeatedly to `allow`.
- **Conventions:** the agent writes `projects/<slug>/CONVENTIONS.md` from what it
  observes. If it got something wrong, edit that file directly — it's read every
  session and treated as authoritative.
- **Behaviour:** `CLAUDE.md`. The three hard rules and the task loop are the
  levers.
- **Note on plan mode:** Claude Code's default permission mode changed to `auto`
  for new sessions in August 2026. A default you set yourself (as this harness
  does) stays in place unless you accept a one-time switch prompt — so if you're
  ever offered that switch, decline it to keep propose-then-confirm behaviour.
