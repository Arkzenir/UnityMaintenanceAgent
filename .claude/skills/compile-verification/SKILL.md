---
name: compile-verification
description: Establish that Unity C# changes actually compile, using the best method available — dotnet build on the generated solution, Unity batch-mode compile, a scratch Roslyn check for new files, or a disciplined static review. Use this after every code change to the project, and during bootstrap to determine and record which verification tier the environment supports. Never report a change as done without running this and stating the result honestly.
---

This harness keeps every skill under `skills/` so that any agent can load it.
Read `skills/compile-verification/SKILL.md` from the harness root and follow it
exactly.
