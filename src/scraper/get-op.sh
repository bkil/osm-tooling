#!/bin/sh
set -u

main() {
  local VAR LETTER OUT
  if [ -z "$DOMAIN" ]; then
    echo "error: DOMAIN unset"
    exit 1
  fi

  readonly VAR="cache"
  mkdir -p "$VAR"
  for LETTER in a b c d e f g h i j k l m n o p q r s t u v w x y z; do
    OUT="$VAR/op-$LETTER.json"
    search "$LETTER" "$OUT"
    jq -c '.results[]' < "$OUT"
  done |
  sort -u |
  geojson
}

search() {
  local STERM SOUT
  readonly STERM="$1"
  readonly SOUT="$2"

  [ -s "$SOUT" ] && return

  echo "$SOUT" >&2
  curl \
    "https://www.$DOMAIN.hu/wp-admin/admin-ajax.php" \
    -A- \
    -d "action=getShops&searchFilters=cim%3D$STERM" \
    --compressed > "$SOUT"

  sleep 1
}

geojson() {
  jq -s '
  {
    "type": "FeatureCollection",
    "features": [.[] |
      {
        "type": "Feature",
        "properties": {
          "ref:internal": .id,
          "branch": .title,
          "addr:postcode": .zip,
          "addr:city": .city,
          "addr:full": .address,
          "name": .category,
          "shop": (if (.category | endswith("szuper")) then "supermarket" else "convenience" end),
          "brand": "'$DOMAIN'"
        },
       "geometry": {
         "type": "Point",
         "coordinates": [.lng, .lat]
       }
     }
   ]
 }'
}

main "$@"
