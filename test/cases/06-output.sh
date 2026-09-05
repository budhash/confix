#!/bin/bash
# --------------------------------------------------------------------
# output modes - in-place (default), "-o <file>" and "-o-" (console)
# --------------------------------------------------------------------

function test_default_mode_edits_the_file_in_place() {
    fixture simple.properties
    confix -f simple.properties "configuration.environment=prod"
    assert_line simple.properties "configuration.environment=prod"
}

function test_console_output_prints_the_result_to_stdout() {
    fixture simple.properties
    confix -o- -f simple.properties "configuration.environment=prod"
    assert_success
    assert_contains "$stdout" "configuration.environment=prod"
}

function test_console_output_leaves_the_input_untouched() {
    fixture simple.properties
    confix -o- -f simple.properties "configuration.environment=prod"
    assert_unchanged simple.properties
}

function test_console_output_prints_the_whole_file() {
    fixture simple.properties
    confix -o- -f simple.properties "configuration.environment=prod"
    assert_contains "$stdout" "#sample properties"
    assert_contains "$stdout" "configuration.name=simple-config"
    assert_contains "$stdout" "configuration.api.version=2"
}

function test_console_output_with_no_commands_echoes_the_input() {
    fixture simple.properties
    confix -o- -f simple.properties
    assert_eq "$(cat simple.properties)" "$stdout"
}

function test_output_to_a_different_file() {
    fixture simple.properties
    confix -o out.properties -f simple.properties "configuration.environment=prod"
    assert_success
    assert_file_exists out.properties
    assert_line out.properties "configuration.environment=prod"
}

function test_output_to_a_different_file_leaves_input_untouched() {
    fixture simple.properties
    confix -o out.properties -f simple.properties "configuration.environment=prod"
    assert_unchanged simple.properties
}

function test_output_file_is_a_full_copy_when_no_commands_given() {
    fixture simple.properties
    confix -o out.properties -f simple.properties
    assert_same_file simple.properties out.properties
}

function test_output_modes_produce_identical_content() {
    fixture simple.properties inplace.properties
    fixture simple.properties source.properties

    confix -f inplace.properties "configuration.environment=prod" ">extra=1"
    confix -o- -f source.properties "configuration.environment=prod" ">extra=1"

    assert_eq "$(cat inplace.properties)" "$stdout" "-o- and in-place editing should agree"
}

function test_console_output_works_with_external_config() {
    fixture log4j.properties
    confix -o- -e "$__DATADIR/log4j.cf" -f log4j.properties
    assert_success
    assert_contains "$stdout" "log4j.rootLogger=DEBUG,stdout"
    assert_unchanged log4j.properties
}

function test_no_temporary_files_are_left_behind() {
    fixture simple.properties
    confix -f simple.properties "configuration.environment=prod"
    # .orig is the harness snapshot directory, everything else must be
    # accounted for
    local _leftovers
    _leftovers=$(ls -A | grep -v '^\.orig$' | grep -v '^simple.properties$' || true)
    assert_eq "" "$_leftovers" "confix left unexpected files in the working directory"
}

function test_no_backup_files_are_left_behind_with_output_file() {
    fixture simple.properties
    confix -o out.properties -f simple.properties "configuration.environment=prod"
    local _leftovers
    _leftovers=$(ls -A | grep -v '^\.orig$' | grep -v '^simple.properties$' | grep -v '^out.properties$' || true)
    assert_eq "" "$_leftovers" "confix left unexpected files in the working directory"
}

function test_no_backup_is_left_in_tmp_after_inplace_edit() {
    # macOS edits in place with "sed -i .SUFFIX", which creates a backup;
    # confix must remove it, not relocate it to /tmp. GNU sed leaves none, so
    # this passes trivially on linux and guards the macOS path.
    local _name="confix-backup-check-$$.properties"
    rm -f "/tmp/${_name}."* 2>/dev/null || true
    make_file "$_name" <<'EOF'
a=1
EOF
    confix -f "$_name" "a=2"
    assert_success
    assert_line "$_name" "a=2"
    local _leftovers
    _leftovers=$(ls -A /tmp 2>/dev/null | grep -F "${_name}." || true)
    assert_eq "" "$_leftovers" "confix left a backup file in /tmp"
}

function test_repeated_runs_are_stable() {
    fixture simple.properties
    confix -f simple.properties "configuration.environment=prod" ">added=1" "<configuration.name"
    local _first
    _first=$(cat simple.properties)
    confix -f simple.properties "configuration.environment=prod" ">added=1" "<configuration.name"
    assert_eq "$_first" "$(cat simple.properties)" "applying the same commands twice should be stable"
}
