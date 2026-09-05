#!/bin/bash
# --------------------------------------------------------------------
# delete operation - "!key"
#
#   !key   remove the key's line entirely, whether it is active or
#          commented out. no action if the key is absent. any value given
#          (!key=value) is ignored - deletion is by key.
#
# unlike "<key" (comment out), which keeps the line, "!key" removes it.
# --------------------------------------------------------------------

function test_delete_removes_an_existing_key() {
    make_file app.properties <<'EOF'
a=1
b=2
c=3
EOF
    confix -f app.properties "!b"
    assert_success
    assert_no_line app.properties "b=2"
    assert_line app.properties "a=1"
    assert_line app.properties "c=3"
    assert_line_count app.properties 2
}

function test_delete_removes_the_line_not_just_the_value() {
    make_file app.properties <<'EOF'
keep=1
drop=2
EOF
    confix -f app.properties "!drop"
    assert_no_line app.properties "drop="
    assert_line_count app.properties 1
}

function test_delete_absent_key_is_noop() {
    fixture simple.properties
    confix -f simple.properties "!definitely_not_here"
    assert_success
    assert_unchanged simple.properties
}

function test_delete_also_removes_a_commented_key() {
    make_file app.properties <<'EOF'
a=1
#b=2
EOF
    confix -f app.properties "!b"
    assert_no_line app.properties "#b=2"
    assert_line app.properties "a=1"
    assert_line_count app.properties 1
}

function test_delete_removes_all_duplicate_occurrences() {
    make_file app.properties <<'EOF'
dup=1
keep=9
dup=2
EOF
    confix -f app.properties "!dup"
    assert_no_line app.properties "dup=1"
    assert_no_line app.properties "dup=2"
    assert_line app.properties "keep=9"
    assert_line_count app.properties 1
}

function test_delete_matches_key_literally_not_as_regex() {
    make_file app.properties <<'EOF'
a.b[0]=v
axb=keep
EOF
    confix -f app.properties "!a.b[0]"
    assert_no_line app.properties "a.b[0]=v"
    assert_line app.properties "axb=keep"
}

function test_delete_ignores_a_supplied_value() {
    make_file app.properties <<'EOF'
k=actual
EOF
    confix -f app.properties "!k=whatever"
    assert_no_line app.properties "k=actual"
    assert_line_count app.properties 0
}

function test_delete_via_external_file_and_custom_comment_char() {
    make_file app.ini <<'EOF'
a=1
;b=2
c=3
EOF
    cat > cmds.cf <<'EOF'
!a
!b
EOF
    confix -c';' -f app.ini -e cmds.cf
    assert_no_line app.ini "a=1"
    assert_no_line app.ini ";b=2"
    assert_line app.ini "c=3"
    assert_line_count app.ini 1
}

function test_delete_with_console_output_leaves_input_untouched() {
    make_file app.properties <<'EOF'
a=1
b=2
EOF
    confix -o- -f app.properties "!a"
    assert_success
    assert_not_contains "$stdout" "a=1"
    assert_contains "$stdout" "b=2"
    assert_unchanged app.properties
}

function test_delete_uses_configured_separator() {
    make_file app.yaml <<'EOF'
kept: 1
gone: 2
EOF
    confix -s':' -f app.yaml "!gone"
    assert_no_line app.yaml "gone: 2"
    assert_line app.yaml "kept: 1"
}
