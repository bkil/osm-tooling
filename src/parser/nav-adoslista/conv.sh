#!/bin/sh

main() {
  jelentos > jelentos.csv
  tartoz100 > tartoz100.csv
  tartoz10 > tartoz10.csv
}

tartoz10() {
  tartoz10_ 1 74
  tartoz10_ 75 75 313
}

tartoz10_() {
  local PAGEFROM="${1-1}"
  local PAGETO="${2-76}"
  local MAXHEIGHT="${3-596}"

  local PDF="180nap_MSZem_20200630WEB.pdf"
  wget -nc "https://www.nav.gov.hu/data/cms160317/$PDF"

  # run this to get the bbox:
  # pdftotext -f 1 -l 2 -bbox "$PDF"

  pdftotext \
    -enc UTF-8 \
    -eol unix \
    -f "$PAGEFROM" -l "$PAGETO" \
    -x 421 -y 0 -W `expr 657 - 421` -H "$MAXHEIGHT" \
    "$PDF"

  sed "s~\f~~g" \
    "`basename "$PDF" .pdf`".txt |
  grep -vE "^(\
\.?YAMATOSAN FENNÁLLÓ 10 MILLIÓ FORINTOT MEGHA|\
YÉNI VÁLLALKOZÓK\) 2020.06.30-i ÁLLAPOT|\
Cím|\
/?76|\
\.|\
)$" |
  sed "s~^~-~" |
  sed -r "
    s~^-~~
    t l
    :l
    N
    s~(\n)-([0-9]{4,} )~\1\2~
    t l
    s~ *\n- *~ ~
    t l
  "
}

tartoz100() {
  local PDF="180NAP_GAZD_20200630WEB.pdf"
  wget -nc "https://www.nav.gov.hu/data/cms160318/$PDF"

  pdftotext \
    -enc UTF-8 \
    -eol unix \
    -x 305 -y 0 -W 210 -H 842 \
    "$PDF"

  sed "s~\f~~g" \
    "180NAP_GAZD_20200630WEB.txt" |
  grep -vE "^(\
0 NAPON KERESZTÜL FOLYAMATOSAN FENNÁL|\
AL RENDELKEZŐ - NEM MAGÁNSZEMÉLY - ADÓ|\
0-I ÁLLAPOT|\
alatt álló gazdálkodók|\
álló gazdálkodók|\
lló gazdálkodók|\
7|\
\.|\
Cím|\
)$" |
  sed "s~^~-~" |
  sed -r "
    s~^-~~
    t l
    :l
    N
    s~(\n)-([0-9]{4,} )~\1\2~
    t l
    s~ *\n- *~ ~
    t l
  "
}

jelentos() {
  local XLS="2020._II._ne_web.xls"
  local CSV="2020._II._ne_web.csv"
  wget -nc "https://www.nav.gov.hu/data/cms528455/$XLS"

  [ -f "$CSV" ] ||
  lowriter \
    --headless \
    --convert-to csv:"Text - txt - csv (StarCalc)":"44,34,0,1,,0" \
    "$XLS" 2>/dev/null >&1

  cat "$CSV" |
  sed -nr '
    s~^((([^,"]*|"[^"]*"),){3}([^,"]*|"[^"]*")),.*$~\1~
    T e
    p
    :e
  ' |
  tee jelentos-all.csv |
  sed -r 's~^((([^,"]*|"[^"]*"),){3}([^,"]*|"[^"]*"))$~\4~' |
  tail -n +2 |
  sed -r 's~^"?\s*~~ ; s~\s*"?$~~'
}

main "$@"
