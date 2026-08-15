#!/bin/bash
# --------------------------------------------------------------------
# update operation - "key=value" with no leading marker
#
# updates a key that already exists. never creates a new key.
# --------------------------------------------------------------------

function test_update_existing_key() {
    fixture simple.properties
    confix -f simple.properties "configuration.environment=prod"
    assert_success
    assert_line simple.properties "configuration.environment=prod"
    assert_no_line simple.properties "configuration.environment=qa"
}

function test_update_does_not_create_missing_key() {
    fixture simple.properties
    confix -f simple.properties "totally.absent.key=value"
    assert_success
    assert_unchanged simple.properties
}

function test_update_leaves_other_keys_alone() {
    fixture simple.properties
    confix -f simple.properties "configuration.environment=prod"
    assert_line simple.properties "configuration.name=simple-config"
    assert_line simple.properties "configuration.api.version=2"
    assert_line simple.properties "#sample properties"
}

function test_update_preserves_line_count() {
    fixture simple.properties
    local _before
    _before=$(wc -l < simple.properties | tr -d ' ')
    confix -f simple.properties "configuration.environment=prod"
    assert_line_count simple.properties "$_before"
}

function test_update_value_containing_slashes() {
    make_file paths.properties <<'EOF'
data.dir=/var/lib/old
EOF
    confix -f paths.properties "data.dir=/change/commitlog"
    assert_line paths.properties "data.dir=/change/commitlog"
}

function test_update_value_containing_equals_signs() {
    make_file conn.properties <<'EOF'
jdbc.url=host
EOF
    confix -f conn.properties "jdbc.url=a=b=c"
    assert_line conn.properties "jdbc.url=a=b=c"
}

function test_update_uncomments_a_commented_key() {
    fixture log4j.properties
    confix -f log4j.properties "log4j.logger.com.endeca.itl.web.metrics=DEBUG"
    assert_line log4j.properties "log4j.logger.com.endeca.itl.web.metrics=DEBUG"
    assert_no_line log4j.properties "#log4j.logger.com.endeca.itl.web.metrics=INFO"
}

function test_update_preserves_spacing_around_separator() {
    make_file spaced.properties <<'EOF'
key = old
EOF
    confix -f spaced.properties "key=new"
    assert_line spaced.properties "key = new"
}

function test_update_matches_key_exactly_not_as_prefix() {
    make_file prefix.properties <<'EOF'
a.b=1
a.b.c=2
EOF
    confix -f prefix.properties "a.b=99"
    assert_line prefix.properties "a.b=99"
    assert_line prefix.properties "a.b.c=2"
}

function test_update_multiple_keys_in_one_invocation() {
    fixture simple.properties
    confix -f simple.properties "configuration.name=multi" "configuration.environment=prod" "configuration.api.version=3"
    assert_line simple.properties "configuration.name=multi"
    assert_line simple.properties "configuration.environment=prod"
    assert_line simple.properties "configuration.api.version=3"
}

function test_update_commands_apply_in_order() {
    make_file order.properties <<'EOF'
key=first
EOF
    confix -f order.properties "key=second" "key=third"
    assert_line order.properties "key=third"
}

function test_update_to_empty_value() {
    make_file blank.properties <<'EOF'
key=something
EOF
    confix -f blank.properties "key="
    assert_line blank.properties "key="
}

function test_update_with_colon_separator() {
    fixture cassandra.yaml
    confix -s':' -f cassandra.yaml "gc_warn_threshold_in_ms=2001"
    assert_line cassandra.yaml "gc_warn_threshold_in_ms: 2001"
    assert_no_line cassandra.yaml "gc_warn_threshold_in_ms: 1000"
}

function test_update_ignores_wrong_separator() {
    # the file uses ":" but we tell confix the separator is "=", so the
    # key should not be recognised
    fixture cassandra.yaml
    confix -s'=' -f cassandra.yaml "gc_warn_threshold_in_ms=2001"
    assert_unchanged cassandra.yaml
}
