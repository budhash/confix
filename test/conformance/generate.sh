#!/bin/bash
# --------------------------------------------------------------------
#
# generate.sh - fill every fixture's `expected` field from the ORACLE
#
# --------------------------------------------------------------------
# USAGE:
#
#   ./test/conformance/generate.sh
#
# Run this after adding a fixture or changing an existing fixture's
# `input` / `commands` / `sep` / `comment`, and after any *intentional*
# change to the bash script's behavior. It runs the real `confix` script
# against each fixture and stores the result as the golden `expected`.
#
# NEVER hand-edit `expected`: it is defined by the oracle, on purpose, so
# the fixtures cannot encode a guess that both implementations then agree
# with. If the oracle output looks wrong, fix the script, not the fixture.
# --------------------------------------------------------------------

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/lib.sh"

shopt -s nullglob

count=0
for fx in "$__CONF_FIXTURES"/*.json; do
    out=$(mktemp "${TMPDIR:-/tmp}/confix-gen.XXXXXX")
    conf::oracle "$fx" "$out"

    tmp=$(mktemp "${TMPDIR:-/tmp}/confix-fx.XXXXXX")
    # --rawfile reads the oracle output as a string, exact bytes and all,
    # and stores it as .expected without reformatting the rest of the file
    jq --rawfile expected "$out" '.expected = $expected' "$fx" > "$tmp" && mv "$tmp" "$fx"

    rm -f "$out"
    count=$((count + 1))
    echo "  regenerated $(basename "$fx")"
done

echo "regenerated $count fixture(s) from the oracle: $__CONF_SCRIPT"
