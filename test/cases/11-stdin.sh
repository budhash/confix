#!/bin/bash
# --------------------------------------------------------------------
# stdin / stdout pipe mode
#
#   -f -   (or omitting -f) reads the config from stdin. unless -o names a
#          file, the result is written to stdout, so confix works in a pipe:
#
#       cat app.props | confix -f - "k=v" > out.props
#
# the "confix" helper runs via "run", which leaves stdin inherited, so
# redirecting stdin on the call feeds the script.
# --------------------------------------------------------------------

function test_reads_from_stdin_and_writes_to_stdout() {
    make_file src.properties <<'EOF'
a=1
c=3
EOF
    confix -f - "a=9" < src.properties
    assert_success
    assert_contains "$stdout" "a=9"
    assert_contains "$stdout" "c=3"
    # the redirect source is never opened by confix, so it is untouched
    assert_unchanged src.properties
}

function test_omitting_f_flag_defaults_to_stdin() {
    make_file src.properties <<'EOF'
a=1
EOF
    confix "a=9" < src.properties
    assert_success
    assert_contains "$stdout" "a=9"
}

function test_stdin_with_output_file_writes_file_and_not_stdout() {
    make_file src.properties <<'EOF'
a=1
EOF
    confix -f - -o out.properties "a=9" < src.properties
    assert_success
    assert_file_exists out.properties
    assert_line out.properties "a=9"
    assert_eq "" "$stdout" "nothing should be printed to stdout when -o names a file"
}

function test_stdin_supports_all_operations() {
    make_file src.properties <<'EOF'
upd=1
#enable=2
comment_me=3
drop=4
EOF
    confix -f - "upd=9" ">enable" "<comment_me" "!drop" ">added=5" < src.properties
    assert_contains "$stdout" "upd=9"
    assert_contains "$stdout" "enable=2"
    assert_contains "$stdout" "#comment_me=3"
    assert_not_contains "$stdout" "drop=4"
    assert_contains "$stdout" "added=5"
}

function test_stdin_with_external_command_file() {
    make_file src.properties <<'EOF'
a=1
b=2
EOF
    cat > cmds.cf <<'EOF'
a=9
!b
EOF
    confix -f - -e cmds.cf < src.properties
    assert_contains "$stdout" "a=9"
    assert_not_contains "$stdout" "b=2"
}

function test_stdin_leaves_no_temp_files_behind() {
    make_file src.properties <<'EOF'
a=1
EOF
    rm -f /tmp/confix.* 2>/dev/null || true
    confix -f - "a=9" < src.properties
    assert_success
    local _leftovers
    _leftovers=$(ls -A /tmp 2>/dev/null | grep -E '^confix\.' || true)
    assert_eq "" "$_leftovers" "stdin buffering left a temp file in /tmp"
}
