#!/bin/sh

main() {
  local OSMIN="$1"
  local OUT="${2-osm-num.csv}"

  cat "$OSMIN" |
  grep -A2 "addr:housenumber" |
  grep -E "addr:(housenumber|postcode|street)" |
  sed "s~;~,~g" |
  sed -r "s~.*<tag k='([^']*)' v='([^']*)'.*~\1;\2~" |
  awk -F';' -vOFS=';' '
    {
      if ($1 == "addr:housenumber") {
        save()
        post = ""
        street = ""
        num = $2
      } else if ($1 == "addr:postcode") {
        post = $2
      } else if ($1 == "addr:street") {
        street = $2
      }
    }

    END {
      save()
    }

    function save() {
      if (num != "")
        print post OFS street OFS num
    }
  ' |
  sort -u |
  cat > "$OUT"
}

main "$@"
