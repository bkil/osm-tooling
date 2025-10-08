#!/bin/sh
. `dirname "$(readlink -f "$0")"`/check-node-move.inc.sh

net_fetch_state() {
  printf -- "$NETFETCHSTATE"
}

net_fetch_part() {
  printf -- "$NETFETCHPART" |
  gzip -1
}

net_fetch_ids() {
  printf -- '42;47.1;19.1;city;Budapest\n69;46.1;20.1;town;Szeged\n'
}

assert() {
  local CASE GIVEIN EXPOUT GOTOUT GOTRET
  readonly CASE="$1"
  readonly GIVEIN="$2"
  readonly EXPOUT="`printf -- "$3"`"

  GOTOUT="`printf -- "$GIVEIN" | eval "$CASE"`"
  GOTRET=$?
  if ! [ "$GOTRET" = 0 ]; then
    printf -- 'failed status for assert "%s", expected 0, got %d\n' "$CASE" "$GOTRET"
    FAILS=$((FAILS+1))
    return 1
  elif ! [ "$GOTOUT" = "$EXPOUT" ]; then
    printf -- 'failed output for assert "%s", expected "%s", got "%s"\n' "$CASE" "$EXPOUT" "$GOTOUT"
    FAILS=$((FAILS+1))
    return 1
  else
    SUCC=$((SUCC+1))
  fi
}

reset_data() {
  rm -R "$DATADIR" 2>/dev/null
  mkdir -p "$DATADIR" || return 1
}

assert_system() {
  reset_data
  assert "$@"
}

test_unit() {
  reset_data

  assert "NETFETCHSTATE='hi=9\n' get_state" '' ''
  assert "NETFETCHSTATE='hi=9\nsequenceNumber=42\nho=9\n' get_state" '' '42'

  assert 'osc2tsv' ' <node id="42" timestamp="2024-01-01" user="A USER" changeset="666" lat="47.0" lon="19.0">' '42 2024-01-01 A%%20USER 666 47.0 19.0'
  assert 'osc2tsv' '<node timestamp="2024-01-01" user="A USER" changeset="666" lat="47.0" lon="19.0">' ''

  assert 'group_by_changeset' '123 69 2024-01-01 A%%20USER town Szeged\n666 21 2024-01-02 A%%20USER town Bugyi\n666 42 2024-01-01 A%%20USER city Budapest\n' '123 2024-01-01 A%%20USER 69 town Szeged\n666 2024-01-02 A%%20USER 21 town Bugyi, 42 city Budapest\n'
  assert 'group_by_changeset' '0 69 2024-01-01 _ town Szeged\n0 21 2024-01-02 _ city Budapest\n' '-69 2024-01-01 _ 69 town Szeged\n-21 2024-01-02 _ 21 city Budapest\n'

  assert \
    'convert_rss_body' \
    '123 2024-01-01 A%%20USER 69 town Szeged\n666 2024-01-02 A%%20USER 21 town Bugyi, 42 city Budapest\n' \
'<item><title>A_USER moved place node 69 town Szeged in changeset 123</title><link>https://www.openstreetmap.org/changeset/123</link><guid>https://www.openstreetmap.org/changeset/123</guid><pubDate>Mon, 01 Jan 2024 00:00:00 +0000</pubDate></item>
<item><title>A_USER moved place node 21 town Bugyi, 42 city Budapest in changeset 666</title><link>https://www.openstreetmap.org/changeset/666</link><guid>https://www.openstreetmap.org/changeset/666</guid><pubDate>Tue, 02 Jan 2024 00:00:00 +0000</pubDate></item>'

  assert \
    'convert_rss_body' \
    '-69 2024-01-01 _ 69 town Szeged\n' \
'<item><title>_ moved place node 69 town Szeged</title><link>https://www.openstreetmap.org/node/69</link><guid>https://www.openstreetmap.org/node/69#1704063600</guid><pubDate>Mon, 01 Jan 2024 00:00:00 +0000</pubDate></item>'
}

test_module() {
  local T
  readonly T="$DATADIR/x"
  reset_data

  rm "$T" 2>/dev/null
  assert \
    'update_ids "$T" && cat "$T"' \
    '' \
'42 47.1 19.1 city Budapest
69 46.1 20.1 town Szeged\n'

  printf -- '42 47.0 19.0 city Budapest\n' > "$T"
  assert \
    "update_get_moved_nodes $T && { echo; cat $T; }" \
    '42 2024-01-01 A%%20USER 666 47.0 19.0\n' \
'
42 47.0 19.0 city Budapest\n'

  printf -- '42 47.1 19.1 city Budapest\n' > "$T"
  assert \
    "update_get_moved_nodes $T && { echo; cat $T; }" \
    '42 2024-01-01 A%%20USER 666 47.1 19.1\n' \
'
42 47.1 19.1 city Budapest\n'

  printf -- '42 47.100 19.100 city Budapest\n' > "$T"
  assert \
    "update_get_moved_nodes $T && { echo; cat $T; }" \
    '42 2024-01-01 A%%20USER 666 47.1 19.1\n' \
'
42 47.100 19.100 city Budapest\n'

  printf -- '42 47.1 19.1 city Budapest\n' > "$T"
  assert \
    "update_get_moved_nodes $T && { echo; cat $T; }" \
    '42 2024-01-01 A%%20USER 666 47.2 19.1\n' \
'666 42 2024-01-01 A%%20USER city Budapest\n
42 47.2 19.1 city Budapest\n'

# process_one
# fetch_process_parts

  reset_data
  echo 4 > "$DATADIR/chunk-20004.xml"
  echo 3 > "$DATADIR/chunk-20003.xml"
  echo 2 > "$DATADIR/chunk-20002.xml"
  echo 1 > "$DATADIR/chunk-1.xml"
  assert 'CUR=30000 process_cache && { cat "$DATADIR/chunk-1.xml" 2>/dev/null; true; }' '' '2\n3\n4\n'
}

test_system() {
  assert_system \
    "NETFETCHSTATE='sequenceNumber=42' NETFETCHPART='\
<node id=\"42\" timestamp=\"2024-01-01T13:37\" user=\"A USER\" changeset=\"666\" lat=\"47.2\" lon=\"19.1\">\
' main_node_move" \
    '' \
    "<?xml version='1.0' encoding='UTF-8'?>
<rss version=\"2.0\" xmlns:georss=\"http://www.georss.org/georss\" xmlns:geo=\"http://www.w3.org/2003/01/geo/wgs84_pos#\" xmlns:dc=\"http://purl.org/dc/elements/1.1/\">
  <channel>
    <title>Change QA (via bkil-bot)</title>
<item><title>A_USER moved place node 42 city Budapest in changeset 666</title><link>https://www.openstreetmap.org/changeset/666</link><guid>https://www.openstreetmap.org/changeset/666</guid><pubDate>Mon, 01 Jan 2024 13:37:00 +0000</pubDate></item>
  </channel>
</rss>"

  assert_system \
    "NETFETCHSTATE='sequenceNumber=42' NETFETCHPART='\
<node id=\"42\" timestamp=\"2024-01-01T13:37\" user=\"A USER\" changeset=\"666\" lat=\"47.2\" lon=\"19.1\">\
' main_node_move_tsv" \
    '' \
    "<item><title>A_USER moved place node 42 city Budapest in changeset 666</title><link>https://www.openstreetmap.org/changeset/666</link><guid>https://www.openstreetmap.org/changeset/666</guid><pubDate>Mon, 01 Jan 2024 13:37:00 +0000</pubDate></item>"

  assert_system \
    "NETFETCHSTATE='sequenceNumber=42' NETFETCHPART='\
<node id=\"42\" timestamp=\"2024-01-01T13:36\" user=\"A USER\" changeset=\"2\" lat=\"47.1\" lon=\"19.1\">\
' main_node_move_tsv >/dev/null; \
NETFETCHSTATE='sequenceNumber=43' NETFETCHPART='\
<node id=\"42\" timestamp=\"2024-01-01T13:37\" user=\"A USER\" changeset=\"3\" lat=\"47.2\" lon=\"19.1\">\
' main_node_move_tsv >/dev/null; \
NETFETCHSTATE='sequenceNumber=44' NETFETCHPART='\
<node id=\"42\" timestamp=\"2024-01-01T13:38\" user=\"A USER\" changeset=\"4\" lat=\"47.2\" lon=\"19.1\">\
' main_node_move_tsv" \
    '' \
    "<item><title>A_USER moved place node 42 city Budapest in changeset 3</title><link>https://www.openstreetmap.org/changeset/3</link><guid>https://www.openstreetmap.org/changeset/3</guid><pubDate>Mon, 01 Jan 2024 13:37:00 +0000</pubDate></item>"
}

main() {
  local DATADIR FAILS SUCC NETFETCHSTATE NETFETCHPART
  FAILS=0
  SUCC=0
  readonly DATADIR="data.tmp"

  test_unit
  test_module
  test_system

  rm -R "$DATADIR" 2>/dev/null
  if [ "$FAILS" = 0 ]; then
    printf -- "All %d tests successful\n" "$SUCC" >&2
  else
    printf -- "%s of %d tests failed\n" "$FAILS" "$((SUCC+FAILS))" >&2
    return 1
  fi
}

main "$@"
