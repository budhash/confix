#!/bin/bash
# --------------------------------------------------------------------
# regression tests for behaviour that used to be broken
#
# these were previously pinned as "known limitations" (characterization
# tests locking in wrong-but-current behaviour). they are now fixed and
# assert the CORRECT behaviour, so they guard against regressions.
# see the changelog / CLAUDE.md for the fixes.
# --------------------------------------------------------------------

function test_value_containing_spaces_is_preserved() {
    # commands used to be word-split before parsing, so only the first
    # word of a value survived. the whole value must now be kept.
    make_file app.properties <<'EOF'
greeting=old
EOF
    confix -f app.properties "greeting=hello world"
    assert_line app.properties "greeting=hello world"
}

function test_value_may_contain_extra_separators() {
    # only the first '=' splits key from value; the rest is data
    make_file conn.properties <<'EOF'
jdbc.url=old
EOF
    confix -f conn.properties "jdbc.url=jdbc:h2:mem:test;MODE=PostgreSQL"
    assert_line conn.properties "jdbc.url=jdbc:h2:mem:test;MODE=PostgreSQL"
}

function test_key_is_matched_literally_not_as_a_regex() {
    # the key used to go into a sed pattern unescaped, so "." matched any
    # character and dotted keys hit unintended lines. it must now match
    # only the literal key.
    make_file app.properties <<'EOF'
axb=1
a.b=2
EOF
    confix -f app.properties "a.b=99"
    assert_line app.properties "axb=1"
    assert_line app.properties "a.b=99"
}

function test_custom_comment_char_is_used_when_detecting_commented_keys() {
    # "-c" used to be honoured only when commenting out; detection and
    # uncommenting hardcoded "#", so ">key=value" appended a duplicate.
    # with -c';' it must uncomment the existing line and update it in place.
    make_file app.ini <<'EOF'
;short_open_tag = Off
EOF
    confix -c';' -f app.ini ">short_open_tag=On"
    assert_line app.ini "short_open_tag = On"
    assert_no_line app.ini ";short_open_tag = Off"
    assert_line_count app.ini 1
}

function test_uncommenting_works_with_a_custom_comment_char() {
    make_file app.ini <<'EOF'
;key = value
EOF
    confix -c';' -f app.ini ">key"
    assert_line app.ini "key = value"
    assert_no_line app.ini ";key = value"
}

function test_tab_separated_keys_are_matched() {
    # the match patterns used to allow literal spaces but not tabs, so
    # tab-aligned files were left untouched. blanks (space or tab) around
    # the key and separator must now match, and be preserved.
    make_file tabs.properties <<EOF
key	=	value
EOF
    confix -f tabs.properties "key=updated"
    assert_line tabs.properties "$(printf 'key\t=\tupdated')"
}

function test_help_flag_exits_zero() {
    # "-h" used to fall through to the input-file check and exit 1; it must
    # now print usage and succeed, so it can be used as a smoke test
    confix -h
    assert_success
    assert_contains "$stdout" "Usage:"
}

function test_all_occurrences_of_a_duplicate_key_are_rewritten() {
    # duplicate keys are all rewritten, not just the first occurrence
    make_file app.properties <<'EOF'
dup=1
dup=2
EOF
    confix -f app.properties "dup=9"
    assert_eq "2" "$(grep -c '^dup=9$' app.properties)" "every occurrence of a duplicate key is rewritten"
}
