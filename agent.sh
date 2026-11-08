#!/usr/bin/env bash
# Launch the Unity engineering harness against one or more project repos.
#   ./agent.sh /path/to/UnityProject
#   ./agent.sh /path/to/UnityProject --also /path/to/LegacyGame
#   HARNESS_AGENT=codex ./agent.sh /path/to/UnityProject
#
# Runs the agent from THIS directory so this harness's AGENTS.md and skills load.
# The first path is the working repo; --also paths are references for porting or
# re-importing between projects.
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "usage: ./agent.sh /path/to/UnityProject [--also /path/to/OtherProject]..." >&2
  echo "       HARNESS_AGENT=codex ./agent.sh /path/to/UnityProject   # pick the CLI" >&2
  exit 1
fi

PROJECT_PATH="$(cd "$1" && pwd)"
shift

EXTRA_PATHS=()
while [ $# -gt 0 ] && [ "$1" = "--also" ]; do
  if [ $# -lt 2 ]; then
    echo "error: --also needs a path" >&2
    exit 1
  fi
  EXTRA_PATHS+=("$(cd "$2" && pwd)")
  shift 2
done

ALL_PATHS=("$PROJECT_PATH")
if [ ${#EXTRA_PATHS[@]} -gt 0 ]; then
  for extra in "${EXTRA_PATHS[@]}"; do
    ALL_PATHS+=("$extra")
  done
fi

AGENT="${HARNESS_AGENT:-claude}"
AGENT_NAME="$(basename "$AGENT")"
AGENT_NAME="${AGENT_NAME%.exe}"

if ! command -v "$AGENT" >/dev/null 2>&1; then
  echo "error: agent '$AGENT' was not found on PATH" >&2
  echo "       install it, or set HARNESS_AGENT to the command to run" >&2
  exit 1
fi

for p in "${ALL_PATHS[@]}"; do
  if [ ! -d "$p/Assets" ] || [ ! -d "$p/ProjectSettings" ]; then
    echo "warning: $p does not look like a Unity project root" >&2
    echo "         (expected Assets/ and ProjectSettings/)" >&2
  fi
done

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HARNESS_DIR"

{
  echo "# Written by agent.sh on $(date). Edit freely. One path per line; the first is the working repo."
  for p in "${ALL_PATHS[@]}"; do
    echo "$p"
  done
} > "$HARNESS_DIR/PROJECT_PATH.txt"

UNITY_AGENT_PROJECT_PATHS=''
for p in "${ALL_PATHS[@]}"; do
  if [ -n "$UNITY_AGENT_PROJECT_PATHS" ]; then
    UNITY_AGENT_PROJECT_PATHS="$UNITY_AGENT_PROJECT_PATHS:$p"
  else
    UNITY_AGENT_PROJECT_PATHS=$p
  fi
done
export UNITY_AGENT_PROJECT_PATHS

# Claude Code needs its extra directories passed explicitly; every other tool
# gets repo access from its own configuration.
AGENT_ARGS=()
if [ "$AGENT_NAME" = "claude" ]; then
  for p in "${ALL_PATHS[@]}"; do
    AGENT_ARGS+=(--add-dir "$p")
  done
fi

exec "$AGENT" ${AGENT_ARGS[@]+"${AGENT_ARGS[@]}"} "$@"
