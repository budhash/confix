# @budhash/confix

A faithful JavaScript port of the [`confix`](https://github.com/budhash/confix)
config-file editor's core: update, add, comment, uncomment and delete keys in
`properties` / YAML / INI-style files. **Pure text-to-text, zero dependencies,
no build step** — runs in Node and the browser.

The bash `confix` script is the reference implementation; this library and the
script are validated against one shared [conformance suite](https://github.com/budhash/confix/tree/main/test/conformance),
so their edits match byte-for-byte. See
[SPEC.md](https://github.com/budhash/confix/blob/main/SPEC.md) for the full
behavior contract.

## Install

```sh
npm install @budhash/confix
```

## Usage

```js
// ESM
import { apply, applyBlock, parseCommandBlock } from "@budhash/confix";

// CommonJS
const { apply, applyBlock, parseCommandBlock } = require("@budhash/confix");

const input = "environment=dev\n#debug=false\n";

apply(input, ["environment=prod", ">debug", ">workers=4"]);
// => "environment=prod\ndebug=false\nworkers=4\n"
```

### `apply(text, commands, opts?) → string`

Applies an ordered list of commands to `text` and returns the new text. Each
command's first character selects the operation:

| Command      | Meaning                                                   |
| ------------ | --------------------------------------------------------- |
| `key=value`  | update an existing key (no-op if absent)                  |
| `>key=value` | set the key, appending it if absent                       |
| `>key`       | uncomment an existing key                                 |
| `<key`       | comment out an existing key (line kept)                   |
| `!key`       | delete the key's line entirely (active or commented)      |

The key/value split is on the **first `=`** in the command, independent of the
file separator.

`opts`:

- `sep` — separator between key and value in the file (default `"="`).
- `comment` — comment character (default `"#"`).

```js
apply("gc: 1000\n", ["gc=2001"], { sep: ":" });   // "gc: 2001\n"
apply(";debug=on\n", [">debug"], { comment: ";" }); // "debug=on\n"
```

### `applyBlock(text, block, opts?) → string`

Convenience: parse a command block (one command per line, like an `-e` file) and
apply it to `text` in one call. Equivalent to
`apply(text, parseCommandBlock(block, comment), opts)`.

```js
applyBlock("port=8080\n#debug=false\n", "port=9090\n>debug\n# a comment");
// => "port=9090\ndebug=false\n"
```

### `parseCommandBlock(block, comment?) → string[]`

Parses a multi-line command block the way an `-e` file is read: one command per
line, skipping blank lines and lines whose first non-blank character is the
comment character (a comment character *inside* a value is data). Leading blanks
on kept commands are stripped.

```js
parseCommandBlock("a=1\n# note\n  >b\n"); // ["a=1", ">b"]
```

## Command line

Installing the package provides a cross-platform `confix` command that mirrors
the [bash script](https://github.com/budhash/confix) flag-for-flag:

```sh
npx @budhash/confix -f app.properties "environment=prod" ">debug"

# stdin -> stdout
cat app.properties | npx @budhash/confix "environment=prod"

# preview changes without writing (unified diff)
npx @budhash/confix -d -f app.properties "environment=prod"
```

| Flag | Meaning                                                             |
| ---- | ------------------------------------------------------------------ |
| `-f` | input file. `-f -`, or omitting `-f`, reads stdin.                  |
| `-o` | output file. `-o-` prints to stdout and leaves the input untouched.|
| `-d` | dry run: print a unified diff and write nothing.                   |
| `-e` | external command file (one command per line).                     |
| `-s` | separator character (default `=`).                                |
| `-c` | comment character (default `#`).                                  |
| `-h` | show usage.                                                        |

Without `-o`, an edit is applied in place. The Node CLI is a self-contained
mirror of the bash tool (including its `-d` diff) and is validated against it by
byte-for-byte parity tests.

## In the browser

The core also attaches to the global as `confix` when loaded without a module
system:

```html
<script src="confix.js"></script>
<script>
  confix.apply("a=1\n", ["a=2"]); // "a=2\n"
</script>
```

## License

Apache-2.0
