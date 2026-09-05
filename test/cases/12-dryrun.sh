#!/bin/bash
# --------------------------------------------------------------------
# dry-run diff mode - "-d"
#
#   -d   print a unified diff of what would change and write nothing.
#        the input file (or stdin) is never modified.
# --------------------------------------------------------------------

function test_dryrun_shows_a_diff_and_leaves_the_file_unchanged() {
    make_file app.properties <<'EOF'
a=1
b=2
EOF
    confix -d -f app.properties "a=9"
    assert_success
    assert_contains "$stdout" "-a=1"
    assert_contains "$stdout" "+a=9"
    assert_unchanged app.properties
}

function test_dryrun_output_is_a_unified_diff_with_labels() {
    make_file app.properties <<'EOF'
a=1
EOF
    confix -d -f app.properties "a=9"
    assert_contains "$stdout" "--- app.properties"
    assert_contains "$stdout" "+++ app.properties (confix)"
    assert_contains "$stdout" "@@"
}

function test_dryrun_with_no_changes_produces_no_output() {
    fixture simple.properties
    confix -d -f simple.properties "not_a_real_key=9"
    assert_success
    assert_eq "" "$stdout" "a no-op dry run should print nothing"
    assert_unchanged simple.properties
}

function test_dryrun_covers_all_operations() {
    make_file app.properties <<'EOF'
upd=1
#enable=2
comment_me=3
drop=4
EOF
    confix -d -f app.properties "upd=9" ">enable" "<comment_me" "!drop" ">added=5"
    assert_contains "$stdout" "+upd=9"
    assert_contains "$stdout" "+enable=2"
    assert_contains "$stdout" "+#comment_me=3"
    assert_contains "$stdout" "-drop=4"
    assert_contains "$stdout" "+added=5"
    assert_unchanged app.properties
}

function test_dryrun_from_stdin_labels_the_diff_as_stdin() {
    make_file src.properties <<'EOF'
a=1
EOF
    confix -d -f - "a=9" < src.properties
    assert_success
    assert_contains "$stdout" "--- (stdin)"
    assert_contains "$stdout" "+a=9"
    assert_unchanged src.properties
}

function test_dryrun_ignores_output_file_and_writes_nothing() {
    make_file app.properties <<'EOF'
a=1
EOF
    confix -d -o out.properties -f app.properties "a=9"
    assert_success
    assert_contains "$stdout" "+a=9"
    assert_file_missing out.properties
    assert_unchanged app.properties
}

function test_dryrun_leaves_no_temp_files_behind() {
    make_file app.properties <<'EOF'
a=1
EOF
    rm -f /tmp/confix.* 2>/dev/null || true
    confix -d -f app.properties "a=9"
    assert_success
    local _leftovers
    _leftovers=$(ls -A /tmp 2>/dev/null | grep -E '^confix\.' || true)
    assert_eq "" "$_leftovers" "dry run left a temp file in /tmp"
}
