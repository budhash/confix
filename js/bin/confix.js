#!/usr/bin/env node
// confix — Node CLI. A cross-platform (Windows-safe) mirror of the bash
// `confix` script's command line: same flags, same stdin/stdout behavior, same
// `-d` unified diff. The actual edits come from the shared core in ../src, so
// the CLI is just I/O and routing around apply(). See SPEC.md §8.
"use strict";

const fs = require("node:fs");
const { apply, parseCommandBlock } = require("../src/confix.js");

const APPNAME = "confix";
const APPVERSION = require("../package.json").version;

const USAGE = `Usage: ${APPNAME} [OPTIONS]... [command1] [command2] ...
Options:
-------
    -h  show this message
    -f <file_name>
        file to modify. "-" (or omitting -f) reads the config from stdin
        and, unless -o names a file, writes the result to stdout
    -o <output_file>
        default behavior is to edit the input file in place.
        "-" prints the result to stdout without updating the input
    -d  dry run: print a unified diff of what would change and write nothing
    -e <external_command_file>
        read edit commands from a file, one command per line
    -s <separator_character>   default "="
    -c <comment_character>     default "#"

Commands:
--------
    each positional argument (and each line of a -e file) is one command;
    the first character selects the operation:

    key=value       update an existing key (no action if the key is absent)
    >key=value      set the key, appending it to the file if it is absent
    >key            uncomment an existing key
    <key            comment out an existing key (the line is kept)
    !key            delete the key's line entirely (active or commented)`;

function die(msg) {
  process.stderr.write(`[error]: ${msg}\n`);
  process.exit(1);
}

// --------------------------------------------------------------------
// argument parsing — mirrors getopts "hdf:o:e:s:c:" + shift: options come
// first, parsing stops at the first non-option token (or "--"). Short options
// take their value attached (-ofile), as the rest of the cluster, or as the
// next argument (-o file), and "-o-" yields the value "-".
// --------------------------------------------------------------------
function parseArgs(argv) {
  const opts = {
    dryrun: false,
    inputFile: "-",
    outputFile: "",
    configFile: "",
    sep: "=",
    comment: "#",
    commands: [],
  };
  const takesValue = { f: "inputFile", o: "outputFile", e: "configFile", s: "sep", c: "comment" };

  let i = 0;
  for (; i < argv.length; i++) {
    const tok = argv[i];
    if (tok === "--") {
      i++;
      break;
    }
    if (tok[0] !== "-" || tok === "-") break; // first positional -> stop

    let j = 1;
    let consumedValue = false;
    for (; j < tok.length && !consumedValue; j++) {
      const o = tok[j];
      if (o === "h") {
        process.stdout.write(`${APPNAME} ${APPVERSION}, modify/update configuration files\n${USAGE}\n`);
        process.exit(0);
      } else if (o === "d") {
        opts.dryrun = true;
      } else if (takesValue[o]) {
        let val = tok.slice(j + 1);
        if (val === "") {
          val = argv[++i];
          if (val === undefined) die(`option -${o} requires an argument\n${USAGE}`);
        }
        opts[takesValue[o]] = val;
        consumedValue = true;
      } else {
        die(`illegal option -${o}\n${USAGE}`);
      }
    }
  }
  opts.commands = argv.slice(i);
  return opts;
}

// --------------------------------------------------------------------
// unified diff (self-contained, no external `diff`) for -d. LCS-based, three
// lines of context, GNU-style @@ hunk headers. Returns "" when nothing changed.
// --------------------------------------------------------------------
function toLines(text) {
  const endsNL = text.endsWith("\n");
  const body = endsNL ? text.slice(0, -1) : text;
  return text === "" ? [] : body.split("\n");
}

function diffOps(a, b) {
  const n = a.length, m = b.length;
  const dp = [];
  for (let i = 0; i <= n; i++) dp.push(new Int32Array(m + 1));
  for (let i = n - 1; i >= 0; i--) {
    for (let j = m - 1; j >= 0; j--) {
      dp[i][j] = a[i] === b[j] ? dp[i + 1][j + 1] + 1 : Math.max(dp[i + 1][j], dp[i][j + 1]);
    }
  }
  const ops = [];
  let i = 0, j = 0;
  while (i < n && j < m) {
    if (a[i] === b[j]) { ops.push([" ", a[i]]); i++; j++; }
    else if (dp[i + 1][j] >= dp[i][j + 1]) { ops.push(["-", a[i]]); i++; }
    else { ops.push(["+", b[j]]); j++; }
  }
  while (i < n) ops.push(["-", a[i++]]);
  while (j < m) ops.push(["+", b[j++]]);
  return ops;
}

function fmtRange(start, count) {
  if (count === 0) return `${start},0`;
  if (count === 1) return `${start}`;
  return `${start},${count}`;
}

function unifiedDiff(aText, bText, aLabel, bLabel, context) {
  const C = context == null ? 3 : context;
  const ops = diffOps(toLines(aText), toLines(bText));

  const changed = [];
  for (let k = 0; k < ops.length; k++) if (ops[k][0] !== " ") changed.push(k);
  if (changed.length === 0) return "";

  // group changed ops that are within 2*C+1 of each other into one hunk
  const groups = [];
  let s = 0;
  while (s < changed.length) {
    let e = s;
    while (e + 1 < changed.length && changed[e + 1] - changed[e] <= 2 * C + 1) e++;
    groups.push([Math.max(0, changed[s] - C), Math.min(ops.length - 1, changed[e] + C)]);
    s = e + 1;
  }

  const out = [`--- ${aLabel}`, `+++ ${bLabel}`];
  for (const [from, to] of groups) {
    let aBefore = 0, bBefore = 0;
    for (let k = 0; k < from; k++) {
      if (ops[k][0] !== "+") aBefore++;
      if (ops[k][0] !== "-") bBefore++;
    }
    let aCount = 0, bCount = 0;
    for (let k = from; k <= to; k++) {
      if (ops[k][0] !== "+") aCount++;
      if (ops[k][0] !== "-") bCount++;
    }
    const aStart = aCount === 0 ? aBefore : aBefore + 1;
    const bStart = bCount === 0 ? bBefore : bBefore + 1;
    out.push(`@@ -${fmtRange(aStart, aCount)} +${fmtRange(bStart, bCount)} @@`);
    for (let k = from; k <= to; k++) out.push(ops[k][0] + ops[k][1]);
  }
  return out.join("\n") + "\n";
}

// --------------------------------------------------------------------
// main
// --------------------------------------------------------------------
function main() {
  const o = parseArgs(process.argv.slice(2));

  // read the input (stdin when "-", otherwise the named file)
  let text;
  let srcName;
  const fromStdin = o.inputFile === "-";
  if (fromStdin) {
    srcName = "(stdin)";
    try {
      text = fs.readFileSync(0, "utf8");
    } catch (_e) {
      text = "";
    }
  } else {
    if (!fs.existsSync(o.inputFile)) {
      die(`file not found : [-f ${o.inputFile}] - please specify file to be updated`);
    }
    srcName = o.inputFile;
    text = fs.readFileSync(o.inputFile, "utf8");
  }

  // commands: those from a -e file first (in file order), then the argv ones
  let commands = [];
  if (o.configFile) {
    if (!fs.existsSync(o.configFile)) die(`external config file not found : [-e ${o.configFile}]`);
    commands = parseCommandBlock(fs.readFileSync(o.configFile, "utf8"), o.comment);
  }
  commands = commands.concat(o.commands);

  const modified = apply(text, commands, { sep: o.sep, comment: o.comment });

  // route the result
  if (o.dryrun) {
    process.stdout.write(unifiedDiff(text, modified, srcName, `${srcName} (confix)`));
  } else if (o.outputFile === "-") {
    process.stdout.write(modified);
  } else if (o.outputFile) {
    fs.writeFileSync(o.outputFile, modified);
  } else if (fromStdin) {
    process.stdout.write(modified);
  } else {
    fs.writeFileSync(o.inputFile, modified); // in place
  }
}

main();
