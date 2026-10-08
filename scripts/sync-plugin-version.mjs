#!/usr/bin/env node
// Copy the release version into the plugin manifest.
//
// `changeset version` bumps package.json only. Claude Code detects a
// marketplace plugin update from the manifest's `version` field before it
// looks at git commits, so a manifest left behind pins every installed copy
// to an old release. release.yml runs this right after `changeset version`,
// so the "chore: version packages" PR carries both bumps.
//
// The manifest is rewritten in place with a targeted replacement rather than
// JSON.stringify, so its formatting (one-line keywords array) survives.

import { readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const releaseFile = resolve(root, "package.json");
const manifestFile = resolve(root, ".claude-plugin/plugin.json");

const { version } = JSON.parse(readFileSync(releaseFile, "utf8"));
if (typeof version !== "string" || version.length === 0) {
  console.error(`${releaseFile}: no version`);
  process.exit(1);
}

const manifest = readFileSync(manifestFile, "utf8");
const versionLine = /^(\s*"version":\s*")[^"]*(",?)$/m;
if (!versionLine.test(manifest)) {
  console.error(`${manifestFile}: no "version" line to update`);
  process.exit(1);
}

const updated = manifest.replace(versionLine, `$1${version}$2`);
if (updated === manifest) {
  console.log(`plugin.json already at ${version}`);
} else {
  writeFileSync(manifestFile, updated);
  console.log(`plugin.json -> ${version}`);
}
