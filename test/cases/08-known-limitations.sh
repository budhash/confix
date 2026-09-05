#!/bin/bash
# --------------------------------------------------------------------
# characterization tests for known limitations
#
# these lock in what confix CURRENTLY does, not what it SHOULD do.
# they exist so the behaviour is visible and so a future fix has to be
# a deliberate, reviewed change rather than an accident. if you fix one
# of these, update the test and note it in the changelog.
# --------------------------------------------------------------------

function test_LIMITATION_value_is_truncated_at_the_first_space() {
    # commands are word-split before parsing, so only the first word of
    # a value survives. quoting the argument does not help.
    make_file app.properties <<'EOF'
greeting=old
EOF
    confix -f app.properties "greeting=hello world"
    assert_line app.properties "greeting=hello"
    assert_no_line app.properties "greeting=hello world"
}

function test_LIMITATION_key_is_interpreted_as_a_regular_expression() {
    # the key goes into a sed pattern unescaped, so "." matches any
    # character and dotted keys can hit unintended lines
    make_file app.properties <<'EOF'
axb=1
a.b=2
EOF
    confix -f app.properties "a.b=99"
    assert_line app.properties "axb=99"
    assert_line app.properties "a.b=99"
}

function test_LIMITATION_comment_char_is_ignored_when_detecting_commented_keys() {
    # "-c" is honoured when commenting a key out, but the existence
    # check and the uncomment step both hardcode "#". with a ";"
    # comment character an already-commented key looks absent, so
    # ">key=value" appends a duplicate instead of uncommenting.
    make_file app.ini <<'EOF'
;short_open_tag = Off
EOF
    confix -c';' -f app.ini ">short_open_tag=On"
    assert_line app.ini ";short_open_tag = Off"
    assert_line app.ini "short_open_tag=On"
}

function test_LIMITATION_uncommenting_only_works_for_hash_comments() {
    make_file app.ini <<'EOF'
;key = value
EOF
    confix -c';' -f app.ini ">key"
    assert_line app.ini ";key = value"
}

function test_LIMITATION_tab_separated_keys_are_not_matched() {
    # the match patterns allow literal spaces around the key ("[ ]*")
    # but not tabs, so tab-aligned config files are left untouched
    make_file tabs.properties <<'EOF'
key	=	value
EOF
    confix -f tabs.properties "key=updated"
    assert_success
    assert_unchanged tabs.properties
}

function test_LIMITATION_help_flag_exits_non_zero() {
    # "-h" prints usage, then falls through to the input-file check and
    # exits 1, so it cannot be used as a success-path smoke test
    confix -h
    assert_failure
}

function test_LIMITATION_first_match_wins_for_duplicate_keys() {
    # duplicate keys are all rewritten, not just the first occurrence
    make_file app.properties <<'EOF'
dup=1
dup=2
EOF
    confix -f app.properties "dup=9"
    assert_eq "2" "$(grep -c '^dup=9$' app.properties)" "every occurrence of a duplicate key is rewritten"
}
