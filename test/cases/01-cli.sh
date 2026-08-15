#!/bin/bash
# --------------------------------------------------------------------
# command line handling, argument validation and error reporting
# --------------------------------------------------------------------

function test_script_is_syntactically_valid() {
    run bash -n "$__SCRIPT"
    assert_success
}

function test_script_is_executable() {
    [ -x "$__SCRIPT" ] || fail "confix should be executable (chmod +x)"
}

function test_missing_input_file_is_an_error() {
    confix -f no-such-file.properties "a=b"
    assert_failure
    assert_contains "$stderr" "file not found"
}

function test_missing_input_file_names_the_offending_path() {
    confix -f ghost.conf "a=b"
    assert_contains "$stderr" "ghost.conf"
}

function test_no_arguments_is_an_error() {
    confix
    assert_failure
    assert_contains "$stderr" "file not found"
}

function test_missing_external_config_is_an_error() {
    fixture simple.properties
    confix -f simple.properties -e no-such-file.cf
    assert_failure
    assert_contains "$stderr" "external config file not found"
    assert_unchanged simple.properties
}

function test_unknown_option_prints_usage_and_fails() {
    confix -Z
    assert_failure
    assert_contains "$output" "Usage:"
}

function test_help_prints_usage_with_examples() {
    confix -h
    assert_contains "$output" "Usage:"
    assert_contains "$output" "Options:"
    assert_contains "$output" "Examples:"
}

function test_help_documents_every_supported_flag() {
    confix -h
    local _flag
    for _flag in "-f" "-o" "-e" "-s" "-c" "-h"; do
        assert_contains "$output" "$_flag"
    done
}

function test_errors_go_to_stderr_not_stdout() {
    confix -f no-such-file.properties "a=b"
    assert_eq "" "$stdout" "error output must not pollute stdout"
    assert_ne "" "$stderr"
}

function test_no_commands_leaves_file_untouched() {
    fixture simple.properties
    confix -f simple.properties
    assert_success
    assert_unchanged simple.properties
}

function test_empty_command_is_ignored() {
    fixture simple.properties
    confix -f simple.properties ""
    assert_success
    assert_unchanged simple.properties
}
