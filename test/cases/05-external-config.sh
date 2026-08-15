#!/bin/bash
# --------------------------------------------------------------------
# external command files - "-e <file>"
#
# one command per line, "#" comments and blank lines ignored
# --------------------------------------------------------------------

function test_commands_are_read_from_external_file() {
    fixture cassandra.yaml
    confix -s':' -f cassandra.yaml -e "$__DATADIR/cassandra.cf"
    assert_success
    assert_line cassandra.yaml "gc_warn_threshold_in_ms: 2001"
    assert_line cassandra.yaml "concurrent_compactors: 1"
    assert_line cassandra.yaml "commitlog_directory: /change/commitlog"
}

function test_external_file_matches_equivalent_commandline() {
    # the shipped cassandra.cf and these arguments must be interchangeable
    fixture cassandra.yaml viafile.yaml
    fixture cassandra.yaml viaargs.yaml

    confix -s':' -f viafile.yaml -e "$__DATADIR/cassandra.cf"
    confix -s':' -f viaargs.yaml "gc_warn_threshold_in_ms=2001" ">concurrent_compactors" "commitlog_directory=/change/commitlog"

    assert_same_file viafile.yaml viaargs.yaml
}

function test_log4j_external_file_matches_equivalent_commandline() {
    fixture log4j.properties viafile.properties
    fixture log4j.properties viaargs.properties

    confix -f viafile.properties -e "$__DATADIR/log4j.cf"
    confix -f viaargs.properties \
        "log4j.rootLogger=DEBUG,stdout" \
        "log4j.logger.com.endeca=WARN" \
        ">log4j.appender.stdout.layout.ConversionPattern" \
        "<log4j.appender.stdout=org.apache.log4j.ConsoleAppender" \
        ">log4j.appender.stdout.layout=org.apache.log4j.NewLayout" \
        "log4j.logger.com.endeca.itl.web.metrics=INFO" \
        "log4j.logger.com.web=INFO"

    assert_same_file viafile.properties viaargs.properties
}

function test_comment_lines_in_external_file_are_ignored() {
    make_file app.properties <<'EOF'
a=1
b=2
EOF
    cat > cmds.cf <<'EOF'
#this is a comment
a=9
EOF
    confix -f app.properties -e cmds.cf
    assert_line app.properties "a=9"
    assert_line app.properties "b=2"
}

function test_indented_comment_lines_are_ignored() {
    make_file app.properties <<'EOF'
a=1
EOF
    cat > cmds.cf <<'EOF'
  #  indented comment
a=9
EOF
    confix -f app.properties -e cmds.cf
    assert_line app.properties "a=9"
    assert_line_count app.properties 1
}

function test_blank_lines_in_external_file_are_ignored() {
    make_file app.properties <<'EOF'
a=1
EOF
    printf '\n\na=9\n\n' > cmds.cf
    confix -f app.properties -e cmds.cf
    assert_line app.properties "a=9"
    assert_line_count app.properties 1
}

function test_external_file_supports_all_three_operations() {
    make_file app.properties <<'EOF'
keep=1
disable=2
#enable=3
EOF
    cat > cmds.cf <<'EOF'
keep=99
<disable
>enable
EOF
    confix -f app.properties -e cmds.cf
    assert_line app.properties "keep=99"
    assert_line app.properties "#disable=2"
    assert_line app.properties "enable=3"
}

function test_external_file_and_commandline_commands_combine() {
    make_file app.properties <<'EOF'
a=1
b=2
EOF
    cat > cmds.cf <<'EOF'
a=9
EOF
    confix -f app.properties -e cmds.cf "b=8"
    assert_line app.properties "a=9"
    assert_line app.properties "b=8"
}

function test_empty_external_file_is_noop() {
    fixture simple.properties
    : > empty.cf
    confix -f simple.properties -e empty.cf
    assert_success
    assert_unchanged simple.properties
}
