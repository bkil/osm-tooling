#!/bin/sh
# https://www.mediawiki.org/wiki/Special:MyLanguage/Help:Extension:Kartographer

main() {
  local IN OUT
  readonly IN="$1"
  if [ -z "$IN" ] || ! [ -f "$IN" ]; then
    echo "error: need input gpx" >&2
    exit 1
  fi
  readonly OUT="`basename "$IN" .gpx`.geojson"

  getTrackPoints "$IN" |
  uniq |
  geojson > "$OUT"
}

getTrackPoints() {
  sed -nr "
    s~^.*<trkpt lat=\"([^\".]+\.[^\"]{1,4})[^\"]*\" lon=\"([^\".]+\.[^\"]{1,4})[^\"]*\">.*$~\1 \2~
    T exit
    p
    :exit
  " "$@"
}

geojson() {
  local LAT LON
  read LAT LON

  printf \
    "%s\n%s%s[%s,%s]%s[%s,%s]" \
    "<mapframe width=\"480\" height=\"400\">" \
    '{"type":"FeatureCollection","features":['\
    '{"type":"Feature","properties":{"title":"Start"},"geometry":{"type":"Point","coordinates":' \
    "$LON" "$LAT" \
    '}},{"type":"Feature","properties":{"title":"[[Hungary]]"},"geometry":{"type":"LineString","coordinates":[' \
    "$LON" "$LAT"

  while read LAT LON; do
    printf ",[%s,%s]" "$LON" "$LAT"
  done
  printf "%s\n%s" "]}}]}" "</mapframe>"
}

main "$@"
