#!/bin/sh

main() {
  local DATADIR WATCHIDF CUR
  readonly DATADIR="data"
  readonly WATCHIDF="$DATADIR/ids.csv"

  mkdir -p "$DATADIR" || return 1
  CUR="`get_state`"
  fetch_ids
  fetch_process_parts

  process_cache |
  convert_rss
}

fetch_process_parts() {
  local LAST STATEFILE TMPIDEXP
  readonly STATEFILE="$DATADIR/state.txt"
  readonly TMPIDEXP="$DATADIR/ids-exp.txt.tmp"

  [ -n "$CUR" ] || {
    echo "error: failed to fetch current state" >&2
    return 1
  }

  LAST="`cat "$STATEFILE" 2>/dev/null`"
  if [ -n "$LAST" ] && [ "$LAST" -ge "$CUR" ]; then
    echo "debug: no new part to process $CUR $LAST" >&2
    return 0
  fi

  sed 's~^\([^;]*\);.*$~ id="\1"~' "$WATCHIDF" > "$TMPIDEXP"

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

fetch_ids() {
  local TMPDOWN LASTFETCH NOW
  readonly TMPDOWN="$DATADIR/ids-new.csv"

  if [ -s "$WATCHIDF" ]; then
    readonly LASTFETCH="`ls -l --time-style=+%s "$WATCHIDF" | tr -s ' ' | cut -d ' ' -f 6`"
    readonly NOW="`date +%s`"
    if [ $((NOW-LASTFETCH)) -lt 601200 ]; then
      echo "debug: will fetch set of IDs from OverPass later" >&2
      return 0
    fi
  else
    touch "$WATCHIDF"
  fi

  touch "$TMPDOWN"
  wget \
    -U- \
    -O "$TMPDOWN" \
    --timeout=30 \
    --post-data 'data=%5Bout%3Acsv(%0A++++%3A%3A%22id%22%2C+%3A%3Alat%2C+%3A%3Alon%3B%0A++++false%3B+%22%3B%22)%5D%5Btimeout%3A25%5D%3B%0Aarea(id%3A3600021335)-%3E.searchArea%3B%0Anode%5B%22place%22%5D(area.searchArea)%3B%0Aout%3B' \
    'https://overpass-api.de/api/interpreter'

  grep -qvE '^[^;]+;[^;]+;[^;]+$' "$TMPDOWN" && return 1
  [ `wc -l < "$TMPDOWN"` = 0 ] && return 1
  mv "$TMPDOWN" "$WATCHIDF"
}

process_cache() {
  local NUM CSV

  ls "$DATADIR" |
  sed -nr 's~^chunk-([0-9]+)\.csv$~\1~; T e; p; :e' |
  sort -n |
  while read NUM; do
    CSV="$DATADIR/chunk-$NUM.csv"
    if [ "$((CUR-NUM))" -gt 2880 ]; then
      echo rm "$CSV" >&2
    else
      cat "$CSV"
    fi
  done
}

convert_rss() {
  local RCHANGE RTIME RUSER RIDS RSSTIME

  cat <<EOF
<?xml version='1.0' encoding='UTF-8'?>
<rss version="2.0" xmlns:georss="http://www.georss.org/georss" xmlns:geo="http://www.w3.org/2003/01/geo/wgs84_pos#" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>Change QA (via bkil-bot)</title>
EOF

  while read RCHANGE RTIME RUSER RIDS; do
    RSSTIME="`date -u -R -d "$RTIME"`"
    printf '<item><title>%s moved place node %s in changeset %s</title><link>https://www.openstreetmap.org/changeset/%s</link><guid>https://www.openstreetmap.org/changeset/%s</guid><pubDate>%s</pubDate></item>\n' \
      "$RUSER" "$RIDS" "$RCHANGE" "$RCHANGE" "$RCHANGE" "$RSSTIME"
  done

  cat <<EOF
  </channel>
</rss>
EOF
}

process_one() {
  local WHICH A B C LINE NID NUSER NCHANGE NLAT NLON OLAT OLON
  WHICH="$1"

  printf %s "$WHICH" |
  sed 's~^~000000000~; s~^.*\(...\)\(...\)\(...\)$~\1 \2 \3~' |
  {
    read A B C
    get_part https://download.openstreetmap.fr/replication/europe/minute/$A/$B/$C.osc.gz |
    zcat |
    fgrep -f "$TMPIDEXP"
  } |
  sed -r 's~<node id="([^"]+)".* timestamp="([^"]+)".* user="([^"]+)" changeset="([^"]+)" lat="([^"]+)" lon="([^"]+)".*$~\1 \2 \3 \4 \5 \6~' |
  while read NID NTIME NUSER NCHANGE NLAT NLON; do
    grep "^$NID;" "$WATCHIDF" |
    sed -r "s~^[^;]*;(([^;0]|0+[^;0])*)0*;(([^;0]|0+[^;0])*)0*$~\1 \3~" |
    {
      read OLAT OLON
      if ! [ "$NLAT" = "$OLAT" ] || ! [ "$NLON" = "$OLON" ]; then
        printf "%s %s %s %s\n" "$NCHANGE" "$NID" "$NTIME" "$NUSER"
      fi
    }
  done |
  awk '
  {
    if ($1 == ochange) {
      oids = (oids " " $2);
    } else {
      save();
      ochange = $1;
      oids = $2;
      otime = $3;
      ouser = $4;
    }
  }
  END {
    save();
  }
  function save() {
    if (ochange != "") {
      print ochange " " otime " " ouser " " oids
    }
  }
  ' > "$DATADIR/chunk-$WHICH.csv"

  printf %s "$WHICH" > "$STATEFILE"
}

get_part() {
  wget -U- -O- --timeout=30 "$1"
}

get_state() {
  wget -U- -O- --timeout=15 https://download.openstreetmap.fr/replication/europe/minute/state.txt |
  sed -n 's~^sequenceNumber=\([0-9][0-9]*\)$~\1~ ; T e; p; :e'
}

main "$@"
