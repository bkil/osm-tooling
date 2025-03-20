#!/bin/sh

parse() {
  local T B
  readonly T="`printf "\t"`"
  readonly B="\\"

  printf '['

  cat "$F" |
  sed "s~${T}~\&#09;~g" |
  sed -rn "
    s~^ * data-([^=]+)=\" *(|[^\" ]|[^\" ][^\"]*[^\" ]) *\"></li>$~\1${T}\2\n${T}~
    t p
    s~^ *(<li )?data-([^=]+)=\" *(|[^\" ]|[^\" ][^\"]*[^\" ]) *\".*$~\2${T}\3~
    T e
    :p
    p
    :e
    " |
  sed -r "
    s~&#193;~Á~g
    s~&#201;~É~g
    s~&#205;~Í~g
    s~&#211;~Ó~g
    s~&#214;~Ö~g
    s~&#218;~Ú~g
    s~&#220;~Ü~g
    s~&#225;~á~g
    s~&#233;~é~g
    s~&#237;~í~g
    s~&#243;~ó~g
    s~&#246;~ö~g
    s~&#250;~ú~g
    s~&#252;~ü~g
    s~&#336;~Ő~g
    s~&#337;~ő~g
    s~&#368;~Ű~g
    s~&#369;~ű~g
    s~${B}${B}~&&~g
    s~(\"|&quot;)~${B}${B}\"~g
  " |
  awk -F "$T" '
    {
      if ($1 == "") {
        print "{\"type\":\"Feature\",\"geometry\":{\"type\":\"Point\",\"coordinates\":[" v["lon"] "," v["lat"] "]},\"properties\":{\"name\":\"" v["title"] "\",\"image\":\"" v["image"] "\",\"addr:postcode\":\"" v["zip"] "\",\"addr:city\":\"" v["city"] "\",\"addr:full\":\"" v["address"] "\",\"contact:phone\":\"" v["phone"] "\",\"contact:website\":\"" v["web"] "\",\"contact:email\":\"" v["email"] "\",\"description\":\"" v["type"] "\"}}"
        delete v;
      } else {
        v[$1] = $2;
      }
    }
  ' |
  sed ":l; N; s~\n~,~; t l"

  printf ']'
}

main() {
  local SITE F OUT
  readonly F="cache/soda.html"
  readonly OUT="cache/soda.geojson"
  [ -n "$1" ] && readonly SITE="$1"
  [ -n "$SITE" ] || exit 1

  if ! [ -f "$F" ]; then
    curl "https://www.${SITE}.hu/tartalek-patron/" > "$F"
  fi

  parse > "$OUT"
  ls -l "$OUT" >&2
}

main "$@"
