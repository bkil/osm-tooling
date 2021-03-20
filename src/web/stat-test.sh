#!/bin/sh

. `dirname "$0"`/stat.inc.sh

main() {
  local JSON="out/html/osm/static/stats.json"

  {
    cat_header
    cat_coverage "$JSON"

    cat_charts "$JSON"
    cat_charts_css "$JSON"

    cat_footer
  } > "out/stat.html"
}

cat_header() {
  cat << EOF
<!DOCTYPE html>
<html>
<head>
<meta charset=UTF-8>
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>CSS-only statistics chart debugging</title>
<style type="text/css">
EOF

  cat "barchart.css"

  cat "out/charts.min.css"
  cat_chart_css_fixup
  cat << EOF
</style>
</head>
<body>
EOF
}

cat_footer() {
  cat << EOF
</body>
</html>
EOF
}

main "$@"
