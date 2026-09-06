// Conformance: the JS core must reproduce every shared fixture's `expected`
// output — the same fixtures the bash oracle is checked against. This is what
// keeps the two implementations in lockstep. See ../../test/conformance/.
"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const confix = require("../src/confix.js");

const FIXTURES = path.join(__dirname, "..", "..", "test", "conformance", "fixtures");

const files = fs
  .readdirSync(FIXTURES)
  .filter((f) => f.endsWith(".json"))
  .sort();

assert.ok(files.length > 0, "no conformance fixtures found — is the suite present?");

for (const file of files) {
  const fx = JSON.parse(fs.readFileSync(path.join(FIXTURES, file), "utf8"));
  test(`conformance: ${fx.name}`, () => {
    const got = confix.apply(fx.input, fx.commands, { sep: fx.sep, comment: fx.comment });
    assert.equal(
      got,
      fx.expected,
      `${fx.desc}\n  commands: ${JSON.stringify(fx.commands)}` +
        `\n  sep=${JSON.stringify(fx.sep)} comment=${JSON.stringify(fx.comment)}`
    );
  });
}
