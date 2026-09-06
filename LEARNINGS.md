# LEARNINGS

Insights, gotchas and decisions from promoting the confix JavaScript port to a
first-class, spec-conformant implementation. Newest first.

## 2.1.0 — applyBlock, sh/ relocation, demo file I/O

- **A minor release needs a real change.** The port already matched the oracle,
  so a JS 2.1.0 with an identical tarball would be a hollow republish. Added one
  genuine additive API — `applyBlock(text, block, opts)` (= parseCommandBlock +
  apply) — which both justifies the minor and powers the demo's load→apply→save
  flow. The bash 2.1.0 is honestly labelled a restructure/maintenance release
  (no behavior change); both share the 2.1.0 line for parity.
- **Relocating `confix` → `sh/confix` kept the install URL stable** by having
  `release.yml` copy `sh/confix` to the release-asset name `confix`. Only the
  three path constants + the workflow guards needed touching — the test cases use
  a `confix()` helper, so they didn't hardcode the path.
- **Demo file I/O works on GitHub Pages** (it's a real page, not a Claude
  Artifact): `<input type="file">` + FileReader to load, `Blob` + `<a download>`
  to save. Both would be inert inside an Artifact sandbox, but this is Pages.
- **Docs stayed the single source:** `docs/confix.js` is regenerated from
  `js/src/confix.js` via `npm run build:docs` and CI-guarded, so adding
  `applyBlock` to the core automatically reached the demo.

## Hardened the conformance suite (48 fixtures)

- **Fuzzed the JS core against the oracle on 20 edge cases the original 32
  fixtures didn't cover** — empty values via `>key=` / `key=`, multi-char and
  regex-special separators (`::`, `.`) and comment chars (`//`, `*`), tabs around
  the separator, values starting with an operator char, append-after-blank-line.
  **Zero divergences**, byte-exact. The port needed no fix; promoted 16 of these
  to committed fixtures so a future refactor of either implementation can't
  regress them.
- **Harness bug worth remembering:** a quick `node -e` comparison that passed the
  module path as a trailing CLI arg (`node -e '...' JS=...`) left `process.env.JS`
  undefined, so every JS run crashed and *looked* like a total divergence. Env
  vars must prefix the command; a trailing arg becomes `process.argv`, not env.
- **`$(...)` masks trailing-newline diffs** (command substitution strips them),
  so the ad-hoc fuzz couldn't see NL-only differences — but the committed
  fixtures assert byte-exact via `cmp` (bash) and `assert.equal` (JS), which do.

## Published to npm + Trusted Publishing

- **`@budhash/confix@2.0.0` is live on npm** (first publish done manually with
  `npm publish --access public`). `@budhash` is a *user scope* — no npm org
  needed, because the npm username is `budhash`.
- **2FA is enforced for publishing.** A plain CLI publish 403'd
  ("Two-factor authentication ... required"); the publish went through via npm's
  browser auth flow (`npm publish` prints an `auth/cli` URL). `--otp=` is the
  other route.
- **Switched CI to Trusted Publishing (OIDC), per npm's own recommendation** over
  long-lived tokens: `release-npm.yml` publishes with no `NPM_TOKEN` — GitHub
  Actions mints a short-lived OIDC token npm verifies against the package's
  configured trusted publisher (repo + workflow). Provenance is automatic; the
  `id-token: write` permission was already in place. Needs npm >= 11.5.1, so the
  workflow upgrades npm first (node 20 ships npm 10).
- **First-publish chicken-and-egg:** npm attaches a trusted publisher to an
  *existing* package, so the very first release was a manual bootstrap; every
  future `js-v*` tag publishes token-lessly.

## PR6 — README

- **Documented the JS library + CLI beside the bash script**, and added a
  "Specification and parity" section explaining the SPEC + oracle-generated
  conformance suite that keeps the two in lockstep. Reframed the summary from
  "a bash script" to "two implementations that behave identically".
- **Honest about publish state:** the package isn't on npm yet (publish pending
  approval), so the README says so and points readers at `js/src/confix.js` to
  vendor directly in the meantime, rather than implying `npm install` works.

## PR5 — docs demo as a live tool over the library

- **The demo already consumed the library's API** (`confix.apply` /
  `confix.parseCommandBlock`); the only duplication was `docs/confix.js` being a
  hand-copy. Fix: make it a **generated, byte-identical vendor** of
  `js/src/confix.js` via `npm run build:docs`, with a CI guard (`diff`) that
  fails if they drift. One source of truth, zero build step for Pages.
- **Byte-identical, no banner.** Adding a "generated" banner to `docs/confix.js`
  would break the trivial `diff` guard, so the "don't edit" note lives in
  `docs/README.md` and the build script instead of in the file.
- No page redesign: the dark theme and "the tool" / "playground" structure are
  untouched — this PR only changes where the demo's code comes from.

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
