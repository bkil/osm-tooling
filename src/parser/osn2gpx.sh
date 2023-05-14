#!/bin/sh

main() {
  {
    cat << EOF
<?xml version='1.0' encoding='UTF-8'?>
<gpx version="1.1" creator="JOSM GPX export" xmlns="http://www.topografix.com/GPX/1/1"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
  <metadata>
    <bounds minlat="47" minlon="18" maxlat="48" maxlon="19"/>
  </metadata>
EOF

    sed -nr "
      s~<note ~&~
      T e
      N
      s~\n~~
      p
      :e
      " "$@" |
    sed -r '
      s~&~\&amp;~g
      s~^.* lat="([^"]*)" lon="([^"]*)".*<comment.*>([^<>]*)</comment>$~<wpt lat="\1" lon="\2"><name>\3</name></wpt>~
    '

    cat << EOF
</gpx>
EOF
  } > "$1.gpx"
}

main "$@"

