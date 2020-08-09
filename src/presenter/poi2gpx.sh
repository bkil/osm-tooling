#!/bin/sh

main() {
  {
    cat << EOF
<?xml version='1.0' encoding='UTF-8'?>
<gpx version="1.1" creator="JOSM GPX export" xmlns="http://www.topografix.com/GPX/1/1"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
  <metadata>
    <bounds minlat="47.18562" minlon="18.5796464" maxlat="47.2162037" maxlon="18.6510873"/>
  </metadata>
EOF

    sed -r '
      s~&~\&amp;~g
      s~^"([^"]*)","([^"]*)","([^"]*)","([^"]*)","([^"]*)","([^"]*)",.*$~<wpt lat="\2" lon="\3"><name>\1: \4 - \5</name></wpt>~
    ' "poimap.csv"

    cat << EOF
</gpx>
EOF
  } > poimap.gpx
}

main "$@"
