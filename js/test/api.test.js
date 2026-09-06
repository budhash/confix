// Unit tests for the public API surface and both consumption paths (CommonJS
// require and native ESM import).
"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const cjs = require("../src/confix.js");

test("apply: defaults sep/comment to = and #", () => {
  assert.equal(cjs.apply("a=1\n", ["a=2"]), "a=2\n");
  assert.equal(cjs.apply("#a=1\n", ["a=2"]), "a=2\n");
});

test("apply: empty command list returns the input unchanged", () => {
  assert.equal(cjs.apply("a=1\n", []), "a=1\n");
});

test("apply: honours a custom separator and comment char", () => {
  assert.equal(cjs.apply("a: 1\n", ["a=2"], { sep: ":" }), "a: 2\n");
  assert.equal(cjs.apply(";a=1\n", ["a=2"], { comment: ";" }), "a=2\n");
});

test("parseCommandBlock: skips blanks and comment lines, strips leading blanks", () => {
  const block = ["  a=1", "", "# a comment", "  >b", "!c"].join("\n");
  assert.deepEqual(cjs.parseCommandBlock(block), ["a=1", ">b", "!c"]);
});

test("parseCommandBlock: a comment char inside a value is data, not a comment", () => {
  assert.deepEqual(cjs.parseCommandBlock("url=http://h/#frag"), ["url=http://h/#frag"]);
});

test("parseCommandBlock: honours a custom comment char", () => {
  assert.deepEqual(cjs.parseCommandBlock(["a=1", ";skip", "b=2"].join("\n"), ";"), [
    "a=1",
    "b=2",
  ]);
});

test("applyBlock: parses a command block and applies it in one call", () => {
  const block = ["port=9090", "# a comment", ">debug=true", "", "!obsolete"].join("\n");
  const input = "port=8080\n#debug=false\nobsolete=1\n";
  assert.equal(
    cjs.applyBlock(input, block),
    cjs.apply(input, cjs.parseCommandBlock(block), {}),
    "applyBlock should equal apply(parseCommandBlock(...))"
  );
  assert.equal(cjs.applyBlock(input, block), "port=9090\ndebug=true\n");
});

test("applyBlock: honours custom sep and comment (comment lines in the block are skipped)", () => {
  // the ";..." line in the command block is a comment and is skipped; the file
  // uses ":" as its separator
  const out = cjs.applyBlock("a: 1\n", "; set a\na=2", { sep: ":", comment: ";" });
  assert.equal(out, "a: 2\n");
});

test("ESM entry re-exports the named API", async () => {
  const esm = await import("../src/confix.mjs");
  assert.equal(typeof esm.apply, "function");
  assert.equal(typeof esm.applyBlock, "function");
  assert.equal(typeof esm.parseCommandBlock, "function");
  assert.equal(esm.apply("a=1\n", ["a=2"]), "a=2\n");
  assert.equal(esm.applyBlock("a=1\n", "a=2"), "a=2\n");
  assert.equal(esm.default.apply, cjs.apply);
});
