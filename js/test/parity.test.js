// Parity: the Node CLI must produce byte-for-byte the same result as the bash
// `confix` script for the same inputs and arguments. Each scenario runs through
// BOTH implementations on identical, isolated copies of the input and compares
// the captured artifact (stdout, or the resulting file bytes).
//
// Skipped when bash or the script is unavailable (e.g. on Windows) — the CI
// `js library` job runs on Linux, where both are present.
"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const { spawnSync } = require("node:child_process");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

const SCRIPT = path.join(__dirname, "..", "..", "sh", "confix"); // the bash oracle
const CLI = path.join(__dirname, "..", "bin", "confix.js"); // the node CLI

const bashOk = spawnSync("bash", ["-c", "exit 0"]).status === 0;
const scriptOk = fs.existsSync(SCRIPT);
const SKIP = !bashOk || !scriptOk;
const skipReason = !bashOk ? "bash not available" : "confix script not found";

function mkdir() {
  return fs.mkdtempSync(path.join(os.tmpdir(), "confix-parity-"));
}

// run one implementation in its own fresh dir seeded with `files`; return
// { stdout, status, files } where files maps name -> bytes after the run.
function runImpl(kind, files, args, stdin) {
  const dir = mkdir();
  for (const [name, content] of Object.entries(files)) {
    fs.writeFileSync(path.join(dir, name), content);
  }
  const argv = kind === "bash" ? [SCRIPT, ...args] : [CLI, ...args];
  const bin = kind === "bash" ? "bash" : process.execPath;
  const res = spawnSync(bin, argv, {
    cwd: dir,
    input: stdin == null ? undefined : stdin,
    encoding: "utf8",
  });
  const after = {};
  for (const name of Object.keys(files)) after[name] = fs.readFileSync(path.join(dir, name), "utf8");
  // also read any extra files a scenario may have produced
  for (const name of fs.readdirSync(dir)) {
    if (!(name in after)) after[name] = fs.readFileSync(path.join(dir, name), "utf8");
  }
  fs.rmSync(dir, { recursive: true, force: true });
  return { stdout: res.stdout, status: res.status, files: after };
}

// each scenario: what the two implementations must agree on
const scenarios = [
  {
    name: "update in place",
    files: { "app.props": "a=1\nb=2\n" },
    args: ["-f", "app.props", "a=9"],
    compare: { file: "app.props" },
  },
  {
    name: "add appends a new key",
    files: { "app.props": "existing=1\n" },
    args: ["-f", "app.props", ">brand.new=hello"],
    compare: { file: "app.props" },
  },
  {
    name: "append to file without trailing newline",
    files: { "app.props": "existing=1" },
    args: ["-f", "app.props", ">brand.new=hello"],
    compare: { file: "app.props" },
  },
  {
    name: "stdin to stdout (default)",
    files: {},
    stdin: "a=1\nb=2\n",
    args: ["a=9", ">c=3"],
    compare: { stdout: true },
  },
  {
    name: "-o- prints to stdout and leaves input unchanged",
    files: { "app.props": "a=1\nb=2\n" },
    args: ["-o-", "-f", "app.props", "<a"],
    compare: { stdout: true, file: "app.props" },
  },
  {
    name: "-o writes to a different file",
    files: { "app.props": "a=1\n" },
    args: ["-o", "out.props", "-f", "app.props", ">c=3"],
    compare: { file: "out.props" },
  },
  {
    name: "external -e command file",
    files: { "app.props": "a=1\nb=2\n#c=3\n", "cmds.cf": "# edits\na=9\n>c\n!b\n" },
    args: ["-e", "cmds.cf", "-f", "app.props"],
    compare: { file: "app.props" },
  },
  {
    name: "custom separator -s :",
    files: { "app.yaml": "k: 1\nother: 2\n" },
    args: ["-s", ":", "-f", "app.yaml", "k=9"],
    compare: { file: "app.yaml" },
  },
  {
    name: "custom comment -c ;",
    files: { "app.ini": ";a=1\nb=2\n" },
    args: ["-c", ";", "-f", "app.ini", ">a"],
    compare: { file: "app.ini" },
  },
  {
    name: "delete active and duplicate keys",
    files: { "app.props": "dup=1\nkeep=9\ndup=2\n" },
    args: ["-f", "app.props", "!dup"],
    compare: { file: "app.props" },
  },
  {
    name: "multiple mixed ops in order",
    files: { "app.props": "a=1\nb=2\n#c=3\nd=4\n" },
    args: ["-f", "app.props", "a=9", ">c", "<b", "!d"],
    compare: { file: "app.props" },
  },
  {
    name: "attached short-option values (-oout -s:)",
    files: { "app.yaml": "k: 1\n" },
    args: ["-oout.yaml", "-s:", "-f", "app.yaml", ">n=v"],
    compare: { file: "out.yaml" },
  },
  {
    name: "value containing spaces and extra =",
    files: { "app.props": "jdbc.url=old\n" },
    args: ["-f", "app.props", "jdbc.url=a;MODE=b c"],
    compare: { file: "app.props" },
  },
];

for (const sc of scenarios) {
  test(`parity: ${sc.name}`, { skip: SKIP ? skipReason : false }, () => {
    const b = runImpl("bash", sc.files, sc.args, sc.stdin);
    const n = runImpl("node", sc.files, sc.args, sc.stdin);
    if (sc.compare.stdout) {
      assert.equal(n.stdout, b.stdout, "stdout differs between node and bash");
    }
    if (sc.compare.file) {
      assert.equal(
        n.files[sc.compare.file],
        b.files[sc.compare.file],
        `file ${sc.compare.file} differs between node and bash`
      );
    }
  });
}

// -d dry-run: node's self-contained unified diff matches GNU diff's for these
// trailing-newline cases, and neither writes the input.
const dryScenarios = [
  { name: "update", files: { "app.props": "a=1\nb=2\n" }, args: ["-d", "-f", "app.props", "a=9"] },
  { name: "delete", files: { "app.props": "a=1\nb=2\nc=3\n" }, args: ["-d", "-f", "app.props", "!b"] },
  {
    name: "add + comment",
    files: { "app.props": "a=1\nb=2\n" },
    args: ["-d", "-f", "app.props", ">c=3", "<a"],
  },
];

for (const sc of dryScenarios) {
  test(`parity (dry-run diff): ${sc.name}`, { skip: SKIP ? skipReason : false }, () => {
    const b = runImpl("bash", sc.files, sc.args);
    const n = runImpl("node", sc.files, sc.args);
    assert.equal(n.stdout, b.stdout, "dry-run diff differs between node and bash");
    assert.equal(n.files["app.props"], b.files["app.props"], "dry run must not modify the input");
  });
}
