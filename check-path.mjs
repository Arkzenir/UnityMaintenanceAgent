#!/usr/bin/env node
/**
 * Confirms PROJECT_PATH.txt points at a real Unity project.
 * Run before your first session if you want to be sure:  node check-path.mjs
 */
import { existsSync, readFileSync } from "node:fs";
import path from "node:path";
import { resolveProjectPath, CONFIG_FILE } from "./hooks/project-path.mjs";

const repo = resolveProjectPath();

if (!repo) {
  console.error("✗ No project path configured.");
  console.error(`  Open ${path.basename(CONFIG_FILE)} and paste your Unity project path.`);
  process.exit(1);
}

console.log(`Configured path: ${repo}`);

if (!existsSync(repo)) {
  console.error("✗ That folder does not exist. Check for typos or a stray character.");
  process.exit(1);
}

const missing = ["Assets", "ProjectSettings"].filter(
  (d) => !existsSync(path.join(repo, d))
);

if (missing.length > 0) {
  console.error(`✗ Missing ${missing.join(" and ")} — this is not a Unity project root.`);
  console.error("  You may have pointed at the Assets folder or a parent folder.");
  process.exit(1);
}

const versionFile = path.join(repo, "ProjectSettings", "ProjectVersion.txt");
let version = "unknown";
if (existsSync(versionFile)) {
  const m = readFileSync(versionFile, "utf8").match(/m_EditorVersion:\s*(\S+)/);
  if (m) version = m[1];
}

console.log(`✓ Valid Unity project root (Unity ${version}).`);
console.log("  Ready — start the agent.");
