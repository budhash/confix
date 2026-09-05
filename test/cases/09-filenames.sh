#!/bin/bash
# --------------------------------------------------------------------
# filename robustness
#
# file paths (input, output, external command file) may contain spaces
# and other shell-significant characters. every internal expansion of a
# path is quoted, so these must work.
# --------------------------------------------------------------------

function test_input_file_with_spaces_is_edited_in_place() {
    make_file "my config.properties" <<'EOF'
key=old
EOF
    confix -f "my config.properties" "key=new"
    assert_success
    assert_line "my config.properties" "key=new"
}

function test_output_file_with_spaces_is_written() {
    make_file "in.properties" <<'EOF'
key=old
EOF
    confix -f "in.properties" -o "my out.properties" "key=new"
    assert_success
    assert_file_exists "my out.properties"
    assert_line "my out.properties" "key=new"
    # the original is left untouched when -o names a different file
    assert_unchanged "in.properties"
}

function test_external_command_file_with_spaces_is_read() {
    make_file "app.properties" <<'EOF'
key=old
EOF
    cat > "my cmds.cf" <<'EOF'
key=new
EOF
    confix -f "app.properties" -e "my cmds.cf"
    assert_success
    assert_line "app.properties" "key=new"
}

function test_console_output_leaves_input_with_spaces_untouched() {
    make_file "my config.properties" <<'EOF'
key=old
EOF
    confix -o- -f "my config.properties" "key=new"
    assert_success
    assert_contains "$stdout" "key=new"
    assert_unchanged "my config.properties"
}
