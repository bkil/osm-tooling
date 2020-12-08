#!/bin/sh

main() {
  jelentos > jelentos.csv
  tartoz100 > tartoz100.csv
  tartoz10 > tartoz10.csv
}

tartoz10() {
  tartoz10_ 1 50
  tartoz10_ 51 51 102
}

tartoz10_() {
  local PAGEFROM="${1-1}"
  local PAGETO="${2-76}"
  local MAXHEIGHT="${3-816}"

  local PDF="180nap_MSZem_20200930WEB.pdf"
  local TXT="`basename "$PDF" .pdf`.$MAXHEIGHT.txt"
  wget -nc "https://www.nav.gov.hu/data/cms160317/$PDF" >&2

  # run this to get the bbox:
  # pdftotext -f 1 -l 2 -bbox "$PDF"

  pdftotext \
    -enc UTF-8 \
    -eol unix \
    -f "$PAGEFROM" -l "$PAGETO" \
    -x 258 -y 66 -W `expr 478 - 258` -H "`expr $MAXHEIGHT - 68`" \
    "$PDF" \
    "$TXT"

  sed "s~\f~~g" "$TXT" |
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
  local PDF="180NAP_GAZD_20200930WEB.pdf"
  local TXT="`basename "$PDF" .pdf`.txt"
  wget -nc "https://www.nav.gov.hu/data/cms160318/$PDF" >&2

  pdftotext \
    -enc UTF-8 \
    -eol unix \
    -x 292 -y 57 -W `expr 503 - 292` -H `expr 816 - 57` \
    "$PDF" \
    "$TXT"

  sed "s~\f~~g" "$TXT" |
  grep -vE "(\
0 NAPON KERESZTÜL FOLYAMATOSAN FENN|\
AL RENDELKEZŐ - NEM MAGÁNSZEMÉLY - AD|\
[0-9]-I ÁLLAPOT$|\
alatt álló gazdálkodók$|\
álló gazdálkodók|\
lló gazdálkodók|\
^(7|\
\.|\
Cím|\
)$)" |
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
  local XLS="2020._III._ne_web.xls"
  local CSV="`basename "$XLS" .xls`.csv"
  wget -nc "https://www.nav.gov.hu/data/cms533097/$XLS" >&2

  [ -f "$CSV" ] ||
  lowriter \
    --headless \
    --convert-to csv:"Text - txt - csv (StarCalc)":"44,34,0,1,,0" \
    "$XLS" >&2 2>/dev/null

  cat "$CSV" |
  sed -nr '
    s~^((([^,"]*|"[^"]*"),){3}([^,"]*|"[^"]*")),.*$~\1~
    T e
    p
    :e
  ' |
  sed -r 's~^((([^,"]*|"[^"]*"),){3}([^,"]*|"[^"]*"))$~\4~' |
  tail -n +2 |
  sed -r 's~^"?\s*~~ ; s~\s*"?$~~'
}

main "$@"
