# confix — behavior specification

**Spec version: 2.1.0** — tracks `__APPVERSION` in the `sh/confix` script.
(Behavior is unchanged from 2.0.0; the 2.1.0 line is a repository restructure
plus the additive `applyBlock` library convenience, neither of which changes the
edit semantics defined here.)

This document is the canonical description of what `confix` does. The bash
script `confix` is the **reference implementation (the oracle)**: where this
prose and the script disagree, the script wins and this document is the bug —
_unless_ the script's behavior is itself a defect, in which case the fix goes
in the script and this spec follows.

Every rule here is pinned by the shared, language-agnostic conformance suite in
[`test/conformance/`](test/conformance/): each fixture's `expected` output is
generated **from the oracle**, and every implementation — the bash script and
the JavaScript port — must reproduce it byte-for-byte. A behavior that is not
covered by a fixture is not guaranteed.

---

## 1. Model

`confix` edits line-oriented configuration files shaped like
`key<separator>value` — `.properties`, YAML, INI, `log4j.properties`,
`php.ini`, and anything similar. It is a **text-to-text transform**: given the
contents of a file, a separator, a comment character, and an ordered list of
commands, it produces the new contents of the file.

The pure core of every implementation is this transform. The CLIs (`confix`
the script, and the Node CLI) add file I/O, stdin/stdout, and the `-d` diff
around that core.

- **Separator** (`-s`, default `=`): the character between a key and its value
  _in the file_.
- **Comment character** (`-c`, default `#`): the character that marks a line as
  commented out.

The separator and comment character are matched **literally**, not as regular
expressions.

## 2. Command grammar

Each command is one string. Its **first character** selects the operation:

| Command      | Operation  | Meaning                                                            |
| ------------ | ---------- | ------------------------------------------------------------------ |
| `key=value`  | update     | update an existing key; **no-op if the key is absent**             |
| `>key=value` | add / set  | update the key, or **append** `key<sep>value` if it is absent      |
| `>key`       | uncomment  | uncomment an existing key; no-op if absent                         |
| `<key`       | comment    | comment the key out (the line is kept, not removed); no-op if absent |
| `!key`       | delete     | delete the key's line entirely (active **or** commented); no-op if absent |

### 2.1 Key/value split

A command's key and value are split on the **first `=` in the command**, and
_only_ the first. This is independent of the file separator `-s`.

- `"jdbc.url=a;MODE=b"` → key `jdbc.url`, value `a;MODE=b`.
- With `-s ':'`, the command is still `key=value` (split on `=`); the file is
  written with `:` as the separator.

The leading operator character (`>`, `<`, `!`) is stripped **before** the
split. A value supplied to `!key` (e.g. `!key=whatever`) is ignored — deletion
is by key.

An empty key (a command that is just an operator, or empty) is a no-op.

## 3. Key state

For a given key, separator and comment character, a line is one of:

- **active** — the key, optionally preceded by blanks, followed by blanks and
  the separator: `^[[:blank:]]*key[[:blank:]]*<sep>`.
- **commented** — as above but with one or more comment characters (and
  optional blanks) before the key: `^[[:blank:]]*(<comment>)*[[:blank:]]*key[[:blank:]]*<sep>`.
- **absent** — neither.

`[[:blank:]]` is spaces **and** tabs. A key is considered present if _any_ line
matches; "active" takes precedence over "commented" when deciding state.

## 4. Operations in detail

### 4.1 update — `key=value`

- If the key is **absent**: no-op.
- If the key is **commented**: it is first uncommented (§4.3), then updated.
- The value replaces everything after the captured `key<sep>` prefix. The
  existing blanks around the key and separator are **preserved** via the
  capture; only the value changes. Example (`-s ':'`):
  `"  key : val"` + `key=new` → `"  key : new"`.
- **Every** occurrence of the key is rewritten, not just the first (the
  transform is line-oriented). This is deliberate and tested.

### 4.2 add / set — `>key=value`

- If the key is **absent**: append it to the end of the file as
  `key<sep>value` (no blanks around the separator). See §5 for newline rules.
- If the key **exists** (active or commented): behaves exactly like update
  (§4.1) — commented keys are uncommented and set; nothing is appended.
- `>key` with **no value** is the uncomment operation (§4.3), _not_ an append:
  a bare `>key` never adds a new key.

### 4.3 uncomment — `>key`

- If the key is **absent** or already **active**: no-op.
- Otherwise the leading blanks, comment character(s), and the blanks between
  them and the key are removed, so `"  #a=1"` → `"a=1"`. The `key<sep>` portion
  and everything after it are preserved.

### 4.4 comment — `<key`

- Only an **active** key is affected. A single comment character is prepended
  to the line: `"a=1"` → `"#a=1"`.
- If the key is **absent** or already **commented**: no-op.

### 4.5 delete — `!key`

- Removes **every** line on which the key is present, whether active or
  commented.
- If the key is **absent**: no-op.
- Matches the key literally (`!a.b[0]` removes `a.b[0]=v` but not `axb=v`).

## 5. Newlines and appending

- The transform preserves the input's trailing-newline state for edits that do
  not append.
- **Appending** a new key (§4.2) puts the key on its own line and ensures the
  file ends with a single trailing newline. No blank separator line is inserted
  between existing content and the appended key, and appending several keys in
  a row introduces no blank lines. Appending to a file with **no** trailing
  newline still places the new key on its own line
  (`"existing=1"` + `>brand.new=hello` → `"existing=1\nbrand.new=hello\n"`).
- Appending to an **empty** file yields `key<sep>value\n`.

## 6. Batch application and ordering

- Multiple commands are applied **in the order given**, each to the result of
  the previous one. A later command sees the effect of earlier ones (e.g.
  `>fresh=1` then `fresh=2` leaves `fresh=2`).
- The same ordering applies to commands read from an external file (`-e`).

## 7. External command file (`-e`)

One command per line. A line is **skipped** when, after stripping leading
blanks:

- it is empty, or
- its **first non-blank character** is the comment character. A comment
  character appearing later in the line (e.g. inside a URL or value) is data,
  not a comment.

Leading blanks on a kept command are stripped before it is executed. The last
line is processed even if the file has no trailing newline. Lines are read
literally (backslashes are preserved).

## 8. CLI surface (the tools)

These belong to the command-line tools (`confix` and the Node CLI), not the
pure core:

| Flag | Meaning                                                                             |
| ---- | ----------------------------------------------------------------------------------- |
| `-f` | input file. `-f -`, or omitting `-f`, reads from **stdin**.                          |
| `-o` | output file. `-o-` writes the result to **stdout** and leaves the input untouched.  |
| `-d` | **dry run**: print a unified diff of what would change and write nothing.           |
| `-e` | external command file (§7).                                                          |
| `-s` | separator character (default `=`).                                                  |
| `-c` | comment character (default `#`).                                                     |
| `-h` | print usage and exit 0.                                                              |

Behavior:

- With no `-f` (or `-f -`), the config is read from stdin and the result is
  written to stdout unless `-o` names a file (or `-d` is given).
- Without `-o`, an edit is applied **in place** to the input file.
- `-o-` and `-d` never modify the input file.
- `-d` output is a unified diff labelled `--- <name>` / `+++ <name> (confix)`;
  a no-op dry run prints nothing. `-d` is the one feature that shells out to
  `diff`.

## 9. Non-goals / explicitly undefined

- Commands must be passed **individually quoted**; word-splitting of a single
  command by the shell is the caller's responsibility.
- Behavior for a value or key containing a newline is undefined (commands are
  single-line).
- The comment character used for detection/commenting is a single character;
  multi-character comment markers are not supported.
