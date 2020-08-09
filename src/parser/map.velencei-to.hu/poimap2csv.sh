#!/bin/sh

main() {
  local OUT="poimap.csv"

  cat map.*.json |
  unescape |
  split_lines |
  json_obj2csv |
  remove_null |
  cat > "$OUT"

  verify "$OUT"
}

json_obj2csv() {
  sed -nr '
    s~^\{"id":("[^"]*").*"latitude":("[^"]*"),"longitude":("[^"]*"),"product_name":("[^"]*").*"product_cim":("[^"]*"|null).*"settlements_name":("[^"]*"|null),"product_irszam":("[^"]*"|null).*"keywords":("[^"]*").*"templates_id":("[^"]*").*"icon":~\1,\2,\3,\4,\5,\6,\7,\8,\9,~
    T e
    s~\}(,|[]])$~~
    p
    :e
  '
}

split_lines() {
  sed 's~{"id"~\n&~g' |
}

verify() {
  local OUT="$1"
  {
    echo "See below lines with possible error:" >&2
    grep --color=always '\\u' "$OUT"
    grep --color=always '{' "$OUT"
  } |
  head
}

remove_null() {
  sed -r '
    :l
    s~^(("[^"]*",)*)null,~\1"",~
    t l
    s~^(("[^"]*",)*)null$~\1""~
  '
}

unescape() {
  sed '
    s~\\u00e1~á~g
    s~\\u00e9~é~g
    s~\\u00ed~í~g
    s~\\u00f3~ó~g
    s~\\u00f6~ö~g
    s~\\u0151~ő~g
    s~\\u00fa~ú~g
    s~\\u00fc~ü~g
    s~\\u0171~ű~g
    s~\\u00c1~Á~g
    s~\\u00c9~É~g
    s~\\u00d3~Ó~g
    s~\\u00d6~Ö~g
    s~\\u0150~Ő~g
    s~\\u00da~Ú~g
    s~\\u00dc~Ü~g
    s~\\u2013~-~g
    s~\\u201e~„~g
    s~\\u201d~”~g
    s~\\/~/~g
    s~\\"~'"'"'~g
  '
}

main "$@"

cat << EOF > /dev/null
Example input:

[{"id":"42","products_id":"42","latitude":"47.1234","longitude":"18.1234","product_name":"L\u00e1da","nice_url":"lada","product_cim":"Baba utca 42.","product_hazszam":"42","settlements_name":"Bugyi","product_irszam":"1234","products_templates_id":"10","address":"1234 Bugyi, Baba utca 42. ","keywords":"angol,magyar,szolg\u00e1ltat\u00e1s,Kiemelt aj\u00e1nlat","showIcon":true,"templates_id":"10","travel_mode":1,"menu_ids":[1965,1943],"icons":[],"image":"http:\/\/www.example.org\/img1-2-3-ca-18-18-mc-tp\/lada-foto.jpg","showImage":true,"subitems":[],"dates":[],"icon":"http:\/\/www.example.org\/svg\/\/1\/2\/3\/4\/5\/6\/csepp\/48\/lada-ikon.png"},{"id":"69",

jq prettyprint:
[
  {
    "id": "42",
    "products_id": "42",
    "latitude": "47.1234",
    "longitude": "18.1234",
    "product_name": "Láda",
    "nice_url": "lada",
    "product_cim": "Baba utca 42.",
    "product_hazszam": "42",
    "settlements_name": "Bugyi",
    "product_irszam": "1234",
    "products_templates_id": "10",
    "address": "1234 Bugyi, Baba utca 42. ",
    "keywords": "angol,magyar,szolgáltatás,Kiemelt ajánlat",
    "showIcon": true,
    "templates_id": "10",
    "travel_mode": 1,
    "menu_ids": [
      1965,
      1943
    ],
    "icons": [],
    "image": "http://www.example.org/img1-2-3-ca-18-18-mc-tp/lada-foto.jpg",
    "showImage": true,
    "subitems": [],
    "dates": [],
    "icon": "http://www.example.org/svg//1/2/3/4/5/6/csepp/48/lada-ikon.png"
  }
]

EOF
