#!/usr/bin/env bash
# Launch the Unity engineering harness against a project repo with any agent CLI.
#   ./agent.sh /path/to/UnityProject
#   HARNESS_AGENT=codex ./agent.sh /path/to/UnityProject
#
# Runs the agent from THIS directory so this harness's AGENTS.md and skills load,
# with the project repo exported for the checks.
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "usage: ./agent.sh /path/to/UnityProject [agent args...]" >&2
  echo "       HARNESS_AGENT=codex ./agent.sh /path/to/UnityProject   # pick the CLI" >&2
  exit 1
fi

PROJECT_PATH="$(cd "$1" && pwd)"
shift

AGENT="${HARNESS_AGENT:-claude}"
AGENT_NAME="$(basename "$AGENT")"
AGENT_NAME="${AGENT_NAME%.exe}"

if ! command -v "$AGENT" >/dev/null 2>&1; then
  echo "error: agent '$AGENT' was not found on PATH" >&2
  echo "       install it, or set HARNESS_AGENT to the command to run" >&2
  exit 1
fi

if [ ! -d "$PROJECT_PATH/Assets" ] || [ ! -d "$PROJECT_PATH/ProjectSettings" ]; then
  echo "warning: $PROJECT_PATH does not look like a Unity project root" >&2
  echo "         (expected Assets/ and ProjectSettings/)" >&2
fi

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HARNESS_DIR"

# Keep PROJECT_PATH.txt in sync so the guards and the agent see the same path.
{
  echo "# Written by agent.sh on $(date). Edit freely."
  echo "$PROJECT_PATH"
} > "$HARNESS_DIR/PROJECT_PATH.txt"

export UNITY_AGENT_PROJECT_PATH="$PROJECT_PATH"

# Only Claude Code needs the extra directory flag; other agents get repo access
# from their own configuration.
if [ "$AGENT_NAME" = "claude" ]; then
  exec "$AGENT" --add-dir "$PROJECT_PATH" "$@"
fi

exec "$AGENT" "$@"
