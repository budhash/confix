// confix — a faithful JavaScript port of the confix config-file editor's core.
//
// This is the canonical JS implementation. It is a pure text-to-text transform
// (no filesystem, no I/O) that mirrors the sed/grep semantics of the bash
// `confix` script, which remains the reference ORACLE: both implementations are
// validated against one shared conformance suite (test/conformance/), and where
// they disagree the bash script wins. See SPEC.md for the full contract.
//
// Runs anywhere — Node (CommonJS `require`, or ESM via ./confix.mjs) and the
// browser (as the `confix` global). The Node CLI and the web demo both consume
// this same core, so there is one source of truth.
//
// Command grammar (first char selects the op; key/value split on the FIRST '='
// in the command, independent of the file separator):
//   key=value    update an existing key (no-op if absent)
//   >key=value   set the key, appending it if absent
//   >key         uncomment an existing key
//   <key         comment out an existing key
//   !key         delete the key's line (active or commented)
(function (root) {
  "use strict";

  function reEsc(s) {
    return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  }

  function splitLines(text) {
    const hadNL = text.endsWith("\n");
    const body = hadNL ? text.slice(0, -1) : text;
    const lines = text.length === 0 ? [] : body.split("\n");
    return { lines, hadNL };
  }
  function joinLines(lines, hadNL) {
    return lines.join("\n") + (hadNL && lines.length ? "\n" : "");
  }

  // command "key=value" splits on the FIRST '=' only
  function parseCmd(s) {
    const i = s.indexOf("=");
    if (i === -1) return { key: s, val: "", hasEq: false };
    return { key: s.slice(0, i), val: s.slice(i + 1), hasEq: true };
  }

  function patterns(key, sep, comment) {
    const K = reEsc(key), S = reEsc(sep), C = reEsc(comment);
    const b = "[ \\t]";
    return {
      active: new RegExp("^" + b + "*" + K + b + "*" + S),
      commented: new RegExp("^" + b + "*(?:" + C + ")*" + b + "*" + K + b + "*" + S),
      // update: capture leading blanks + key + blanks + sep + blanks; drop the rest
      update: new RegExp("^(" + b + "*" + K + b + "*" + S + b + "*).*$"),
      // uncomment: strip leading blanks + comments + blanks before (key blanks sep)
      uncomment: new RegExp("^" + b + "*(?:" + C + ")*" + b + "*(" + K + b + "*" + S + ")"),
    };
  }

  function status(lines, p) {
    if (lines.some((l) => p.active.test(l))) return 1; // exists, uncommented
    if (lines.some((l) => p.commented.test(l))) return 2; // exists, commented
    return 0; // absent
  }

  function removeComment(lines, p) {
    return lines.map((l) => l.replace(p.uncomment, "$1"));
  }
  function addComment(lines, p, comment) {
    return lines.map((l) => (p.active.test(l) ? comment + l : l));
  }
  function updateValue(lines, p, val) {
    return lines.map((l) => l.replace(p.update, (_m, g1) => g1 + val));
  }

  function applyOne(state, cmd, sep, comment) {
    let { lines, hadNL } = state;
    let op = "update", body = cmd;
    if (cmd[0] === ">") { op = "add"; body = cmd.slice(1); }
    else if (cmd[0] === "<") { op = "comment"; body = cmd.slice(1); }
    else if (cmd[0] === "!") { op = "delete"; body = cmd.slice(1); }

    const { key, val, hasEq } = parseCmd(body);
    if (!key) return { lines, hadNL };
    const p = patterns(key, sep, comment);

    if (op === "update") {
      if (status(lines, p) === 2) lines = removeComment(lines, p);
      lines = updateValue(lines, p, val);
    } else if (op === "add") {
      if (!hasEq) {
        lines = removeComment(lines, p);
      } else if (status(lines, p) === 0) {
        lines = lines.slice();
        lines.push(key + sep + val);
        hadNL = true;
      } else {
        if (status(lines, p) === 2) lines = removeComment(lines, p);
        lines = updateValue(lines, p, val);
      }
    } else if (op === "comment") {
      if (status(lines, p) === 1) lines = addComment(lines, p, comment);
    } else if (op === "delete") {
      lines = lines.filter((l) => !p.commented.test(l));
    }
    return { lines, hadNL };
  }

  // apply a list of commands (strings) to text; returns the new text.
  function apply(text, commands, opts) {
    opts = opts || {};
    const sep = opts.sep != null && opts.sep !== "" ? opts.sep : "=";
    const comment = opts.comment != null && opts.comment !== "" ? opts.comment : "#";
    let state = splitLines(text);
    for (const raw of commands) {
      const cmd = raw; // caller pre-filters blanks/comment lines if desired
      if (cmd === "") continue;
      state = applyOne(state, cmd, sep, comment);
    }
    return joinLines(state.lines, state.hadNL);
  }

  // parse a multi-line command block like an -e file: one command per line,
  // skip blanks and lines whose first non-blank char is the comment char.
  function parseCommandBlock(block, comment) {
    comment = comment || "#";
    const out = [];
    for (const line of block.split("\n")) {
      const trimmed = line.replace(/^[ \t]+/, "");
      if (trimmed === "") continue;
      if (trimmed[0] === comment) continue;
      out.push(trimmed);
    }
    return out;
  }

  const api = { apply, parseCommandBlock, _reEsc: reEsc };
  if (typeof module !== "undefined" && module.exports) module.exports = api;
  else root.confix = api;
})(typeof self !== "undefined" ? self : this);
