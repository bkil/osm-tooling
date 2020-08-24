#!/bin/sh
# Yes, I know JOSM can open GeoJSON

main() {
  OUT="out"
  mkdir -p "$OUT/" || exit 1
  cd "`dirname "$0"`/$OUT" || exit 1
  MAP="alltheplaces.xyz.gpx"
  DIR="output"
  if ! [ -d "$DIR" ]; then
    #Get the most recent URL from here: https://www.alltheplaces.xyz/
    wget -nc "https://data.alltheplaces.xyz/runs/2020-08-19-14-42-37/output.tar.gz" || exit 1
    tar -xzf "output.tar.gz" || exit 1
  fi

    cat << EOF > "$MAP"
<?xml version='1.0' encoding='UTF-8'?>
<gpx version="1.1" creator="JOSM GPX export" xmlns="http://www.topografix.com/GPX/1/1"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
EOF

  ls "output" |
  while read F; do
    echo "$F" >&2
  jq \
  --raw-output \
'.features[] |'\
'try select('\
'.geometry.coordinates[1] > 45.5 and .geometry.coordinates[1] < 48.6 and'\
'.geometry.coordinates[0] > 16 and .geometry.coordinates[0] < 23'\
') |'\
'@html "'\
'<wpt'\
' lat=\"\(.geometry.coordinates[1])\"'\
' lon=\"\(.geometry.coordinates[0])\"'\
'><name>'\
'\(.properties.brand // "") '\
'\(.properties.name // ""): '\
'\(.properties["addr:postcode"] // "") \(.properties["addr:city"] // "") \(.properties["addr:street"] // "") \(.properties["addr:full"] // "")'\
'</name>'\
'<description>'\
'\(.properties)'\
'</description>'\
'</wpt>"
  ' "$DIR"/"$F"
  done |
  sed 's~\"~"~g' >> "$MAP" || exit 1

  cat << EOF >> "$MAP"
</gpx>
EOF
}

main "$@"
