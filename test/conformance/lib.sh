#!/bin/bash
# --------------------------------------------------------------------
#
# lib.sh - shared helpers for the confix conformance harness
#
# --------------------------------------------------------------------
# DESCRIPTION:
#
# A "fixture" is a language-agnostic JSON file describing one edit:
#
#   {
#     "name":     "update-existing-key",
#     "desc":     "plain key=value updates an active key in place",
#     "sep":      "=",
#     "comment":  "#",
#     "commands": ["environment=prod"],
#     "input":    "environment=dev\n",
#     "expected": "environment=prod\n"
#   }
#
# The bash script (the ORACLE) is run against `input` + `commands`, and
# its resulting file is the ground truth stored in `expected`. Every
# implementation - the bash script itself and the JavaScript port - must
# reproduce `expected` byte-for-byte.
#
#   generate.sh   fills `expected` FROM the oracle (never hand-edit it)
#   run-bash.sh   asserts the oracle still reproduces every `expected`
#   ../../js       the JS conformance test asserts the port matches
#
# This file is sourced by generate.sh and run-bash.sh; it is not meant
# to be executed directly.
# --------------------------------------------------------------------

set -u

readonly __CONF_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
readonly __CONF_ROOT="$( cd "$__CONF_DIR/../.." && pwd )"
readonly __CONF_SCRIPT="$__CONF_ROOT/confix"
readonly __CONF_FIXTURES="$__CONF_DIR/fixtures"

command -v jq >/dev/null 2>&1 || {
    echo "conformance: jq is required to read the JSON fixtures" 1>&2
    echo "             install it with 'brew install jq' or 'apt-get install jq'" 1>&2
    exit 2
}

##
# @info     run the bash oracle against a fixture, writing the resulting
#           file bytes to <output_file> exactly (trailing newline preserved,
#           or preserved-absent). jq -j is used for input/output so no
#           spurious trailing newline is introduced by the harness.
# @usage    conf::oracle <fixture.json> <output_file>
##
function conf::oracle() {
    local _fx="$1" _out="$2"

    local _sep _comment
    _sep=$(jq -r '.sep // "="' "$_fx")
    _comment=$(jq -r '.comment // "#"' "$_fx")

    local _work
    _work=$(mktemp "${TMPDIR:-/tmp}/confix-conf.XXXXXX")
    jq -j '.input' "$_fx" > "$_work"

    # read the command list into an array, one command per element
    local _cmds=() _c
    while IFS= read -r _c; do _cmds+=("$_c"); done < <(jq -r '.commands[]' "$_fx")

    # edit the file in place, exactly as a caller would on the command line
    if [ ${#_cmds[@]} -gt 0 ]; then
        bash "$__CONF_SCRIPT" -s "$_sep" -c "$_comment" -f "$_work" "${_cmds[@]}" >/dev/null 2>&1
    else
        bash "$__CONF_SCRIPT" -s "$_sep" -c "$_comment" -f "$_work" >/dev/null 2>&1
    fi

    cat "$_work" > "$_out"
    rm -f "$_work"
}
