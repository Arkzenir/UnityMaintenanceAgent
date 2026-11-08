/**
 * Shared resolver for the game repo path.
 *
 * Order of precedence:
 *   1. UNITY_AGENT_PROJECT_PATH environment variable (set by the launcher scripts)
 *   2. PROJECT_PATH.txt in the harness root (the user pastes their path there)
 *
 * Returns an absolute path, or null if nothing usable is configured. Callers
 * must treat null as "fail open" — a missing config should never block work.
 */

import { readFileSync } from "node:fs";
import path from "node:path";
import os from "node:os";
import { fileURLToPath } from "node:url";

export const HARNESS_DIR = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  ".."
);

export const CONFIG_FILE = path.join(HARNESS_DIR, "PROJECT_PATH.txt");

/** Text shipped in the config file; means "not filled in yet". */
const PLACEHOLDER = "PASTE_YOUR_UNITY_PROJECT_PATH_HERE";

/**
 * Tolerate whatever a file manager pastes: surrounding whitespace, wrapping
 * quotes (Windows "Copy as path" includes them), trailing separators, and a
 * leading ~ for the home directory.
 */
export function normalizePath(raw) {
  if (typeof raw !== "string") return null;

  let v = raw.trim();
  if (v.length === 0) return null;

  // strip one layer of wrapping quotes
  if (
    (v.startsWith('"') && v.endsWith('"') && v.length > 1) ||
    (v.startsWith("'") && v.endsWith("'") && v.length > 1)
  ) {
    v = v.slice(1, -1).trim();
  }

  if (v.length === 0 || v.includes(PLACEHOLDER)) return null;

  // ~ / ~\ expansion
  if (v === "~") {
    v = os.homedir();
  } else if (v.startsWith("~/") || v.startsWith("~\\")) {
    v = path.join(os.homedir(), v.slice(2));
  }

  // drop trailing separators (but keep a bare root like "/" or "C:\")
  while (v.length > 3 && (v.endsWith("/") || v.endsWith("\\"))) {
    v = v.slice(0, -1);
  }

  if (v.length === 0) return null;

  try {
    return path.resolve(v);
  } catch {
    return null;
  }
}

/** First non-comment, non-empty line of the config file. */
function readConfigFile() {
  let text;
  try {
    text = readFileSync(CONFIG_FILE, "utf8");
  } catch {
    return null;
  }
  for (const line of text.split(/\r?\n/)) {
    const t = line.trim();
    if (t.length === 0 || t.startsWith("#")) continue;
    return t;
  }
  return null;
}

/** @returns {string|null} absolute path to the game repo, or null. */
export function resolveProjectPath() {
  const fromEnv = normalizePath(process.env.UNITY_AGENT_PROJECT_PATH);
  if (fromEnv) return fromEnv;
  return normalizePath(readConfigFile());
}
