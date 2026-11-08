#!/usr/bin/env node
/**
 * repo-guard — PreToolUse guard for Write / Edit.
 *
 * Blocks the agent from creating harness, planning, or AI-related files inside
 * the game repo. Enforces Rule 1 of CLAUDE.md mechanically so it doesn't depend
 * on the model remembering.
 *
 * Reads the project path via hooks/project-path.mjs (PROJECT_PATH.txt, or the
 * UNITY_AGENT_PROJECT_PATH env var). If neither is configured the hook does
 * nothing — it fails OPEN by design, so a misconfigured environment never blocks
 * legitimate work. The CLAUDE.md rule still applies in that case.
 *
 * Exit codes: 0 = allow, 2 = block (stderr is shown to the agent).
 */

import { readFileSync } from "node:fs";
import path from "node:path";
import { resolveProjectPath } from "./project-path.mjs";

const ALLOW = 0;
const BLOCK = 2;

/** Filenames that must never appear inside the game repo. */
const BANNED_NAMES = [
  /^claude\.md$/i,
  /^agents?\.md$/i,
  /^\.claude$/i,
  /^\.cursor(rules)?$/i,
  /^\.aider.*/i,
  /^\.windsurfrules$/i,
  /^copilot-instructions\.md$/i,
  /^current_?status\.md$/i,
  /^curren_?status\.md$/i,
  /^handoff\.md$/i,
  /^analysis\.md$/i,
  /^audit(_report)?\.md$/i,
  /^plan\.md$/i,
  /^notes\.md$/i,
  /^scratch\..*/i,
  /^todo\.md$/i,
];

/** Filename patterns that signal agent scratch, backups, or shadow copies. */
const BANNED_PATTERNS = [
  /\.agent\.md$/i,
  /\.plan\.md$/i,
  /_notes\.md$/i,
  /_ai\.(cs|md)$/i,
  /\.bak$/i,
  /\.orig$/i,
  /\.old$/i,
  /\.cs\.(txt|new|old|bak)$/i,
  /(^|[\/\\])[^\/\\]*_v\d+\.cs$/i,
  /(^|[\/\\])[^\/\\]*_new\.cs$/i,
  /(^|[\/\\])[^\/\\]*_copy\.cs$/i,
  /(^|[\/\\])[^\/\\]*\.copy\.cs$/i,
];

/** Path segments inside the repo that are never ours to write. */
const BANNED_DIRS = [
  /(^|[\/\\])Library([\/\\]|$)/,
  /(^|[\/\\])Temp([\/\\]|$)/,
  /(^|[\/\\])obj([\/\\]|$)/,
  /(^|[\/\\])Logs([\/\\]|$)/,
  /(^|[\/\\])UserSettings([\/\\]|$)/,
];

function read(stream) {
  try {
    return readFileSync(stream === "stdin" ? 0 : stream, "utf8");
  } catch {
    return "";
  }
}

function norm(p) {
  return path.resolve(p).split(path.sep).join("/");
}

function main() {
  const projectPath = resolveProjectPath();
  if (!projectPath) return ALLOW; // fail open

  let payload;
  try {
    payload = JSON.parse(read("stdin"));
  } catch {
    return ALLOW; // unrecognised hook payload — fail open
  }

  const input = payload?.tool_input ?? {};
  const target =
    input.file_path ?? input.path ?? input.notebook_path ?? input.filePath;
  if (typeof target !== "string" || target.length === 0) return ALLOW;

  const repo = norm(projectPath);
  const file = norm(target);

  // Only concerned with writes inside the game repo.
  if (!(file === repo || file.startsWith(repo + "/"))) return ALLOW;

  const rel = file.slice(repo.length + 1);
  const base = path.basename(file);

  const hit =
    BANNED_NAMES.some((r) => r.test(base)) ||
    BANNED_PATTERNS.some((r) => r.test(rel)) ||
    BANNED_DIRS.some((r) => r.test(rel));

  if (hit) {
    process.stderr.write(
      `BLOCKED by repo-guard: "${rel}" is not permitted inside the game repo.\n` +
        `CLAUDE.md Rule 1 — the repo must contain no harness, planning, backup, ` +
        `or AI-related files, and Library/Temp/obj/Logs/UserSettings are off limits.\n` +
        `Write documentation and analysis to projects/<slug>/ in the harness, and ` +
        `scratch work to scratch/. If you were creating a backup copy, don't — ` +
        `git and the user's own VCS handle that.\n`
    );
    return BLOCK;
  }

  return ALLOW;
}

process.exit(main());
