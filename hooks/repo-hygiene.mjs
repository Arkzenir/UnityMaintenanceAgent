#!/usr/bin/env node
/**
 * repo-hygiene — Stop hook.
 *
 * Scans the game repo for stray harness / AI / backup artifacts before the
 * agent is allowed to finish its turn. If any are found, blocks the stop and
 * tells the agent to clean up.
 *
 * Reads the project path via hooks/project-path.mjs (PROJECT_PATH.txt, or the
 * UNITY_AGENT_PROJECT_PATH env var). Fails OPEN if neither is configured or on
 * any error, so a broken hook never wedges a session.
 *
 * Skips Library/, Temp/, obj/, Logs/, .git/ and node_modules for speed.
 *
 * Exit codes: 0 = allow stop, 2 = block stop (stderr shown to the agent).
 */

import { readdirSync, statSync, readFileSync } from "node:fs";
import path from "node:path";
import { resolveProjectPath } from "./project-path.mjs";

const ALLOW = 0;
const BLOCK = 2;

const SKIP_DIRS = new Set([
  "Library",
  "Temp",
  "obj",
  "bin",
  "Logs",
  "UserSettings",
  ".git",
  ".vs",
  ".idea",
  "node_modules",
  "Build",
  "Builds",
]);

const SUSPECT = [
  /^claude\.md$/i,
  /^agents?\.md$/i,
  /^\.cursorrules$/i,
  /^\.windsurfrules$/i,
  /^copilot-instructions\.md$/i,
  /^curren?t_?status\.md$/i,
  /^handoff\.md$/i,
  /^analysis\.md$/i,
  /^audit(_report)?\.md$/i,
  /\.agent\.md$/i,
  /\.plan\.md$/i,
  /_notes\.md$/i,
  /\.bak$/i,
  /\.orig$/i,
  /\.old$/i,
  /^scratch\./i,
];

const SUSPECT_DIRS = new Set([".claude", ".cursor", ".aider"]);

function walk(dir, repo, found, depth = 0) {
  if (depth > 12 || found.length > 40) return;
  let entries;
  try {
    entries = readdirSync(dir, { withFileTypes: true });
  } catch {
    return;
  }
  for (const e of entries) {
    const full = path.join(dir, e.name);
    if (e.isDirectory()) {
      if (SKIP_DIRS.has(e.name)) continue;
      if (SUSPECT_DIRS.has(e.name)) {
        found.push(path.relative(repo, full) + "/");
        continue;
      }
      walk(full, repo, found, depth + 1);
    } else if (SUSPECT.some((r) => r.test(e.name))) {
      found.push(path.relative(repo, full));
    }
  }
}

function main() {
  const repo = resolveProjectPath();
  if (!repo) return ALLOW;

  try {
    if (!statSync(repo).isDirectory()) return ALLOW;
  } catch {
    return ALLOW;
  }

  // Avoid an infinite stop-block loop if the agent can't or won't clean up.
  try {
    const payload = JSON.parse(readFileSync(0, "utf8"));
    if (payload?.stop_hook_active) return ALLOW;
  } catch {
    /* no payload — continue with the scan */
  }

  const found = [];
  walk(path.resolve(repo), path.resolve(repo), found);

  if (found.length === 0) return ALLOW;

  process.stderr.write(
    `repo-hygiene found ${found.length} stray artifact(s) in the game repo:\n` +
      found.map((f) => `  - ${f}`).join("\n") +
      `\n\nCLAUDE.md Rule 1: the repo must be clean. If you created these, ` +
      `remove them and move the content into projects/<slug>/ in the harness. ` +
      `If they predate you and belong to the user, say so explicitly in your ` +
      `report and leave them alone — do not delete the user's files.\n`
  );
  return BLOCK;
}

let code = ALLOW;
try {
  code = main();
} catch {
  code = ALLOW;
}
process.exit(code);
