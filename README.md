# confix
[![ci](https://github.com/budhash/confix/actions/workflows/ci.yml/badge.svg)](https://github.com/budhash/confix/actions/workflows/ci.yml)
[![release](https://img.shields.io/github/v/release/budhash/confix)](https://github.com/budhash/confix/releases/latest)
[![npm](https://img.shields.io/npm/v/@budhash/confix)](https://www.npmjs.com/package/@budhash/confix)

## Summary
a tiny config-file editor: update, add, comment, uncomment and delete keys in
`properties` / YAML / INI-style files. It ships as **two implementations that
behave identically** — a dependency-free **bash script** (`confix`) and a
**JavaScript port** (`@budhash/confix`: a zero-dependency library + CLI) — kept
in lockstep by a shared [specification](SPEC.md) and
[conformance suite](test/conformance/).

**Try it in your browser → [budhash.com/confix](https://budhash.com/confix)** — an
interactive playground that runs confix's command logic client-side, over the very
same JavaScript library.

## Status
Stable

## License
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

## Introduction
simple bash script to modify/update configuration files
 
See Usage and Examples for more details. 

## Installing

Download the latest released `confix` (branch-independent, always the most recent tag):

    curl -kL https://github.com/budhash/confix/releases/latest/download/confix > confix; chmod +x confix

Optionally verify the download against its published checksum:

    curl -kLO https://github.com/budhash/confix/releases/latest/download/confix.sha256
    shasum -a 256 -c confix.sha256

## Options

| Option | Meaning                                                                        |
| ------ | ------------------------------------------------------------------------------ |
| `-f`   | input file to modify; `-f -` (or omitting `-f`) reads stdin                     |
| `-o`   | output file; `-o-` prints to stdout and leaves the input file untouched         |
| `-d`   | dry run — print a unified diff of what would change and write nothing           |
| `-e`   | external command file (one command per line)                                   |
| `-s`   | separator character (default `=`)                                              |
| `-c`   | comment character (default `#`)                                               |
| `-h`   | show help                                                                      |

When neither `-o` nor an in-place file applies (i.e. reading from stdin), the result is written to stdout.

## Commands
Each positional argument (and each line of a `-e` file) is one command; the first character selects the operation:

| Command      | Meaning                                                       |
| ------------ | ------------------------------------------------------------- |
| `key=value`  | update an existing key (no action if the key is absent)       |
| `>key=value` | set the key, appending it to the file if it is absent         |
| `>key`       | uncomment an existing key                                     |
| `<key`       | comment out an existing key (the line is kept)                |
| `!key`       | delete the key's line entirely (active or commented)          |

## Examples
- remove (comment out) an existing config element

      ./confix -c '#' -s':' -f cassandra.yaml "<gc_warn_threshold_in_ms"

- delete a config element entirely (removes the line)

      ./confix -s':' -f cassandra.yaml "!gc_warn_threshold_in_ms"

- uncomment an existing config element (no action if the config key does not exist)

      ./confix -s':' -f cassandra.yaml ">concurrent_compactors"

- add a new config to the end of the file (or update existing config) 

      ./confix -s':' -f cassandra.yaml ">new_param=/some/val"

- update the value of an existing config element

      ./confix -s':' -f cassandra.yaml "gc_warn_threshold_in_ms=2001"

- multiple commands

      ./confix -s':' -f cassandra.yaml "gc_warn_threshold_in_ms=2001" ">concurrent_compactors" "commitlog_directory=/change/commitlog"

- prints the modifications to console without updating the original file

      ./confix -o- -f log4j.properties "log4j.logger.com.endeca.itl.web.metrics=DEBUG" 

- save the modifications to a different file

      ./confix -olog4j-dev.properties -f log4j.properties "log4j.logger.com.endeca.itl.web.metrics=DEBUG"

- read from stdin and write to stdout (pipe mode, `-f -` or no `-f`)

      cat log4j.properties | ./confix -f - "log4j.rootLogger=DEBUG,stdout" > log4j-dev.properties

- preview changes as a unified diff without writing (dry run)

      ./confix -d -f log4j.properties "log4j.rootLogger=DEBUG,stdout"

- specify the edit/update commands via external file (log4j.cf) instead of commandline

      ./confix -o- -e log4j.cf -f log4j.properties

- execute directly via curl + bash 

      curl -skL https://github.com/budhash/confix/releases/latest/download/confix | bash /dev/stdin -o- -f test/data/log4j.properties "log4j.rootLogger=DEBUG,stdout"
      curl -skL https://github.com/budhash/confix/releases/latest/download/confix | bash /dev/stdin -o- -e test/data/log4j.cf -f test/data/log4j.properties

## JavaScript library and CLI

The same behavior is available as a zero-dependency JavaScript package,
[`@budhash/confix`](https://www.npmjs.com/package/@budhash/confix) — usable as a
library (Node and the browser) and as a cross-platform CLI. It is a pure
text-to-text port of the bash script, validated against it (see
[parity](#specification-and-parity) below).

```sh
npm install @budhash/confix
```

**Library:**

```js
import { apply, applyBlock, parseCommandBlock } from "@budhash/confix"; // ESM
// const { apply, applyBlock, parseCommandBlock } = require("@budhash/confix"); // CommonJS

apply("environment=dev\n#debug=false\n", ["environment=prod", ">debug", ">workers=4"]);
// => "environment=prod\ndebug=false\nworkers=4\n"

apply("gc: 1000\n", ["gc=2001"], { sep: ":" }); // "gc: 2001\n"

// one call for a whole command block (like an -e file), skipping comment lines:
applyBlock("port=8080\n", "port=9090\n>debug=true"); // => "port=9090\ndebug=true\n"
```

- `apply(text, commands, { sep = "=", comment = "#" }) → string` — apply the
  commands (same grammar as above) to `text` and return the new text.
- `applyBlock(text, block, { sep, comment }) → string` — parse a command block
  (one command per line, like an `-e` file) and apply it in one call.
- `parseCommandBlock(block, comment = "#") → string[]` — split an `-e`-style
  block into commands, skipping blanks and comment lines.

**CLI** (mirrors the bash flags: `-f -o -d -e -s -c -h`, stdin/stdout):

```sh
npx @budhash/confix -f app.properties "environment=prod" ">debug"
cat app.properties | npx @budhash/confix "environment=prod"   # stdin -> stdout
npx @budhash/confix -d -f app.properties "environment=prod"   # dry-run diff
```

See [`js/README.md`](js/README.md) for the full library and CLI reference.

## Specification and parity

The behavior of confix is written down once, in [`SPEC.md`](SPEC.md), and pinned
by a shared, language-agnostic [conformance suite](test/conformance/): each
fixture's expected output is **generated from the bash script (the oracle)**, and
both implementations must reproduce it byte-for-byte. The bash script and the
JavaScript port run the *same* fixtures in CI (on GNU and BSD sed for bash), and
the Node CLI is additionally checked against the bash CLI by byte-for-byte parity
tests. So the two can never silently drift — if they disagree, the bash script
wins.

## Limitations
* The bash script is tested on macOS (Sierra and above) and Ubuntu; the
  JavaScript library and CLI are cross-platform (any Node ≥ 14, and the browser).

## Known Issues
* See [confix issues on GitHub](https://github.com/budhash/confix/issues) for open issues

## Authors / Contact
budhash (at) gmail

## Download
You can download this project in either [zip](http://github.com/budhash/confix/zipball/main) or [tar](http://github.com/budhash/confix/tarball/main) formats.

Or simply clone the project with [Git](http://git-scm.com/) by running:

    git clone git://github.com/budhash/confix

In a clone, the bash script lives at `sh/confix` and the JavaScript package at
`js/`. See [CHANGELOG.md](CHANGELOG.md) for release history.
 
