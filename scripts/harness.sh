#!/usr/bin/env sh
# Portable checks for the Unity engineering harness.
#
# macOS/Linux implementation. The Windows counterpart is scripts/harness.ps1;
# keep the two in step. No Node or Python needed.
#
#   ./scripts/harness.sh check-path            validate the configured project
#   ./scripts/harness.sh check-write <path>    test one write target
#   ./scripts/harness.sh check-repo            scan for stray artifacts
#
# check-write and check-repo exit 0 when clean and 2 on a violation. They fail
# open when no project path is configured.

set -u

SCRIPT_DIR=$(CDPATH= cd "$(dirname "$0")" && pwd)
HARNESS_DIR=$(CDPATH= cd "$SCRIPT_DIR/.." && pwd)
CONFIG_FILE="$HARNESS_DIR/PROJECT_PATH.txt"

BANNED_NAME_RE='^(claude\.md|agents?\.md|gemini\.md|\.claude|\.cursor(rules)?|\.codex|\.gemini|\.aider.*|\.windsurfrules|copilot-instructions\.md|current_?status\.md|curren_?status\.md|handoff\.md|analysis\.md|audit(_report)?\.md|plan\.md|notes\.md|scratch\..*|todo\.md)$'
BANNED_PATH_RE='(\.agent\.md$|\.plan\.md$|_notes\.md$|_ai\.(cs|md)$|\.bak$|\.orig$|\.old$|\.cs\.(txt|new|old|bak)$|/[^/]*_v[0-9]+\.cs$|/[^/]*_new\.cs$|/[^/]*_copy\.cs$|/[^/]*\.copy\.cs$)'
BANNED_DIR_RE='(^|/)(Library|Temp|obj|Logs|UserSettings|\.claude|\.cursor|\.codex|\.gemini|\.aider[^/]*)(/|$)'

usage() {
  printf 'usage: %s <check-path|check-repo|check-write <path>>\n' "$0" >&2
}

configured_path() {
  raw=''
  if [ -n "${UNITY_AGENT_PROJECT_PATH:-}" ]; then
    raw=$UNITY_AGENT_PROJECT_PATH
  elif [ -f "$CONFIG_FILE" ]; then
    raw=$(sed -n '/^[[:space:]]*#/d; /^[[:space:]]*$/d; p; q' "$CONFIG_FILE")
  fi

  [ -n "$raw" ] || return 1

  raw=$(printf '%s\n' "$raw" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

  case "$raw" in
    \"*\") raw=${raw#\"}; raw=${raw%\"} ;;
    \'*\') raw=${raw#\'}; raw=${raw%\'} ;;
  esac

  case "$raw" in
    *PASTE_YOUR_UNITY_PROJECT_PATH_HERE*) return 1 ;;
  esac

  case "$raw" in
    "~") raw=$HOME ;;
    "~/"*) raw=$HOME/${raw#\~/} ;;
  esac

  while [ "${raw%/}" != "$raw" ]; do
    raw=${raw%/}
  done

  [ -n "$raw" ] || return 1

  case "$raw" in
    /*) ;;
    *) raw="$PWD/$raw" ;;
  esac

  if [ -d "$raw" ]; then
    (CDPATH= cd "$raw" && pwd -P) || printf '%s\n' "$raw"
  else
    printf '%s\n' "$raw"
  fi
}

blocked() {
  printf 'BLOCKED by repo-guard: "%s" is not permitted inside the game repo.\n' "$1" >&2
  printf '%s\n' 'AGENTS.md Rule 1 - the repo must contain no harness, planning, backup, or AI-related files, and Library/Temp/obj/Logs/UserSettings are off limits.' >&2
  printf '%s\n' 'Write documentation and analysis to projects/<slug>/ in the harness, and scratch work to scratch/. If you were creating a backup copy, do not - git and the user'"'"'s own VCS handle that.' >&2
  exit 2
}

check_path() {
  repo=$(configured_path) || {
    printf 'ERROR: No project path configured.\n' >&2
    printf '  Copy PROJECT_PATH.example.txt to PROJECT_PATH.txt and paste your Unity project path.\n' >&2
    exit 1
  }

  printf 'Configured path: %s\n' "$repo"

  if [ ! -d "$repo" ]; then
    printf 'ERROR: That folder does not exist. Check for typos or a stray character.\n' >&2
    exit 1
  fi

  missing=''
  [ -d "$repo/Assets" ] || missing=" Assets"
  [ -d "$repo/ProjectSettings" ] || missing="$missing ProjectSettings"
  if [ -n "$missing" ]; then
    printf 'ERROR: Missing%s - this is not a Unity project root.\n' "$missing" >&2
    printf '  You may have pointed at the Assets folder or a parent folder.\n' >&2
    exit 1
  fi

  version='unknown'
  if [ -f "$repo/ProjectSettings/ProjectVersion.txt" ]; then
    found=$(sed -n 's/.*m_EditorVersion:[[:space:]]*\([^[:space:]]*\).*/\1/p' "$repo/ProjectSettings/ProjectVersion.txt" | head -n 1)
    [ -n "$found" ] && version=$found
  fi

  printf 'OK: valid Unity project root (Unity %s).\n' "$version"
  printf '  Ready - start the agent.\n'
}

check_write() {
  target=${1:-}
  [ -n "$target" ] || exit 0

  repo=$(configured_path) || exit 0
  [ -d "$repo" ] || exit 0
  repo=${repo%/}

  case "$target" in
    /*) file=$target ;;
    *) file="$PWD/$target" ;;
  esac

  dir=$(dirname "$file")
  base=$(basename "$file")
  if resolved_dir=$(CDPATH= cd "$dir" 2>/dev/null && pwd -P); then
    file="$resolved_dir/$base"
  fi

  case "$file" in
    "$repo"|"$repo"/*) rel=${file#"$repo"}; rel=${rel#/} ;;
    *) exit 0 ;;
  esac

  if printf '%s\n' "$base" | grep -Eiq "$BANNED_NAME_RE"; then
    blocked "$rel"
  fi
  if printf '%s\n' "$rel" | grep -Eiq "$BANNED_PATH_RE"; then
    blocked "$rel"
  fi
  if printf '%s\n' "$rel" | grep -Eiq "$BANNED_DIR_RE"; then
    blocked "$rel"
  fi

  exit 0
}

check_repo() {
  repo=$(configured_path) || exit 0
  [ -d "$repo" ] || exit 0
  cd "$repo" || exit 0

  found=$(
    find . \
      \( -type d \( -name Library -o -name Temp -o -name obj -o -name bin \
        -o -name Logs -o -name UserSettings -o -name .git -o -name .vs \
        -o -name .idea -o -name node_modules -o -name Build -o -name Builds \) -prune \) -o \
      \( -type d \( -name .claude -o -name .cursor -o -name .codex \
        -o -name .gemini -o -name .aider \) -prune -print \) -o \
      \( -type f \( -iname 'claude.md' -o -iname 'agent.md' -o -iname 'agents.md' \
        -o -iname 'gemini.md' -o -iname '.cursorrules' -o -iname '.windsurfrules' \
        -o -iname 'copilot-instructions.md' -o -iname 'current_status.md' \
        -o -iname 'currentstatus.md' -o -iname 'handoff.md' -o -iname 'analysis.md' \
        -o -iname 'audit.md' -o -iname 'audit_report.md' -o -iname '*.agent.md' \
        -o -iname '*.plan.md' -o -iname '*_notes.md' -o -iname '*.bak' \
        -o -iname '*.orig' -o -iname '*.old' -o -iname 'scratch.*' \) -print \) \
      2>/dev/null
  )

  found=$(printf '%s\n' "$found" | sed -e '/^$/d' -e 's|^\./||' | head -n 40)
  [ -n "$found" ] || exit 0

  count=$(printf '%s\n' "$found" | wc -l | tr -d ' ')
  printf 'repo-hygiene found %s stray artifact(s) in the game repo:\n' "$count" >&2
  printf '%s\n' "$found" | sed 's/^/  - /' >&2
  printf '\n' >&2
  printf '%s\n' 'AGENTS.md Rule 1: the repo must be clean. If you created these, remove them and move the content into projects/<slug>/ in the harness. If they predate you and belong to the user, say so explicitly in your report and leave them alone - do not delete the user'"'"'s files.' >&2
  exit 2
}

action=${1:-}
case "$action" in
  check-path)  shift; check_path ;;
  check-write) shift; check_write "${1:-}" ;;
  check-repo)  shift; check_repo ;;
  *) usage; exit 1 ;;
esac
