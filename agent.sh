#!/usr/bin/env bash
# Launch the Unity engineering harness against a project repo.
#   ./agent.sh /path/to/UnityProject
#
# Runs Claude Code from THIS directory (so this harness's CLAUDE.md and skills
# load) with read/write access granted to the project repo.
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "usage: ./agent.sh /path/to/UnityProject [extra claude args...]" >&2
  exit 1
fi

PROJECT_PATH="$(cd "$1" && pwd)"
shift

if [ ! -d "$PROJECT_PATH/Assets" ] || [ ! -d "$PROJECT_PATH/ProjectSettings" ]; then
  echo "warning: $PROJECT_PATH does not look like a Unity project root" >&2
  echo "         (expected Assets/ and ProjectSettings/)" >&2
fi

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HARNESS_DIR"

# Keep PROJECT_PATH.txt in sync so the hooks and the agent see the same path.
{
  echo "# Written by agent.sh on $(date). Edit freely."
  echo "$PROJECT_PATH"
} > "$HARNESS_DIR/PROJECT_PATH.txt"

export UNITY_AGENT_PROJECT_PATH="$PROJECT_PATH"

exec claude --add-dir "$PROJECT_PATH" "$@"
