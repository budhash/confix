#!/bin/bash
# --------------------------------------------------------------------
#
# testlib - minimal, dependency-free test harness for confix
#
# --------------------------------------------------------------------
# DESCRIPTION:
#
# provides test discovery hooks, per-test sandboxing and assertions.
# sourced by run-tests.sh - not meant to be executed directly.
#
# a test is any shell function named "test_*" declared in a case file
# under test/cases. each test runs in its own subshell, inside its own
# temporary working directory, so tests never see each other's files.
# --------------------------------------------------------------------

# --------------------------------------------------------------------
# state
# --------------------------------------------------------------------
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0
FAILED_NAMES=()

# exit code a test uses to report "skipped" rather than "failed"
readonly __SKIP_CODE=200

# --------------------------------------------------------------------
# output helpers
# --------------------------------------------------------------------
function tl::colors() {
    if [ "$NO_COLOR" == "true" ] || [ ! -t 1 ]; then
        C_RED= ; C_GREEN= ; C_YELLOW= ; C_DIM= ; C_BOLD= ; C_RESET=
    else
        C_RED=$'\033[31m'   ; C_GREEN=$'\033[32m'
        C_YELLOW=$'\033[33m'; C_DIM=$'\033[2m'
        C_BOLD=$'\033[1m'   ; C_RESET=$'\033[0m'
    fi
}

function tl::log()  { echo "$@" 1>&2; }
function tl::info() { echo "${C_DIM}$@${C_RESET}" 1>&2; }

# --------------------------------------------------------------------
# assertions
#
# every assertion aborts the current test on failure. tests run in a
# subshell, so "exit 1" ends only the test that failed.
# --------------------------------------------------------------------

##
# @info     abort the running test with a message
##
function fail() {
    echo "${C_RED}    assertion failed:${C_RESET} $*" 1>&2
    exit 1
}

##
# @info     abort the running test, reporting it as skipped
##
function skip() {
    echo "${C_YELLOW}    skipped:${C_RESET} ${*:-no reason given}" 1>&2
    exit $__SKIP_CODE
}

##
# @info     assert two strings are equal
# @usage    assert_eq <expected> <actual> [message]
##
function assert_eq() {
    local _expected="$1" _actual="$2" _msg="${3:-values differ}"
    if [ "$_expected" != "$_actual" ]; then
        fail "$_msg
      expected: [$_expected]
      actual:   [$_actual]"
    fi
}

##
# @info     assert two strings are not equal
##
function assert_ne() {
    local _unexpected="$1" _actual="$2" _msg="${3:-values should differ}"
    [ "$_unexpected" == "$_actual" ] && fail "$_msg
      both were: [$_actual]"
    return 0
}

##
# @info     assert the last "run" call exited with the given status
##
function assert_status() {
    local _expected="$1"
    assert_eq "$_expected" "$status" "unexpected exit status
      stdout: [$stdout]
      stderr: [$stderr]"
}

##
# @info     assert last run succeeded / failed
##
function assert_success() { assert_status 0; }
function assert_failure() {
    [ "$status" -eq 0 ] && fail "expected a non-zero exit status
      stdout: [$stdout]
      stderr: [$stderr]"
    return 0
}

##
# @info     assert a string contains / does not contain a substring
##
function assert_contains() {
    local _haystack="$1" _needle="$2"
    case "$_haystack" in
        *"$_needle"*) return 0;;
        *) fail "expected to find [$_needle] in:
$_haystack";;
    esac
}

function assert_not_contains() {
    local _haystack="$1" _needle="$2"
    case "$_haystack" in
        *"$_needle"*) fail "did not expect to find [$_needle] in:
$_haystack";;
    esac
    return 0
}

##
# @info     assert a file contains an exact line (whole line match)
# @usage    assert_line <file> <line>
##
function assert_line() {
    local _file="$1" _line="$2"
    [ -f "$_file" ] || fail "file not found: $_file"
    if ! grep -qxF -- "$_line" "$_file"; then
        fail "expected line [$_line] in $_file, file contains:
$(cat "$_file")"
    fi
}

##
# @info     assert a file does not contain an exact line
##
function assert_no_line() {
    local _file="$1" _line="$2"
    [ -f "$_file" ] || fail "file not found: $_file"
    if grep -qxF -- "$_line" "$_file"; then
        fail "did not expect line [$_line] in $_file"
    fi
}

##
# @info     assert two files have identical content
##
function assert_same_file() {
    local _a="$1" _b="$2"
    if ! diff -q "$_a" "$_b" >/dev/null 2>&1; then
        fail "files differ: $_a vs $_b
$(diff "$_a" "$_b" || true)"
    fi
}

##
# @info     assert a file is byte-identical to its pristine fixture copy
#           (fixtures are snapshotted by "fixture" into .orig/)
##
function assert_unchanged() {
    local _file="$1"
    [ -f ".orig/$_file" ] || fail "no pristine snapshot for $_file - use 'fixture' to stage it"
    assert_same_file ".orig/$_file" "$_file"
}

##
# @info     assert a file exists / does not exist
##
function assert_file_exists() {
    [ -f "$1" ] || fail "expected file to exist: $1"
}

function assert_file_missing() {
    [ -e "$1" ] && fail "expected file to be absent: $1"
    return 0
}

##
# @info     assert the number of lines in a file
##
function assert_line_count() {
    local _file="$1" _expected="$2"
    local _actual
    _actual=$(wc -l < "$_file" | tr -d ' ')
    assert_eq "$_expected" "$_actual" "unexpected line count in $_file"
}

# --------------------------------------------------------------------
# fixtures and execution
# --------------------------------------------------------------------

##
# @info     copy a fixture from test/data into the test sandbox and
#           snapshot it under .orig/ so assert_unchanged can compare
# @usage    fixture <name> [dest_name]
##
function fixture() {
    local _name="$1" _dest="${2:-$1}"
    [ -f "$__DATADIR/$_name" ] || fail "no such fixture: $_name"
    mkdir -p .orig
    cp -f "$__DATADIR/$_name" "./$_dest"
    cp -f "$__DATADIR/$_name" ".orig/$_dest"
}

##
# @info     write a file into the sandbox from stdin and snapshot it
# @usage    make_file <name> <<'EOF' ... EOF
##
function make_file() {
    local _name="$1"
    mkdir -p .orig
    cat > "./$_name"
    cp -f "./$_name" ".orig/$_name"
}

##
# @info     run confix, capturing stdout, stderr and exit status into
#           the $stdout / $stderr / $status variables
# @usage    confix <args...>
##
function confix() {
    run bash "$__SCRIPT" "$@"
}

##
# @info     run an arbitrary command, capturing stdout/stderr/status
# @usage    run <command> [args...]
##
function run() {
    local _out _err
    _out=$(mktemp "${TMPDIR:-/tmp}/confix-out.XXXXXX")
    _err=$(mktemp "${TMPDIR:-/tmp}/confix-err.XXXXXX")

    "$@" >"$_out" 2>"$_err"
    status=$?

    stdout=$(cat "$_out")
    stderr=$(cat "$_err")
    output="$stdout$stderr"
    rm -f "$_out" "$_err"
    return 0
}

# --------------------------------------------------------------------
# runner internals
# --------------------------------------------------------------------

##
# @info     execute a single test function in an isolated sandbox
# @usage    tl::run_test <function_name> <case_file_label>
##
function tl::run_test() {
    local _test="$1" _label="$2"
    local _sandbox="$__RUNDIR/$_test.$$"
    local _log="$__RUNDIR/$_test.log"

    TESTS_RUN=$((TESTS_RUN + 1))
    mkdir -p "$_sandbox"

    # each test gets its own subshell + working directory, so a test
    # that leaves files behind cannot influence the next one
    (
        cd "$_sandbox" || exit 1
        "$_test"
    ) >"$_log" 2>&1
    local _status=$?

    case $_status in
        0)
            TESTS_PASSED=$((TESTS_PASSED + 1))
            tl::log "${C_GREEN}  ok${C_RESET}   $_test"
            [ "$VERBOSE" == "true" ] && [ -s "$_log" ] && cat "$_log" 1>&2
            ;;
        $__SKIP_CODE)
            TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
            tl::log "${C_YELLOW}  skip${C_RESET} $_test"
            [ -s "$_log" ] && cat "$_log" 1>&2
            ;;
        *)
            TESTS_FAILED=$((TESTS_FAILED + 1))
            FAILED_NAMES+=("$_label :: $_test")
            tl::log "${C_RED}  FAIL${C_RESET} $_test"
            [ -s "$_log" ] && cat "$_log" 1>&2
            ;;
    esac

    rm -rf "$_sandbox"
    rm -f "$_log"
    return 0
}

##
# @info     list the test functions declared by a case file, in the
#           order they appear in the source
##
function tl::discover() {
    local _file="$1"
    grep -oE '^[[:space:]]*(function[[:space:]]+)?test_[a-zA-Z0-9_]+[[:space:]]*\(\)' "$_file" \
        | grep -oE 'test_[a-zA-Z0-9_]+'
}
