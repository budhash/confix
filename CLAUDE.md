# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this project is

`confix` is a single, dependency-free Bash script that edits configuration
files in place — properties, YAML, INI, `log4j.properties`, `php.ini`, and
anything else shaped like `key<separator>value`. It is designed to be
`curl`-ed onto a box and run, so **the whole tool is one file: `confix`**.

There is no build step, no package manifest and no runtime dependency beyond
`bash`, `sed`, `grep` and `cat`.

```
confix                      the entire tool
test/run-tests.sh           test runner
test/lib/testlib.sh         test harness (assertions, sandboxing)
test/cases/*.sh             test cases, one file per area
test/data/                  fixture config files
.github/workflows/           CI: ci (push), pr (checks + guards), release (tags)
```

## Running the tests

```bash
./test/run-tests.sh              # everything
./test/run-tests.sh -f update    # only tests whose name matches "update"
./test/run-tests.sh -s 03-add    # only one case file
./test/run-tests.sh -l           # list tests without running them
./test/run-tests.sh -v           # show output from passing tests too
./test/run-tests.sh -n           # no colour (for logs)
```

Exits 0 when everything passed, 1 otherwise. Always run the full suite before
committing — it is fast (a couple of seconds) and there is no other safety net.

## The command language

Every positional argument (and every line of a `-e` file) is one command. The
first character selects the operation:

| Command      | Meaning                                                        |
| ------------ | -------------------------------------------------------------- |
| `key=value`  | update an existing key; **no-op if the key is absent**          |
| `>key=value` | set the key, appending it to the end of the file if absent      |
| `>key`       | uncomment an existing key; no-op if absent                      |
| `<key`       | comment the key out (the line is kept, not deleted)             |

Flags: `-f` input file, `-o` output file (`-o-` prints to stdout and leaves
the input alone), `-e` external command file, `-s` separator (default `=`),
`-c` comment character (default `#`).

## Architecture notes

* **`common::*` functions** (lines ~44-170) are a vendored, general-purpose
  Bash prelude — logging, OS/arch detection, string helpers. They are shared
  boilerplate across the author's scripts. Keep the `common::` block
  self-contained; don't entangle it with confix-specific logic.
* **`__map_commands`** picks the right `sed` invocation at runtime. GNU sed
  and BSD/macOS sed disagree about in-place editing, so macOS gets
  `sed -i .$__TIMESTAMP` (writing a backup that `main` later moves to `/tmp`).
  **Any change to a `sed` call must be checked on both platforms** — this has
  broken twice before (issues #3, #5).
* **`_rexists_config`** is the key-state oracle and returns `0` absent,
  `1` present, `2` present-but-commented. `_update_config`, `_add_config` and
  `_remove_config` all branch on it.
* **`_parse_cmd`** splits a command into key/value on the first `=` only
  (setting `__pkey` / `__pval` / `__phaseq`); **`_escape_re`** and
  **`_escape_repl`** make a string safe on the pattern and replacement sides
  of a `sed` command. Keys always go through `_escape_re`; the separator and
  comment char are pre-escaped once in `main` as `$__sep_re` / `$__cc_re`.
* **`main "$@"` on the last line** is what actually runs the tool. It was
  accidentally commented out in the 2021 refactor (commit `43cd08b`), which
  turned confix into a silent no-op for every release since. `bash -n` cannot
  catch this — the test suite can, and does.

## Working on this codebase

* **Keep it a single file.** Don't split `confix` into modules or add a
  library directory; the install story is `curl > confix; chmod +x confix`.
* **Keep it dependency-free.** No `awk` gymnastics that need gawk, no
  `python`, no test framework to install. The test harness is deliberately
  hand-rolled bash for this reason.
* **Match the existing style**: four-space indent, `function name() {`,
  `local` for every variable, `_private` / `__module_level` naming, and the
  `##` doc-comment block above non-trivial functions.
* **Never edit `test/data/` fixtures.** Tests assert against their exact
  contents; several also depend on whether a fixture ends with a trailing
  newline. Add a new fixture instead, or build a file inline with `make_file`.
* Portability target is Bash 3.2 (the macOS system bash), so avoid `declare -A`,
  `${var^^}` and other Bash 4+ syntax in `confix` itself.

## Writing tests

A test is any function named `test_*` in a file under `test/cases/`. The
runner discovers them automatically — no registration needed. Each test runs
in its own subshell inside its own temporary directory, so tests cannot see
each other's files.

```bash
function test_update_existing_key() {
    fixture simple.properties                       # stage a file from test/data
    confix -f simple.properties "environment=prod"  # sets $stdout/$stderr/$status
    assert_success
    assert_line simple.properties "environment=prod"
}
```

Helpers: `fixture`, `make_file` (heredoc into the sandbox), `confix`, `run`,
`skip`, `fail`, and assertions `assert_eq` / `assert_ne` / `assert_success` /
`assert_failure` / `assert_status` / `assert_contains` / `assert_not_contains` /
`assert_line` / `assert_no_line` / `assert_same_file` / `assert_unchanged` /
`assert_file_exists` / `assert_file_missing` / `assert_line_count`.

`assert_unchanged` compares a file against the pristine snapshot taken by
`fixture` or `make_file` — the cleanest way to assert a no-op.

## Behaviour notes and fixed regressions

`test/cases/08-regressions.sh` guards behaviour that used to be broken and was
pinned as "known limitations". These are now fixed; the tests assert the
correct behaviour so the fixes cannot silently regress. When touching the
matching/escaping logic, keep these in mind:

* **Values may contain spaces and extra separators.** Commands are split into
  key/value on the *first* `=` only (`_parse_cmd`), so `"key=hello world"` and
  `"jdbc.url=a;MODE=b"` are preserved. Callers must pass each command quoted.
* **Keys are matched literally, not as regexes.** `_escape_re` escapes the key
  (and the separator / comment char) before it goes into a `sed`/`grep`
  pattern, so `a.b` no longer also matches `axb`.
* **`-c` is honoured everywhere.** Detection (`_rexists_config`), commenting
  (`_add_comment`) and uncommenting (`_remove_comment`) all use `$__comment_char`
  (pre-escaped as `$__cc_re`), so a `;`-commented key is correctly detected,
  uncommented and updated in place.
* **Blanks around the key/separator match spaces *and* tabs** — patterns use
  `[[:blank:]]*`, and the existing whitespace is preserved via the capture group.
* **`-h` prints usage and exits 0**, so it works as a success-path smoke test.

The one behaviour deliberately kept: **every occurrence of a duplicate key is
rewritten**, not just the first (sed is line-oriented). This is tested, not
accidental.

## Repository conventions

* Development happens on feature branches; `main` is the release branch, and
  the `README.md` install URL points at raw `main`, so **anything merged to
  main is immediately live for every user**.
* Commit messages reference the issue they close (`fixes #6`).
* CI runs through GitHub Actions (see below).

## CI and releases

Three workflows, all running the suite on Linux **and** macOS because `confix`
selects a different `sed` invocation per platform:

* **`ci.yml`** - on pushes to `main` and `claude/**`. Syntax check + suite.
* **`pr.yml`** - on pull requests into `main`. Suite, advisory `shellcheck`,
  and a `guards` job that fails the PR if `confix` stops invoking `main "$@"`
  (the 2021 silent-no-op regression), stops being executable, or starts
  `source`-ing an external file. It warns when `test/data/` fixtures change.
* **`release.yml`** - on pushing a `v*` tag. Runs the suite on both platforms,
  smoke-tests the script the way the README tells users to, then **fails if the
  tag does not match `__APPVERSION` in `confix`**, and publishes a GitHub
  Release with `confix` and a SHA256 checksum attached.

Cutting a release:

```bash
# 1. bump __APPVERSION in confix (it is the source of truth)
# 2. commit, merge to main, then:
git tag v1.1 && git push origin v1.1
```
