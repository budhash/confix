#!/bin/bash
# --------------------------------------------------------------------
#
# run-tests.sh - test runner for confix
#
# --------------------------------------------------------------------
# USAGE:
#
#   ./test/run-tests.sh                  run every test
#   ./test/run-tests.sh -f update        run tests matching "update"
#   ./test/run-tests.sh -s 02-update     run one case file
#   ./test/run-tests.sh -l               list tests without running
#   ./test/run-tests.sh -v               show output of passing tests
#
# exits 0 when everything passed, 1 when anything failed.
# --------------------------------------------------------------------

set -u

readonly __APPNAME=$( basename "${BASH_SOURCE[0]}" )
readonly __BASEDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

readonly __TESTDIR=$__BASEDIR
readonly __DATADIR=$__BASEDIR/data
readonly __CASEDIR=$__BASEDIR/cases
readonly __CODEDIR=$__BASEDIR/..
readonly __SCRIPT=$__CODEDIR/sh/confix

FILTER=""
SUITE=""
VERBOSE=false
LIST_ONLY=false
NO_COLOR=false

source "$__BASEDIR/lib/testlib.sh"

function _usage() {
    cat << EOF
Usage: $__APPNAME [OPTIONS]
Options:
-------
    -h              show this message
    -f <pattern>    only run tests whose name matches <pattern>
    -s <pattern>    only run case files whose name matches <pattern>
    -l              list matching tests and exit
    -v              print output of passing tests too
    -n              disable coloured output
EOF
}

function _parse_args() {
    while getopts "hf:s:lvn" OPTION; do
        case "$OPTION" in
            h) _usage; exit 0;;
            f) FILTER=$OPTARG;;
            s) SUITE=$OPTARG;;
            l) LIST_ONLY=true;;
            v) VERBOSE=true;;
            n) NO_COLOR=true;;
            ?) _usage 1>&2; exit 1;;
        esac
    done
}

function _preflight() {
    [ -f "$__SCRIPT" ] || { echo "[error]: confix not found at $__SCRIPT" 1>&2; exit 1; }
    [ -d "$__CASEDIR" ] || { echo "[error]: no case directory at $__CASEDIR" 1>&2; exit 1; }

    # a syntax error in confix would make every test fail with the same
    # unhelpful message - catch it up front instead
    if ! bash -n "$__SCRIPT" 2>/dev/null; then
        echo "[error]: confix has a syntax error:" 1>&2
        bash -n "$__SCRIPT" 1>&2
        exit 1
    fi
}

function _main() {
    _parse_args "$@"
    tl::colors
    _preflight

    __RUNDIR=$(mktemp -d "${TMPDIR:-/tmp}/confix-tests.XXXXXX")
    trap '_cleanup' EXIT INT TERM

    local _cases=()
    local _file
    for _file in "$__CASEDIR"/*.sh; do
        [ -f "$_file" ] || continue
        [ -n "$SUITE" ] && [[ "$( basename "$_file" )" != *"$SUITE"* ]] && continue
        _cases+=("$_file")
    done

    if [ ${#_cases[@]} -eq 0 ]; then
        echo "[error]: no case files matched" 1>&2
        exit 1
    fi

    [ "$LIST_ONLY" == "true" ] || tl::log "${C_BOLD}confix test suite${C_RESET} ${C_DIM}[bash ${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]} on $(uname -s)]${C_RESET}"

    local _label _test
    for _file in "${_cases[@]}"; do
        _label=$( basename "$_file" .sh )

        # case files are sourced into the runner, so they can use every
        # helper in testlib.sh directly
        # shellcheck source=/dev/null
        source "$_file"

        local _tests=()
        while IFS= read -r _test; do
            [ -z "$_test" ] && continue
            [ -n "$FILTER" ] && [[ "$_test" != *"$FILTER"* ]] && continue
            _tests+=("$_test")
        done < <(tl::discover "$_file")

        [ ${#_tests[@]} -eq 0 ] && continue

        if [ "$LIST_ONLY" == "true" ]; then
            for _test in "${_tests[@]}"; do echo "$_label :: $_test"; done
            continue
        fi

        tl::log ""
        tl::log "${C_BOLD}$_label${C_RESET}"
        for _test in "${_tests[@]}"; do
            tl::run_test "$_test" "$_label"
        done

        # forget this file's tests so a name reused across case files
        # cannot be run twice
        for _test in "${_tests[@]}"; do unset -f "$_test"; done
    done

    [ "$LIST_ONLY" == "true" ] && exit 0

    _summary
}

function _summary() {
    tl::log ""
    tl::log "${C_BOLD}summary${C_RESET}"
    tl::log "  ${C_GREEN}passed:${C_RESET}  $TESTS_PASSED"
    tl::log "  ${C_RED}failed:${C_RESET}  $TESTS_FAILED"
    tl::log "  ${C_YELLOW}skipped:${C_RESET} $TESTS_SKIPPED"
    tl::log "  total:   $TESTS_RUN"

    if [ $TESTS_FAILED -gt 0 ]; then
        tl::log ""
        tl::log "${C_RED}failing tests:${C_RESET}"
        local _name
        for _name in "${FAILED_NAMES[@]}"; do
            tl::log "  - $_name"
        done
        exit 1
    fi

    if [ $TESTS_RUN -eq 0 ]; then
        tl::log "${C_RED}no tests ran${C_RESET}"
        exit 1
    fi

    exit 0
}

function _cleanup() {
    [ -n "${__RUNDIR:-}" ] && rm -rf "$__RUNDIR"
}

_main "$@"
