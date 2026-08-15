#!/bin/bash
# --------------------------------------------------------------------
# real-world config formats - separators, comment characters and the
# guarantee that untargeted parts of a file are never touched
# --------------------------------------------------------------------

function test_yaml_update_add_and_remove_together() {
    fixture cassandra.yaml
    confix -s':' -f cassandra.yaml \
        "gc_warn_threshold_in_ms=2001" \
        ">concurrent_compactors" \
        "commitlog_directory=/change/commitlog"
    assert_success
    assert_line cassandra.yaml "gc_warn_threshold_in_ms: 2001"
    assert_line cassandra.yaml "concurrent_compactors: 1"
    assert_line cassandra.yaml "commitlog_directory: /change/commitlog"
}

function test_yaml_edit_changes_only_the_targeted_lines() {
    fixture cassandra.yaml
    confix -s':' -f cassandra.yaml "gc_warn_threshold_in_ms=2001"
    local _changed
    _changed=$(diff .orig/cassandra.yaml cassandra.yaml | grep -c '^[<>]' || true)
    assert_eq "2" "$_changed" "exactly one line should change (one removed, one added)"
}

function test_yaml_preserves_indented_block_content() {
    fixture cassandra.yaml
    confix -s':' -f cassandra.yaml "cluster_name=prod_cluster"
    assert_line cassandra.yaml "cluster_name: prod_cluster"
    # indented sub-keys elsewhere in the document must survive untouched
    assert_eq "$(grep -c '^ ' .orig/cassandra.yaml)" "$(grep -c '^ ' cassandra.yaml)"
}

function test_properties_file_with_dotted_keys() {
    fixture log4j.properties
    confix -f log4j.properties "log4j.rootLogger=DEBUG,stdout"
    assert_line log4j.properties "log4j.rootLogger=DEBUG,stdout"
    assert_no_line log4j.properties "log4j.rootLogger=ERROR,stdout"
}

function test_properties_value_with_comma() {
    fixture log4j.properties
    confix -f log4j.properties "log4j.rootLogger=WARN,stdout,file"
    assert_line log4j.properties "log4j.rootLogger=WARN,stdout,file"
}

function test_ini_file_with_semicolon_comments() {
    fixture php.ini
    confix -c';' -f php.ini "<memory_limit"
    assert_success
    assert_contains "$(grep memory_limit php.ini)" ";memory_limit"
}

function test_ini_file_preserves_section_headers() {
    fixture php.ini
    confix -c';' -f php.ini "<memory_limit"
    assert_line php.ini "[PHP]"
}

function test_ini_update_with_spaces_around_separator() {
    make_file app.ini <<'EOF'
[PHP]
memory_limit = 128M
EOF
    confix -f app.ini "memory_limit=512M"
    assert_line app.ini "memory_limit = 512M"
}

function test_file_without_trailing_newline_is_handled() {
    printf 'a=1' > nonl.properties
    confix -f nonl.properties "a=2"
    assert_success
    assert_line nonl.properties "a=2"
}

function test_empty_file_accepts_new_keys() {
    : > empty.properties
    confix -f empty.properties ">a=1"
    assert_success
    assert_line empty.properties "a=1"
}

function test_custom_separator_and_comment_char_together() {
    make_file app.conf <<'EOF'
alpha: 1
beta: 2
EOF
    confix -s':' -c'%' -f app.conf "<beta"
    assert_line app.conf "%beta: 2"
    assert_line app.conf "alpha: 1"
}
