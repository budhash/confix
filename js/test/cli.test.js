// Node CLI behaviors that don't depend on the bash oracle: exit codes, stdin
// routing, dry-run output shape, and the "never writes" guarantees.
"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const { spawnSync } = require("node:child_process");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

const CLI = path.join(__dirname, "..", "bin", "confix.js");

function run(args, { input, cwd } = {}) {
  return spawnSync(process.execPath, [CLI, ...args], { input, cwd, encoding: "utf8" });
}

function tmpFile(content) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "confix-cli-"));
  const file = path.join(dir, "app.props");
  fs.writeFileSync(file, content);
  return { dir, file, read: () => fs.readFileSync(file, "utf8") };
}

test("-h prints usage and exits 0", () => {
  const r = run(["-h"]);
  assert.equal(r.status, 0);
  assert.match(r.stdout, /Usage: confix/);
  assert.match(r.stdout, /!key\s+delete the key's line/);
});

test("missing input file exits non-zero with an error", () => {
  const r = run(["-f", "/no/such/file.props", "a=1"]);
  assert.notEqual(r.status, 0);
  assert.match(r.stderr, /file not found/);
});

test("stdin with no -f writes the result to stdout", () => {
  const r = run(["a=9", ">c=3"], { input: "a=1\nb=2\n" });
  assert.equal(r.status, 0);
  assert.equal(r.stdout, "a=9\nb=2\nc=3\n");
});

test("in-place edit writes nothing to stdout", () => {
  const t = tmpFile("a=1\nb=2\n");
  const r = run(["-f", t.file, "a=9"]);
  assert.equal(r.status, 0);
  assert.equal(r.stdout, "");
  assert.equal(t.read(), "a=9\nb=2\n");
  fs.rmSync(t.dir, { recursive: true, force: true });
});

test("-o- prints to stdout and leaves the input file untouched", () => {
  const t = tmpFile("a=1\nb=2\n");
  const r = run(["-o-", "-f", t.file, "a=9"]);
  assert.equal(r.stdout, "a=9\nb=2\n");
  assert.equal(t.read(), "a=1\nb=2\n", "input must be unchanged");
  fs.rmSync(t.dir, { recursive: true, force: true });
});

test("-d prints a unified diff with labels and does not modify the input", () => {
  const t = tmpFile("a=1\nb=2\n");
  const r = run(["-d", "-f", t.file, "a=9"]);
  assert.equal(r.status, 0);
  assert.match(r.stdout, new RegExp(`^--- ${t.file.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}`, "m"));
  assert.match(r.stdout, /^\+\+\+ .*\(confix\)$/m);
  assert.match(r.stdout, /^@@ /m);
  assert.match(r.stdout, /^-a=1$/m);
  assert.match(r.stdout, /^\+a=9$/m);
  assert.equal(t.read(), "a=1\nb=2\n", "dry run must not modify the input");
  fs.rmSync(t.dir, { recursive: true, force: true });
});

test("-d with no changes prints nothing", () => {
  const t = tmpFile("a=1\n");
  const r = run(["-d", "-f", t.file, "absent=9"]);
  assert.equal(r.status, 0);
  assert.equal(r.stdout, "");
  fs.rmSync(t.dir, { recursive: true, force: true });
});
