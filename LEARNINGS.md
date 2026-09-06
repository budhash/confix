# LEARNINGS

Insights, gotchas and decisions from promoting the confix JavaScript port to a
first-class, spec-conformant implementation. Newest first.

## PR2 — promote the JS port to `@budhash/confix`

- **Zero-build, dual-consumable from one UMD core.** `js/src/confix.js` keeps the
  port's `module.exports = api` / `root.confix` shape, so it is the CommonJS
  `require` target *and* the browser global with no bundler. A ~4-line
  `confix.mjs` shim re-exports the named API for native ESM `import`. The
  `package.json` `exports` map wires `import`→`.mjs`, `require`→`.js`,
  `types`→hand-written `confix.d.ts`.
- **Node can't statically see named exports from this CJS core** (it assigns an
  object built from variables), which is exactly why the `.mjs` shim imports the
  default and re-exports names — don't point ESM consumers straight at the CJS.
- **`node --test` is the whole test runner** — no devDependencies, no lockfile.
  The JS conformance test reads the same `test/conformance/fixtures/*.json` the
  bash oracle uses (39 JS tests: 32 conformance + 7 API). One contract, two
  implementations.
- **npm packaging gotchas:** `npm pack --dry-run` to verify shipped files;
  `files` didn't include a LICENSE, so a copy was placed at `js/LICENSE` (npm
  only bundles a LICENSE from the package dir). `repository.directory: "js"`
  points npm at the subdir.
- **Temporary duplication:** `docs/confix.js` still exists alongside
  `js/src/confix.js` during this window; PR5 rewires the demo onto the built
  library and removes the copy. They are byte-identical bodies today.

## PR1 — SPEC + conformance harness

- **The bash script is the oracle, and `expected` is generated from it.** The
  conformance fixtures never hand-encode expected output; `generate.sh` runs
  the real `confix` to produce it. This makes it impossible for a fixture to
  bless a wrong answer that both implementations then agree with. If the oracle
  output looks wrong, the fix goes in the script, not the fixture.
- **`jq -j` (not `-r`) for reading `input`/`expected`.** `jq -r` appends a
  trailing newline, which would corrupt every "no trailing newline" fixture.
  Comparisons are done byte-for-byte with `cmp` against temp files, never via
  `$(...)` (command substitution strips trailing newlines too).
- **The JS port already matches all 32 oracle fixtures** with no changes — good
  news for PR2: it is a promotion, not a repair.
- **`main` was far ahead of a stale local `origin/main`.** The repo's real work
  (v2.0.0 script with `!`/`-d`/stdin, `test/cases/*`, GitHub Actions, and the
  `docs/` web demo) lives on `main`; `master` is an old, inert refactor. Always
  `git fetch` before trusting local refs. All promotion work branches off
  `origin/main`.
- **Portability: bash 3.2.** The conformance scripts avoid `mapfile`/`declare -A`
  and guard `"${arr[@]}"` under `set -u` with a length check, matching the
  script's own macOS-system-bash target.
- **Package name.** `confix` is taken on npm by an unrelated package; the JS
  library will publish as `@budhash/confix` (CLI bin still `confix`).
