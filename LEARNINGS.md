# LEARNINGS

Insights, gotchas and decisions from promoting the confix JavaScript port to a
first-class, spec-conformant implementation. Newest first.

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
