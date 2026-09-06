# Changelog

All notable changes to confix. The bash script and the `@budhash/confix`
JavaScript package share a version line and are kept behaviorally identical by a
shared [SPEC.md](SPEC.md) and [conformance suite](test/conformance/).

Releases are tagged per channel: `vX.Y.Z` cuts the bash script's GitHub Release;
`js-vX.Y.Z` publishes the npm package.

## [2.1.0]

### Added
- **`applyBlock(text, block, opts)`** in the JavaScript library — parse a
  command block (one command per line, like an `-e` file) and apply it in a
  single call. Equivalent to `apply(text, parseCommandBlock(block, comment), opts)`.
- **Web demo:** load a config file from disk and download the edited result,
  entirely in the browser; the demo now uses `applyBlock` and documents the npm
  library + CLI alongside the bash tool.

### Changed
- **Repository layout:** the bash tool moved to **`sh/confix`** to mirror `js/`.
  The published release asset is still named `confix`, so the install URL
  (`releases/latest/download/confix`) is unchanged. Only undocumented raw links
  to `.../main/confix` are affected (now `.../main/sh/confix`).
- Hardened the conformance suite to 48 fixtures (added empty-value, multi-char
  and regex-special separators/comment chars, tab handling, and more).

### Notes
- No change to the command grammar or edit behavior — the bash `2.1.0` release is
  a maintenance/restructure release, and the JS `2.1.0` adds only the additive
  `applyBlock` convenience. Behavior remains as specified for `2.0.0`.

## [2.0.0]

### Added
- **`@budhash/confix`** — the JavaScript port promoted to a first-class,
  published package: a zero-dependency, zero-build library (Node + browser) and
  a cross-platform CLI mirroring the bash flags, plus a shared spec and
  conformance suite guaranteeing byte-for-byte parity with the bash script.

### Changed
- The bash script reached `2.0.0` (stable): adds `!key` delete, `-d` dry-run
  diff, and stdin support over the `1.x` line.
