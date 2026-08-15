#!/bin/bash
# --------------------------------------------------------------------
# add / enable operation - ">key=value" and ">key"
#
#   >key=value  set the key, appending it to the file if it is absent
#   >key        uncomment an existing key, no-op if the key is absent
# --------------------------------------------------------------------

function test_add_new_key_appends_to_end_of_file() {
    make_file app.properties <<'EOF'
existing=1
EOF
    confix -f app.properties ">brand.new=hello"
    assert_success
    assert_line app.properties "brand.new=hello"
    assert_line app.properties "existing=1"
    assert_eq "brand.new=hello" "$(tail -1 app.properties)" "new key should be the last line"
}

function test_add_existing_key_updates_in_place_without_appending() {
    make_file app.properties <<'EOF'
a=1
b=2
EOF
    confix -f app.properties ">a=9"
    assert_line app.properties "a=9"
    assert_line_count app.properties 2
}

function test_add_uncomments_existing_commented_key() {
    fixture cassandra.yaml
    confix -s':' -f cassandra.yaml ">concurrent_compactors"
    assert_line cassandra.yaml "concurrent_compactors: 1"
    assert_no_line cassandra.yaml "#concurrent_compactors: 1"
}

function test_add_without_value_is_noop_for_absent_key() {
    fixture cassandra.yaml
    confix -s':' -f cassandra.yaml ">definitely_not_a_real_key"
    assert_success
    assert_unchanged cassandra.yaml
}

function test_add_with_value_uncomments_and_sets_commented_key() {
    make_file app.properties <<'EOF'
#a=1
EOF
    confix -f app.properties ">a=9"
    assert_line app.properties "a=9"
    assert_no_line app.properties "#a=1"
}

function test_add_uses_configured_separator_for_new_keys() {
    fixture cassandra.yaml
    confix -s':' -f cassandra.yaml ">new_param=/some/val"
    assert_line cassandra.yaml "new_param:/some/val"
}

function test_add_new_key_with_slash_value() {
    make_file app.properties <<'EOF'
existing=1
EOF
    confix -f app.properties ">data.dir=/some/deep/path"
    assert_line app.properties "data.dir=/some/deep/path"
}

function test_add_multiple_new_keys() {
    make_file app.properties <<'EOF'
existing=1
EOF
    confix -f app.properties ">one=1" ">two=2" ">three=3"
    assert_line app.properties "one=1"
    assert_line app.properties "two=2"
    assert_line app.properties "three=3"
}

function test_add_then_update_the_new_key() {
    make_file app.properties <<'EOF'
existing=1
EOF
    confix -f app.properties ">fresh=1" "fresh=2"
    assert_line app.properties "fresh=2"
    assert_no_line app.properties "fresh=1"
}

function test_add_is_idempotent() {
    make_file app.properties <<'EOF'
existing=1
EOF
    confix -f app.properties ">repeat=1"
    local _once
    _once=$(cat app.properties)
    confix -f app.properties ">repeat=1"
    assert_eq "$_once" "$(cat app.properties)" "adding the same key twice should not duplicate it"
}

function test_add_appends_blank_separator_line_when_file_ends_with_newline() {
    # documents the current layout of appended entries: confix writes an
    # empty line before the new key
    make_file app.properties <<'EOF'
existing=1
EOF
    confix -f app.properties ">brand.new=hello"
    assert_eq "" "$(sed -n '2p' app.properties)" "expected a blank line between old content and the new key"
}
