#!/usr/bin/env node
// Vendor the canonical core into docs/ so the web demo — served statically by
// GitHub Pages, with no build step — runs the exact same code the npm package
// ships. docs/confix.js is GENERATED from js/src/confix.js and must stay
// byte-identical to it; CI enforces that. Regenerate with:
//
//   cd js && npm run build:docs
"use strict";

const fs = require("node:fs");
const path = require("node:path");

const src = path.join(__dirname, "..", "src", "confix.js");
const dst = path.join(__dirname, "..", "..", "docs", "confix.js");

fs.copyFileSync(src, dst);
console.log(`vendored ${path.relative(process.cwd(), src)} -> ${path.relative(process.cwd(), dst)}`);
