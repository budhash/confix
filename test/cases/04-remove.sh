#!/bin/bash
# --------------------------------------------------------------------
# remove / disable operation - "<key"
#
# comments the key out rather than deleting the line
# --------------------------------------------------------------------

function test_remove_comments_out_an_existing_key() {
    fixture cassandra.yaml
    confix -c'#' -s':' -f cassandra.yaml "<gc_warn_threshold_in_ms"
    assert_success
    assert_line cassandra.yaml "#gc_warn_threshold_in_ms: 1000"
    assert_no_line cassandra.yaml "gc_warn_threshold_in_ms: 1000"
}

function test_remove_keeps_the_original_value() {
    make_file app.properties <<'EOF'
timeout=30
EOF
    confix -f app.properties "<timeout"
    assert_line app.properties "#timeout=30"
}

function test_remove_absent_key_is_noop() {
    fixture cassandra.yaml
    confix -s':' -f cassandra.yaml "<invalid_key"
    assert_success
    assert_unchanged cassandra.yaml
}

function test_remove_already_commented_key_is_noop() {
    make_file app.properties <<'EOF'
#a=1
EOF
    confix -f app.properties "<a"
    assert_line app.properties "#a=1"
    assert_line_count app.properties 1
}

function test_remove_leaves_other_keys_alone() {
    make_file app.properties <<'EOF'
a=1
b=2
c=3
EOF
    confix -f app.properties "<b"
    assert_line app.properties "a=1"
    assert_line app.properties "#b=2"
    assert_line app.properties "c=3"
}

function test_remove_uses_custom_comment_character() {
    make_file app.ini <<'EOF'
memory_limit = 128M
EOF
    confix -c';' -f app.ini "<memory_limit"
    assert_line app.ini ";memory_limit = 128M"
}

function test_remove_then_add_round_trips() {
    make_file app.properties <<'EOF'
a=1
EOF
    confix -f app.properties "<a"
    assert_line app.properties "#a=1"
    confix -f app.properties ">a"
    assert_line app.properties "a=1"
    assert_unchanged app.properties
}

function test_remove_does_not_change_line_count() {
    fixture simple.properties
    local _before
    _before=$(wc -l < simple.properties | tr -d ' ')
    confix -f simple.properties "<configuration.name"
    assert_line_count simple.properties "$_before"
}

function test_remove_multiple_keys() {
    make_file app.properties <<'EOF'
a=1
b=2
c=3
EOF
    confix -f app.properties "<a" "<c"
    assert_line app.properties "#a=1"
    assert_line app.properties "b=2"
    assert_line app.properties "#c=3"
}
