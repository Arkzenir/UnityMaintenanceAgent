# Unity engineering harness

An agent workspace for auditing, maintaining, and extending a Unity project that
lives somewhere else on disk. Nothing in here ever gets copied into your game
repo, and the agent is instructed — and mechanically checked — against writing
its own files there.

The harness is tool-neutral. The operating contract is [`AGENTS.md`](AGENTS.md),
which Claude Code, Codex, Cursor, Gemini CLI, Copilot and most other agents can
read. `CLAUDE.md` and `GEMINI.md` are short shims for the two tools that look
for their own filename first.

## Setup

1. **Extract this folder** wherever you like — next to your projects, not inside
   one. `~/dev/unity-agent` is fine.
2. **Copy `PROJECT_PATH.example.txt` to `PROJECT_PATH.txt`** and paste the path
   to your Unity project. Replace the `PASTE_YOUR_UNITY_PROJECT_PATH_HERE` line,
   save, done. (The terminal launchers create the file for you.)

   The path is the folder containing `Assets/` and `ProjectSettings/` — the project
   root, not the `Assets` folder. Quotes, trailing slashes, spaces and a leading
   `~` are all handled, so paste whatever your file manager gives you. Windows
   "Copy as path" output works as-is.

   Add more lines for a second repo — porting, re-importing, or comparing two
   projects. The first line is the working repo; the rest are references, and
   every check covers every line.

   Optional sanity check before you start:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\harness.ps1 check-path
   ```

   or, on macOS/Linux:

   ```bash
   ./scripts/harness.sh check-path
   ```

   It confirms the folder exists, is a Unity project root, and prints the Unity
   version it found. `PROJECT_PATH.txt` is gitignored, so your local path stays
   out of the repository.
3. **Nothing else to install for the checks.** They are PowerShell on Windows and
   POSIX `sh` on macOS/Linux — both already there. No Node, no Python.
4. **Install the agent you want to use** — Claude Code, Codex CLI, Gemini CLI,
   Cursor, or none of the above if you are running this from a harness that can
   read files and run commands itself.
5. **Keep Rider.** No IDE change is needed. The agent edits files on disk and
   Rider picks them up on focus. (There are JetBrains and VS Code integrations if
   you ever want inline diffs, but the desktop app is enough for this workflow.)

To switch projects later, just edit `PROJECT_PATH.txt` again.

## Running it

Open **this folder** — the harness, not your game repo — as the agent's working
directory. That is what makes it load `AGENTS.md` and the skills; opening the
game repo instead would silently give you a generic agent. Then grant the agent
access to your game repo as an additional directory or permission, in whatever
way your tool does that.

| Agent | What it loads | Notes |
|---|---|---|
| Claude Code / Claude Desktop | `CLAUDE.md` → `@AGENTS.md` | Plan mode default, `.claude/skills` pointers |
| Codex CLI | `AGENTS.md` natively | |
| Cursor | `AGENTS.md` natively | |
| Gemini CLI | `GEMINI.md` → `AGENTS.md` | |
| GitHub Copilot | `AGENTS.md` natively | |
| DSH / anything else | point it at `AGENTS.md` | |

No agent gets automatic hooks: `.claude/settings.json` stays hook-free so the
same file works on every OS, and every agent — Claude included — is told to run
`check-repo` before it ends a turn.

If your tool needs more than `AGENTS.md` — a fixed filename or its own config —
`agents/README.md` describes the pattern and includes a template.

The agent reads `PROJECT_PATH.txt` as its first action, so it already knows where
each project is. Nothing to paste into the chat. The repo-purity checks read the
same file, so they're protecting the right directories from the first turn.

If you ever want to work on a different project for one session without editing the
file, just name the path in chat — that wins for that session, and the agent will
offer to persist it.

### Terminal launchers (optional)

The launchers write the path into `PROJECT_PATH.txt`, export it for the checks,
and start your agent from the harness directory:

```bash
./agent.sh /path/to/MyUnityProject                    # defaults to claude
HARNESS_AGENT=codex ./agent.sh /path/to/MyUnityProject
```

```powershell
.\agent.ps1 C:\dev\MyUnityProject
.\agent.ps1 C:\dev\MyUnityProject -Agent codex
```

`-Agent` / `HARNESS_AGENT` takes any command on your `PATH`; remaining arguments
are passed through to it. Only Claude Code gets `--add-dir` automatically,
because that is its flag for granting a second directory. For other tools, grant
the repo access in that tool's own configuration.

For a second repo, add it at launch:
`.\agent.ps1 C:\target -AdditionalPaths C:\source` or
`./agent.sh /target --also /source`.

Without a launcher:

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

- **Propose-then-apply is the default.** It reads and analyses freely, then
  proposes, then waits. Nothing is written to your project until you approve. Use
  plan mode where your agent has one; otherwise it stops in chat.
- **One task at a time.** It won't run off through a backlog. Things it notices
  get recorded as observations and mentioned once.
- **Editor work comes back to you** as a numbered checklist. It'll offer a
  temporary editor script when the work is genuinely bulk, but only as an option,
  and it tracks that script until you delete it.
- **It won't claim to have tested anything.** It compiles; you verify behaviour.
  Where a change has a runtime risk compilation can't catch, it names it and gives
  you something concrete to look for.
- **It won't commit, push, or reset git.** `AGENTS.md` §8 forbids it for every
  agent; Claude Code additionally has those commands denied in
  `.claude/settings.json`. `com.unity.pipeline` is declined, so no experimental
  package can sneak in.

## Layout

```
AGENTS.md              the agent's operating contract — read this to know what it will do
CLAUDE.md, GEMINI.md   filename shims for Claude Code and Gemini CLI
README.md              you are here
skills/                six skills: audit, architecture, workflow, verification,
                       handoff, docs
.claude/
  README.md            how the Claude wiring fits together
  settings.json        Claude Code adapter: permissions and plan-mode default
  skills/              pointer stubs into skills/
agents/
  README.md            how to wire a tool; shared-vs-per-agent rule
  _template/           copy to agents/<id>/ for a new tool
scripts/
  harness.ps1          the checks, Windows PowerShell
  harness.sh           the checks, macOS/Linux sh
PROJECT_PATH.example.txt  copy to PROJECT_PATH.txt before you start
agent.sh / agent.ps1   optional terminal launchers
templates/             document templates the agent fills in
projects/<slug>/       per-project memory: PROJECT, CURRENT_STATUS, ARCHITECTURE,
                       CONVENTIONS, CHANGELOG, EDITOR_TASKS, proposals/
logs/                  compile logs
scratch/               throwaway analysis — safe to delete anytime
```

The two documents worth reading yourself are `projects/<slug>/CURRENT_STATUS.md`
(where things stand) and `CHANGELOG.md` (what was done).

## Repo-purity checks

The rule lives in `AGENTS.md` Rule 1; two platform-native scripts back it:

| Check | What it does |
|---|---|
| `check-path` | validates every configured path, prints each Unity version |
| `check-write <path>` | tests one write target; exit 2 blocks it |
| `check-repo` | scans the repo for stray artifacts; exit 2 lists them |

On Windows run them through `scripts/harness.ps1`; on macOS/Linux through
`scripts/harness.sh`. Exit 0 is clean. The agent is required to run `check-repo`
before it finishes a turn, and `check-write` on anything it is about to create
inside the repo.

Both read every path from `PROJECT_PATH.txt` (or the environment overrides) and
apply to all of them, so a reference repo is guarded too. They **fail open** when
no path is configured — a missing or unfilled `PROJECT_PATH.txt` means no
protection, which is the other reason to set it up first. Neither script deletes
anything. If a pattern ever produces a false positive on one of your own
filenames, edit the pattern lists near the top of `scripts/harness.ps1` and
`scripts/harness.sh` — they are plain arrays of regexes, kept in step across the
two files.

If the scan flags a file that is genuinely yours, the agent is told to say so and
leave it alone.

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
problems.

Whichever tier ran, the agent states it in every report. If it says "not verified",
believe it. And it's instructed never to imply it tested behaviour — where a change
carries a runtime risk that compilation can't catch, it names the risk and puts a
concrete observable check at the end of your editor checklist.

## Tuning

- **Behaviour:** `AGENTS.md`. The three hard rules and the task loop are the
  levers. They apply to every agent.
- **Conventions:** the agent writes `projects/<slug>/CONVENTIONS.md` from what it
  observes. If it got something wrong, edit that file directly — it's read every
  session and treated as authoritative.
- **Claude Code specifics:** `.claude/settings.json` holds Claude's permissions
  and plan-mode default. Other agents ignore that file and use their own
  permission configuration; the contract they follow is still `AGENTS.md`.
- **Note on plan mode (Claude Code):** its default permission mode changed to
  `auto` for new sessions in August 2026. A default you set yourself (as this
  harness does) stays in place unless you accept a one-time switch prompt — so if
  you're ever offered that switch, decline it to keep propose-then-confirm
  behaviour.
