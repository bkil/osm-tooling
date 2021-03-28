#!/bin/sh
# Test: https://bkil.gitlab.io/spamisi/

. `dirname "$0"`/stat.inc.sh

main() {
  OBFUSCATEID="1"

  local OUT="out"
  mkdir -p "$OUT" || exit 1
  local HTML="$OUT/html"
  local URLBASE="https://osm-gimmisn.vmiklos.hu/"
  local URL="${URLBASE}osm/index.html"
  local MAIN="`echo "$URL" | sed "s~^.*://[^/]*/~$HTML/~"`"

  download "$URL" "$URLBASE" "$HTML" "$OUT"

  {
    get_header "$OUT"
    get_pages "$OUT" "$MAIN" "$HTML" "$URLBASE"
    get_footer "$MAIN"
  } > "$OUT/index.html"
}

download() {
# TODO: osm/static/stats.json (via stats.ts)
# TODO: osm/static/relations.json (via main.ts)
#    --timestamping
# --reject-regex "^${URLBASE}(osm/(street(-housenumbers)?|filter-for/refcounty)/.*|.*/update-result)$"
# --accept-regex "^${URLBASE}(robots\.txt|osm/(index\.html|static/[^/]+|([^/]+/balatonalmadi/view-[^/]+)|(filter-for|housenumber-stats)/.*|(additional|missing)-[^/]+/[^/]+/view-result))$"

  local URL="$1"
  local URLBASE="$2"
  local HTML="$3"
  local OUT="$4"

  mkdir -p "$HTML/osm/static" || exit 1

  wget \
    --no-clobber \
    --directory-prefix="$OUT" \
    --compression=auto \
    "https://cdn.jsdelivr.net/npm/charts.css/dist/charts.min.css" || exit 1

  wget \
    --directory-prefix="$HTML/osm/static" \
    --no-clobber \
    --compression=auto \
    "${URLBASE}osm/static/stats.json" || exit 1

  wget \
    --directory-prefix="$HTML" \
    --force-directories \
    --no-host-directories \
    --wait=1 \
    --no-parent \
    --recursive \
    --level 4 \
    --adjust-extension \
    --no-clobber \
    --backups=0 \
    --continue \
    --compression=auto \
    --accept-regex "^${URLBASE}(robots\.txt|osm/(index\.html|static/[^/]+|([^/]+/balatonalmadi/view-[^/]+)|(filter-for|housenumber-stats)/.*|(additional|missing)-[^/]+/balatonalmadi/view-result))$" \
    "$URL" || exit 1
}

get_pages() {
  local OUT="$1"
  local MAIN="$2"
  local HTML="$3"
  local URLBASE="$4"

  local IDS="$OUT/downloaded-ids.txt"

  get_file_list "$HTML" "$MAIN" |
  sed "s~^$HTML/~~ ; s~/index\.html$~~ ; s~\.html$~~" |
  sort -u > "$IDS"

  local IDREGEX="`sed ":l; N; s~\n~|~g; t l" "$IDS"`"

  get_file_list "$HTML" "$MAIN" |
  {
    local PAGEIDX="0"
    while read FILE; do
      get_page "$FILE" "$PAGEIDX"
      local PAGEIDX="`expr $PAGEIDX + 1`"
    done
  } |
  post_process_page "$IDREGEX" "$URLBASE"
}

get_file_list() {
  local HTML="$1"
  local MAIN="$2"

  # hack: this is shown while the document is being transferred
  echo "$MAIN"

  find "$HTML" -type f |
  sort |
  fgrep -v "$MAIN" |
  grep -E "^$HTML/osm/((([^/]+/balatonalmadi)|filter-for|housenumber-stats)/|(additional|missing)-[^/]+/[^/]+/view-result)" |
  grep -v "/update-result$"

  # hack: this is showed via `get_page_switching_style` after having loaded
  echo "$MAIN"
}

get_page() {
  local FILE="$1"
  local PAGEIDX="$2"

  local JSON="out/html/osm/static/stats.json"

  local ISLOADING=""
  [ "$PAGEIDX" = 0 ] && ISLOADING="1"

  local ENDPOINT="`echo "$FILE" | sed "s~^$HTML/~~ ; s~/index.html$~~ ; s~\.html$~~"`"
  local NAME="`echo "$ENDPOINT" | sed "s~/~--~g"`"

  local IDNAME="$NAME"
  [ -n "$ISLOADING" ] &&
    local IDNAME="SPAMISI-LOADING---$NAME"

  local PRE="$PAGEIDX"
  [ "$IDNAME" = "osm--housenumber-stats--hungary" ] &&
    local PRE="${IDNAME}---"

  local TITLE="`sed -nr "s~^.*<title>(.*)</title>.*$~\1~ ; T e; p; :e" "$FILE"`"

  cat << EOF

<div id="$IDNAME" class="page">
EOF

  if [ -n "$TITLE" ]; then
    if [ -n "$ISLOADING" ]; then
      echo "<div class=\"title-loading\">$TITLE - LOADING</div>"
    else
      echo "<div class=\"title\">$TITLE</div>"
    fi
  fi

  if
    fgrep -q "<!DOCTYPE html>" "$FILE"
  then

  fgrep -v "<!DOCTYPE html>" "$FILE" |
  sed -r "
    s~ id=\"~ id=\"${PRE}~g

    s~(<a href=\"#)([^\"])~\1${PRE}\2~g

    s~(<a href=\"#)(\")~\1$IDNAME\2~g

    s~(<a)( href=\"/${ENDPOINT}/?\")~\1 class=\"selflink\"\2~g
  "

  if [ "$IDNAME" = "osm--housenumber-stats--hungary" ]; then
    echo "<div class=no-js>"
    cat_coverage "$JSON"
    cat_charts "$JSON"
    cat_charts_css "$JSON"
    echo "</div>"
  fi

  else
    printf "<pre>"
    cat "$FILE"
    printf "</pre><hr/>"
  fi
  
  cat << EOF
</div>
EOF
}

post_process_page() {
  local IDREGEX="$1"
  local URLBASE="$2"

  sed '
    s~<div style="display: none;"><div id="[^"]*str-toolbar-overpass-wait" data-value="Waiting for Overpass..."></div><div id="[^"]*str-toolbar-overpass-error" data-value="Error from Overpass: "></div><div id="[^"]*str-toolbar-reference-wait" data-value="Creating from reference..."></div><div id="[^"]*str-toolbar-reference-error" data-value="Error from reference: "></div></div><a[^<>]* href="https://overpass-turbo.eu/">Overpass turbo</a> ¦ ~~g

    s~<div style="display: none;"><div id="[^"]*str-gps-wait" data-value="Waiting for GPS..."></div><div id="[^"]*str-gps-error" data-value="Error from GPS: "></div><div id="[^"]*str-overpass-wait" data-value="Waiting for Overpass..."></div><div id="[^"]*str-overpass-error" data-value="Error from Overpass: "></div><div id="[^"]*str-relations-wait" data-value="Waiting for relations..."></div><div id="[^"]*str-relations-error" data-value="Error from relations: "></div><div id="[^"]*str-redirect-wait" data-value="Waiting for redirect..."></div></div>~~g
    ' |
  sed -r "
    s~^.*<body>~~
    s~</body></html>$~~

    s~(<hr />)<div>Version\: <a [^>]*>[^<>]*</a> . OSM data © OpenStreetMap contributors\.( . (Last update\: [^<>]*))?</div>$~\1\3~

    s~ id=\"[^\"]*---(filter-based-on-position|_daily|_dailytotal|_monthly|_monthlytotal|_topusers|_topcities|_usertotal|_progress)\"~& class=\"js\"~g

    s~(<a( class=\"selflink\")? href=\"/[^\"]*)/(\")~\1\3~g

    s~(<a)( href=\"[^#/][^\"]*\")( target=\"[^\"]*\")?(>)~\1 target=\"_blank\"\2\4~g

    s~(<a)( href=\"/)~\1 class=\"redlink\"\2~g
    s~(<a class=\")red(link\" href=\"/($IDREGEX)\")~\1\2~g
    s~(<a) class=\"redlink\"( href=\")/([^\"]*\")~\1 target=\"_blank\"\2${URLBASE}\3~g

    t l
    :l
    s~(<a class=\"(self)?link\" href=\"/[^\"/]*)/~\1--~g
    t l
    s~(<a class=\"(self)?link\" href=\")/~\1#~g
  " |
  minify
}

minify() {
  # https://html.spec.whatwg.org/multipage/syntax.html#void-elements
  # https://html.spec.whatwg.org/multipage/syntax.html#syntax-text
  sed -r "
    s~([<>\s]|^)</?strong>|</?strong>([&<>\s]|$)~\1\2~g
    s~</?strong>~ ~g
    s~ tabindex=\"[^\"]*\"~~g
    s~ +/>~/>~g
    s~<span style=\"color\: blue;\">(<abbr [^<>]*>[^<>]*</abbr>)</span>~\1~g
    s~<span style=\"color\: blue;\">(<abbr title=\"[^\"<>]*)$~\1~g
    s~^([^\"<>]*\">[^<>]*</abbr>)</span>~\1~g
    s~<span style=\"color\: blue;\">([^<>]*)</span>~<i>\1</i>~g

    s~(<tr>)<th><a href=\"#[^\"]*\">(@id|Identifier)</a></th>((<th><a [^>]*>[^<>]*</a></th>)*)(<th><a [^>]*>[^<>]*</a></th>)(</tr>)~\1\5\3\6~
    s~(<tr><td><a[^<>]* href=\"https\://www\.openstreetmap\.org/[^/]*/[0-9]+\"[^<>]*>)[0-9]+(</a></td>(<td>[^<>]*</td>)*)<td>([^<>]*)</td>(</tr>)~\1\4\2\5~g

    s~(<(area|base|br|col|embed|hr|img|input|link|meta|param|source|track|wbr)(|( +[^<> ]+)*)) */(>)~\1\5~g

    t stripquotes
    :stripquotes
    s~(<[^<> ]+( +[^<>= ]+(=[^\"'\`=<> ]+)?)* +[^<>= ]+=)\"([^\"'\`=<> ]+)\" *(/>)~\1\4 \5~g
    t stripquotes
    s~(<[^<> ]+( +[^<>= ]+(=[^\"'\`=<> ]+)?)* +[^<>= ]+=)\"([^\"'\`=<> ]+)\"~\1\4~g
    t stripquotes

    t makeEndsMeet
    :makeEndsMeet
    s~</(th|tr|td|)>(</?(th|tr|td|thead|tbody|table)>)~\2~g
    t makeEndsMeet

    t colspan
    :colspan
    s~(<td>){10}(</?(th|tr|td|thead|tbody|table)>)~<td colspan=10>\2~g
    t colspan
    s~(<td>){9}(</?(th|tr|td|thead|tbody|table)>)~<td colspan=9>\2~g
    t colspan
    s~(<td>){8}(</?(th|tr|td|thead|tbody|table)>)~<td colspan=8>\2~g
    t colspan
    s~(<td>){7}(</?(th|tr|td|thead|tbody|table)>)~<td colspan=7>\2~g
    t colspan
    s~(<td>){6}(</?(th|tr|td|thead|tbody|table)>)~<td colspan=6>\2~g
    t colspan
    s~(<td>){5}(</?(th|tr|td|thead|tbody|table)>)~<td colspan=5>\2~g
    t colspan
    s~(<td>){4}(</?(th|tr|td|thead|tbody|table)>)~<td colspan=4>\2~g
    t colspan

    s~https://www.openstreetmap.org/~http://osm.org/~g
  "
}

minify_css() {
  sed -r "
    s~/\*([^*]|\*+[^*/])*\*/~~

    s~&~&amp;~g
    t amp
    :amp
    s~([a-zA-Z0-9]) ( *[a-zA-Z0-9])~\1\&nbsp;\2~g
    t amp

    t l
    :l
    s~^(([^\" ]|\"[^\"]*\")*) +~\1~
    t l

    s~&nbsp;~ ~g
    s~&amp;~\&~g
  " "$@" |
  sed ":l; N; s~\n~~; t l"
}

get_header() {
  local OUT="$1"

  cat << EOF |
<!DOCTYPE html>
<html lang="en"><head>
<meta charset="UTF-8" /><style type="text/css">
<meta name="viewport" content="width=device-width, initial-scale=1" />
<link rel="icon" type="image/png" sizes="64x64" href="favicon.ico">
<title>SPA-Misi</title>
EOF
  minify

  {
    cat "$OUT/html/osm/static/osm.css"

    cat << EOF
.pages > .page {
  display: none;
}

.pages > :first-child {
  display: block;
}

.title {
  color: #fff;
  background-color: #707;
}

.title-loading {
  color: #fff;
  background-color: #770;
}

.link {
  color: #090;
  text-decoration: underline;
}
.link:hover,
.link:focus {
  background-color: #efe;
  cursor: pointer;
}

.selflink {
  color: #fff;
  background-color: #000;
  text-decoration: none;
}

abbr, i {
  color: blue;
}

.no-js { display: none; }
.js { display: block; }
EOF
  } |
  minify_css

  cat << EOF |
</style>

<noscript>
  <style type="text/css">
  .no-js { display: block; }
  .js { display: none; }
  </style>
</noscript>
</head><body>
<div style="display: none;"><div id="str-toolbar-overpass-wait" data-value="Waiting for Overpass..."></div><div id="str-toolbar-overpass-error" data-value="Error from Overpass: "></div><div id="str-toolbar-reference-wait" data-value="Creating from reference..."></div><div id="str-toolbar-reference-error" data-value="Error from reference: "></div></div>

<div style="display: none;"><div id="str-gps-wait" data-value="Waiting for GPS..."></div><div id="str-gps-error" data-value="Error from GPS: "></div><div id="str-overpass-wait" data-value="Waiting for Overpass..."></div><div id="str-overpass-error" data-value="Error from Overpass: "></div><div id="str-relations-wait" data-value="Waiting for relations..."></div><div id="str-relations-error" data-value="Error from relations: "></div><div id="str-redirect-wait" data-value="Waiting for redirect..."></div></div>

<div class="pages">
EOF
  minify
}

get_page_switching_style() {
  cat << EOF
<style type="text/css">
.pages > .page:target ~ .page:last-child, .pages > .page {
  display: none;
}

.pages > :last-child, .pages > .page:target {
  display: block;
}
</style>
EOF
}

get_loading_finished_style() {
  cat << EOF
<style type="text/css">
.title {
  color: #fff;
  background-color: #f00;
}
</style>

<!--  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/charts.css/dist/charts.min.css"> -->
<!--  <link rel="stylesheet" href="https://unpkg.com/charts.css/dist/charts.min.css"> -->

  <style type="text/css">
EOF
  # if not using CDN
  cat "out/charts.min.css"

  {
    # DEBUG comparison
    cat "barchart.css"

    cat_chart_css_fixup
  } |
  minify_css
  cat << EOF
  </style>
EOF
}

get_js() {
  cat << EOF
<script>
EOF

  sed -r "
    s~((getElementById|:[{]display:!0,(text|labelString):k)\(\")~\1osm--housenumber-stats--hungary---~g
    s~(uriPrefix=\"/)osm(\")~\1spamisi\2~g
  " "$OUT/html/osm/static/bundle.js"

  cat << EOF
</script>
EOF
}

get_footer() {
  local MAIN="$1"
  cat << EOF
</div>
EOF

  get_page_switching_style |
  minify

  get_version "$MAIN" |
  minify

  get_js

  get_loading_finished_style |
  minify

  cat << EOF
</body></html>
EOF
}

get_version() {
  sed -nr '
    s~.*<hr */>(<div>Version\: <a)( href=\"[^\"]*\">[^<>]*</a>[^<>]*)(</div>)</body></html>$~\1 target=\"_blank\"\2 | single page application generated by <a target=\"_blank\" href=\"https://github.com/bkil/osm-tooling/blob/master/src/web/spamisi.sh\">spamisi.sh</a>\3~
    T e
    p
    :e
  ' "$@"
}

main "$@"
