#!/bin/sh

get_state() {
  net_fetch_state |
  sed -rn 's~^sequenceNumber=([0-9]+)$~\1~ ; T e; p; :e'
}

update_ids() {
  local UIF TMPDOWN LASTFETCH NOW
  readonly UIF="$1"
  readonly TMPDOWN="$DATADIR/ids-new.csv"

  if [ -s "$UIF" ]; then
    readonly LASTFETCH="`ls -l --time-style=+%s "$UIF" | tr -s ' ' | cut -d ' ' -f 6`"
    readonly NOW="`date +%s`"
    if [ $((NOW-LASTFETCH)) -lt 601200 ]; then
      echo "debug: will fetch set of IDs from OverPass later" >&2
      return 0
    fi
  else
    touch "$UIF"
  fi

  touch "$TMPDOWN"
  net_fetch_ids |
  sed -r "
    s~%~%25~g
    s~\t~%09~g
    s~ ~%20~g
    s~^([^;]+);([^;]+);([^;]+);([^;]+);(.*)$~\1 \2 \3 \4 \5~
    " > "$TMPDOWN" || return 1

  grep -qvE '^[^ ]+ [^ ]+ [^ ]+ [^ ]+ .*$' "$TMPDOWN" && return 1
  [ `wc -l < "$TMPDOWN"` = 0 ] && return 1
  mv "$TMPDOWN" "$UIF"
}

osc2tsv() {
  sed -nr '
    s~^\s*<node id="([0-9]+)".* timestamp="([^"]+)".* user="([^"]*)" changeset="([0-9]+)" lat="([0-9.-]+)" lon="([0-9.-]+)".*$~\1"\2"\3"\4"\5"\6~
    T e
    s~%~%25~g
    s~\t~%09~g
    s~ ~%20~g
    s~""~"_"~g
    s~"~ ~g
    p
    :e
    '
}

update_get_moved_nodes() {
  local UGMNF NID NTIME NUSER NCHANGE NLAT NLON OLAT OLON OPLACE ONAME

  readonly UGMNF="$1"
  while read -r NID NTIME NUSER NCHANGE NLAT NLON; do
    fgrep "$NID " "$UGMNF" |
    grep "^$NID " |
    sed -rn "
      s~^[^ ]* ([^.]+\.0?([^ 0]|0+[^ 0])*)0* ([^.]+\.0?([^ 0]|0+[^ 0])*)0* ([^ ]+) (.*)$~\1 \3 \5 \6~
      T e
      p
      :e
      " |
    {
      read -r OLAT OLON OPLACE ONAME
      if ! [ "$NLAT" = "$OLAT" ] || ! [ "$NLON" = "$OLON" ]; then
        sed -i -r "s~(${NID} )[^ ]+ [^ ]+( .*)$~\1${NLAT} ${NLON}\2~" "$UGMNF"
        printf "%s %s %s %s %s %s\n" "$NCHANGE" "$NID" "$NTIME" "$NUSER" "$OPLACE" "$ONAME"
      fi
    }
  done
}

group_by_changeset() {
  awk '
  BEGIN {
    ochange = "-";
  }
  {
    oid = ($2 " " $5 " " $6);
    if (($1 == ochange) && ($1 != 0)) {
      oids = (oids ", " oid);
    } else {
      save();
      ochange = $1;
      if (ochange == 0) {
        ochange = -$2;
      }
      oids = oid;
      otime = $3;
      ouser = $4;
    }
  }
  END {
    save();
  }
  function save() {
    if (ochange != "-") {
      print ochange " " otime " " ouser " " oids
    }
  }
  '
}

convert_rss_body() {
  local RCHANGE RTIME RUSER RIDS RSSTIME NODE UNIXTIME
  while read -r RCHANGE RTIME RUSER RIDS; do
    RSSTIME="`date -u -R -d "$RTIME"`"
    if [ "$RCHANGE" -gt 0 ]; then
      printf '<item><title>%s moved place node %s in changeset %s</title><link>https://www.openstreetmap.org/changeset/%s</link><guid>https://www.openstreetmap.org/changeset/%s</guid><pubDate>%s</pubDate></item>\n' \
        "$RUSER" "$RIDS" "$RCHANGE" "$RCHANGE" "$RCHANGE" "$RSSTIME"
    else
      NODE=$((-RCHANGE))
      UNIXTIME="`date -d "$RTIME" +%s`"
      printf '<item><title>%s moved place node %s</title><link>https://www.openstreetmap.org/node/%s</link><guid>https://www.openstreetmap.org/node/%s#%s</guid><pubDate>%s</pubDate></item>\n' \
        "$RUSER" "$RIDS" "$NODE" "$NODE" "$UNIXTIME" "$RSSTIME"
    fi |
    sed "s~%20~_~g"
  done
}

process_one() {
  local WHICH A B C
  readonly WHICH="$1"

  printf %s "$WHICH" |
  sed 's~^~000000000~; s~^.*\(...\)\(...\)\(...\)$~\1 \2 \3~' |
  {
    read -r A B C
    net_fetch_part $A $B $C
  } |
  zcat |
  fgrep -f "$TMPIDEXP" |
  osc2tsv |
  update_get_moved_nodes "$WATCHIDF" |
  group_by_changeset |
  convert_rss_body > "$DATADIR/chunk-$WHICH.xml"

  printf %s "$WHICH" > "$STATEFILE"
}

fetch_process_parts() {
  local LAST TMPIDEXP
  readonly TMPIDEXP="$DATADIR/ids-exp.txt.tmp"

  [ -n "$CUR" ] || {
    echo "error: failed to fetch current state" >&2
    return 1
  }

  LAST="`cat "$STATEFILE" 2>/dev/null`"
  if [ -n "$LAST" ] && [ "$LAST" -ge "$CUR" ]; then
    printf "debug: current available part %s not newer than last processed %s\n" "$CUR" "$LAST" >&2
    return 0
  fi

  sed -rn 's~^([^ ]+) .*$~ id="\1"~; T e; p; :e' "$WATCHIDF" > "$TMPIDEXP"

  if [ -z "$LAST" ]; then
    process_one "$CUR"
  else
    while [ "$LAST" -lt "$CUR" ]; do
      LAST=$((LAST+1))
      process_one "$LAST" || return
    done
  fi
  rm "$TMPIDEXP" 2>/dev/null
}

process_cache() {
  local NUM CSV

  ls "$DATADIR" |
  sed -nr 's~^chunk-([0-9]+)\.xml$~\1~; T e; p; :e' |
  sort -n |
  while read -r NUM; do
    CSV="$DATADIR/chunk-$NUM.xml"
    if [ "$((CUR-NUM))" -gt 2880 ]; then
      rm "$CSV"
    else
      cat "$CSV"
    fi
  done |
  tail
}

wrap_rss() {
  cat <<EOF
<?xml version='1.0' encoding='UTF-8'?>
<rss version="2.0" xmlns:georss="http://www.georss.org/georss" xmlns:geo="http://www.w3.org/2003/01/geo/wgs84_pos#" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>Change QA (via bkil-bot)</title>
EOF

  cat

  cat <<EOF
  </channel>
</rss>
EOF
}

main_node_move_updates() {
  local WATCHIDF STATEFILE
  readonly WATCHIDF="$DATADIR/ids.csv"
  readonly STATEFILE="$DATADIR/state.txt"
  mkdir -p "$DATADIR" || return 1

  CUR="`get_state`"
  update_ids "$WATCHIDF" || return 1
  fetch_process_parts || return 1
}

main_node_move_tsv() {
  local CUR
  main_node_move_updates || return 1
  process_cache
}

main_node_move() {
  local CUR
  main_node_move_updates || return 1
  process_cache |
  wrap_rss
}
