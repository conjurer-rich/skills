#!/usr/bin/env node
// Run `claude plugin validate --json` over the plugin and the marketplace and
// fail on any error or warning, except one: CLAUDE.md at the plugin root is
// "not loaded as project context". That file is the guide for working on this
// repository (AGENTS.md points at it), not context the plugin ships, so the
// warning is expected. `--strict` cannot express that exception.
//
// Usage: node scripts/validate-plugin.mjs [claude command]   (default: claude)

import { execFileSync } from "node:child_process";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const [cmd, ...cmdArgs] = (process.argv[2] ?? "claude").split(" ");
const expected = /^CLAUDE\.md at the plugin root is not loaded as project context/;

let failures = 0;
for (const target of [".claude-plugin/plugin.json", "."]) {
  let report;
  try {
    report = execFileSync(cmd, [...cmdArgs, "plugin", "validate", "--json", target], { cwd: root, encoding: "utf8" });
  } catch (error) {
    report = error.stdout;
    if (!report) throw error;
  }
  const { manifest, contents = [] } = JSON.parse(report);
  for (const part of [manifest, ...contents].filter(Boolean)) {
    for (const e of part.errors ?? []) {
      console.error(`error   ${part.file}: ${e.path}: ${e.message}`);
      failures++;
    }
    for (const w of part.warnings ?? []) {
      if (expected.test(w.message)) continue;
      console.error(`warning ${part.file}: ${w.path}: ${w.message}`);
      failures++;
    }
  }
}
if (failures) {
  console.error(`${failures} plugin validation problem(s)`);
  process.exit(1);
}
console.log("plugin and marketplace manifests are valid");
