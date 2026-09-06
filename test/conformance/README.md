# conformance suite

A shared, language-agnostic contract that keeps every implementation of confix
— the bash script and the JavaScript port — in lockstep with the behavior
described in [`SPEC.md`](../../SPEC.md).

## How it works

Each file in [`fixtures/`](fixtures/) is one edit, as JSON:

```json
{
  "name":     "update-existing-key",
  "desc":     "plain key=value updates an active key in place",
  "sep":      "=",
  "comment":  "#",
  "commands": ["environment=prod"],
  "input":    "environment=dev\n",
  "expected": "environment=prod\n"
}
```

`expected` is **generated from the bash script (the oracle)** — never written
by hand. The oracle is the source of truth; the fixtures capture what it
actually does, so a fixture can never encode a guess that the implementations
then happily agree with. If the oracle's output looks wrong, fix the script,
not the fixture.

## Running

```bash
./test/conformance/run-bash.sh          # assert the bash oracle matches every fixture
VERBOSE=1 ./test/conformance/run-bash.sh # also list passing fixtures
```

Run on both Linux (GNU sed) and macOS (BSD sed) in CI, so a platform
difference is caught even though the fixtures were generated on one machine.

The JavaScript port runs the same fixtures from its own package (`js/`), so the
two implementations are validated against one identical contract.

## Adding or changing a fixture

1. Add or edit the fixture JSON (set `input`, `commands`, `sep`, `comment`;
   leave `expected` as `""`).
2. Regenerate the golden output from the oracle:
   ```bash
   ./test/conformance/generate.sh
   ```
3. Run `./test/conformance/run-bash.sh` and the JS conformance test; both must
   pass.

Only regenerate `expected` after an **intentional** change to the script's
behavior — a diff in `expected` on an unrelated change is a red flag.

## Requirements

`jq` (to read the JSON fixtures). It is preinstalled on the GitHub runners;
locally, `brew install jq` or `apt-get install jq`.
