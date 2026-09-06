#!/bin/bash
# --------------------------------------------------------------------
#
# run-bash.sh - assert the bash ORACLE reproduces every fixture
#
# --------------------------------------------------------------------
# USAGE:
#
#   ./test/conformance/run-bash.sh        run every fixture
#   VERBOSE=1 ./test/conformance/run-bash.sh   also list passing fixtures
#
# For each fixture, run the real `confix` script against input+commands
# and compare the result byte-for-byte with the stored `expected`. This
# pins the script's output as golden and - because CI runs it on both
# GNU sed (linux) and BSD sed (macos) - catches a platform difference or
# a future regression that the JSON was generated before.
#
# Exits 0 when every fixture matches, 1 otherwise.
# --------------------------------------------------------------------

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/lib.sh"

shopt -s nullglob

pass=0
failn=0
for fx in "$__CONF_FIXTURES"/*.json; do
    name=$(jq -r '.name' "$fx")

    out=$(mktemp "${TMPDIR:-/tmp}/confix-out.XXXXXX")
    exp=$(mktemp "${TMPDIR:-/tmp}/confix-exp.XXXXXX")
    conf::oracle "$fx" "$out"
    jq -j '.expected' "$fx" > "$exp"

    if cmp -s "$out" "$exp"; then
        pass=$((pass + 1))
        [ "${VERBOSE:-}" = "1" ] && echo "  ok   $name"
    else
        failn=$((failn + 1))
        echo "  FAIL $name"
        diff -u "$exp" "$out" | sed 's/^/      /'
    fi

    rm -f "$out" "$exp"
done

echo "conformance (bash): $pass passed, $failn failed"
[ "$failn" -eq 0 ]
