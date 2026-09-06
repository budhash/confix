# LEARNINGS

Insights, gotchas and decisions from promoting the confix JavaScript port to a
first-class, spec-conformant implementation. Newest first.

## PR4 — npm packaging + tag-gated release

- **Two independent release channels.** The bash script releases on `v*` tags
  (GitHub Release); the npm package releases on `js-v*` tags (`release-npm.yml`).
  Keeping the tag namespaces separate lets the script and the package version on
  their own cadence and avoids one tag triggering both.
- **A tag alone can't leak a publish.** `release-npm.yml` publishes only with an
  `NPM_TOKEN` secret; without it the publish step fails. The workflow also
  re-checks `tag == js/package.json version` before publishing, mirroring the
  bash release's `__APPVERSION` guard.
- **Scoped packages need `publishConfig.access: "public"`** or npm refuses to
  publish `@budhash/*` publicly. `--provenance` + `id-token: write` gives npm
  provenance (public repo on GitHub Actions).
- **`prepublishOnly: node --test`** is a last-line safety so a local `npm publish`
  can't ship a broken build.
- No publish, no tag, no name reservation performed — that waits for explicit
  approval.

## PR3 — Node CLI + bash-vs-node parity

- **Hand-rolled getopts, not `util.parseArgs`.** To match the bash `getopts`
  contract exactly — attached short-option values (`-ofile`, `-s:`), `-o-`
  meaning the value `"-"`, clustering (`-df`), and *stopping at the first
  positional* (`shift $((OPTIND-1))`) — a small manual parser is clearer and
  more faithful than `parseArgs`, which permutes and doesn't take attached
  short values the same way.
- **Self-contained unified diff for `-d` (Windows-safe).** The bash tool shells
  out to `diff`; the Node CLI can't assume `diff` exists, so `-d` is an LCS-based
  unified diff (3 lines context, GNU-style `@@` headers, `,count` omitted when
  1). It byte-matches GNU `diff -u` for trailing-newline cases — verified by
  parity tests — so those assert byte-equality; no-trailing-newline cases (GNU's
  `\ No newline at end of file` marker) are intentionally left out of `-d`
  byte-parity.
- **Parity tests run both implementations on isolated copies.** In-place edits
  mutate the input, so bash and node each get their own fresh temp dir seeded
  with identical content; then stdout and resulting file bytes are compared. 13
  write-mode scenarios + 3 dry-run scenarios, all byte-identical. Guarded with
  `{ skip }` when bash/script are absent (Windows), so the suite still runs.
- **Command order:** `-e` file commands first (in file order), then argv
  commands — matching `main()` in the script.

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
