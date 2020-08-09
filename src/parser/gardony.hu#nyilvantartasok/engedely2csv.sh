#!/bin/sh

# input:
# * vasony-tmp004.csv https://github.com/vasony/osm-gimmisn-reference/tree/master/gardony
# * poimap.csv parser output for map.velencei-to.hu
# * dup.csv: filter rows by keys listed here
# * Bejelentés Köteles Kereskedelmi Tevékenységet Végzők
# * Működési Engedéllyel Rendelkező Kereskedők

main() {
  local OUT="engedely.csv"

  {
    parse_mukodesi |
    sed "s~^~ker;~"

    parse_bejelentes |
    sed "s~^~bej;~"

    cat "vasony-tmp004.csv" |
    sed "
      s~\"~~g
      s~^~vas;~
    "

    project_poimap
  } |
  patches |
  sort --stable --field-separator=";" --key=3 |
  uniq |
  cat > "$OUT"
}

project_poimap() {
  cat "poimap.csv" |
  grep -v ',Állat","31",' |
  sed -r '
    s~;~,~g
    s~^"([^"]*)","([^"]*)","([^"]*)","([^"]*)","([^"]*)","([^"]*)","([^"]*)","[^"]*","([^"]*)".*$~vmap;\1;\7 \6, \5;\4;;\8;\2;\3~
    s~;;10;~;szolgáltatás;~
    s~;;11;~;ital;~
    s~;;13;~;múzeum;~
    s~;;16;~;hotel;~
    s~;;19;~;szobor;~
    s~;;20;~;program;~
    s~;;26;~;gyógyulás;~
    s~;;27;~;védett természet;~
    s~;;31;~;túrázás;~
    s~;;41;~;térkép;~
    s~;;42;~;turisztika;~
    s~;;7;~;apartman;~
    s~;;8;~;vallás;~
    s~;;9;~;építmény;~
    s~;;[^;]*;~;;~
  ' |
  keep_region_gardony
}

keep_region_gardony() {
  awk -F ';' -vOFS=';' '
    {
      if (($6 > 47.15692) && ($6 < 47.25224) && ($7 > 18.51341) && ($7 < 18.69919))
        print
    }
  '
}

patches() {
  local TMP="filter-tmp.csv"

  cat "dup.csv" |
  sed 's~"~~g ; s~^~^~ ; s~$~;~' |
  cat > "$TMP"

  sed -r "
    s~, ,~,~g
    s~ +,~,~g
    s~( Gárdony,) *Agárd(|( +| *- *)([^ ;-][^;]*))(;)~\1\4 (Agárd)\5~g
    s~( Gárdony) *- *Agárd?,?( *(|[^, ;][^;]*))(;)~\1,\2 (Agárd)\4~g
    s~(;)Agárd-([^;]*)(;)~\12484 Gárdony, \2 (Agárd)\3~g
    s~( Gárdony,) *Dinnyés *- *([^;]*)(;)~\1 \2 (Dinnyés)\3~g
    s~( Gárdony,) *Dinnyés(|[, ;] *([^ ;][^;]*))(;)~\1 \3 (Dinnyés)\4~g
    s~( Gárdony) *- *Dinnyés,? *(|[^, ;][^;]*)(;)~\1, \2 (Dinnyés)\3~g
    s~;2085( Gárdony),~;2485\1~g
    s~(;248[3-5] )(Agárd|Dinnyés)(, [^ ;][^;]*)(;)~\1Gárdony\3 (\2)\4~
    s~(,)([^ ])~\1 \2~g
    s~ u\. ~ utca ~g
    s~(;[0-9]{4} [^, ;]+) ~\1, ~
  " |
  grep -vf "$TMP"

  rm "$TMP"
}

parse_bejelentes() {
  local IN="Bejelentes.pdftotext.layout.txt"
  local OUT="engedely-bejelentes.tmp.csv"
  local ID="id.tmp.csv"

  echo "bejelentes" >&2
  pdftotext -layout "Bejelentés Köteles Kereskedelmi Tevékenységet Végzők 2018-12-20.pdf" "$IN"

  cat "$IN" |
  sed "
    s~õ~ő~g
    s~û~ű~g
    s~\"~'~g
    " |
  sed -nr "
    :restart
    s~^\f? {10,}([^ ])~\1~
    T next
    N
    s~^\f?(.*)\n(neve:) *~\2\1 ~
    t appendop

    s~^\f?(.*)\n(Üzlet elnevezése:) *~\2\1 ~
    t appendname

    s~.*\n~~
    t restart
    b restart

    :appendname
    N
    s~( +Nyitvatartás ideje)\n {10,}([^ ].*)$~ \2 \1~
    t next
    b next

    :appendop
    N
    s~( +[0-9]+/20[0-2][0-9])\n {10,}([^ ].*)$~ \2 \1~
    t next
    b next

    :next
    s~([^ ].*) kereskedelmi helyhez tartozó üzletek$~addr;\1~
    t p

    s~.*Üzlet elnevezése: *([^ ]|[^ ].*[^ ]) +Nyitvatartás ideje$~name;\1~
    t p

    :name
    s~^\f?neve: *([^ ].*[^ ]) +([0-9]+/20[0-2][0-9])$~id;\2\noperator;\1~
    t p

    b e
    :p
    p
    :e
  " |
  awk -F ';' -vOFS=';' '
    {
      if ($1 == "id") {
        save()
        id = $2
        operator = ""
        name = ""
        addr = ""
      } else if ($1 == "operator") {
        operator = $2
      } else if ($1 == "name") {
        name = $2
      } else if ($1 == "addr") {
        addr = $2
      }
    }
    END {
        save()
    }
    function save() {
        if (id != "") {
          print id OFS addr OFS name OFS operator
        }
    }
  ' |
  tee "$OUT"

  sed -rn 's~^neve:( *|.* )([0-9]+/20[0-2][0-9])$~\2~; T e; p; :e' "$IN" > "$ID"

  {
    echo "extra IDs:"
    fgrep -v "$OUT" -f "$ID"

    echo "missing IDs:"
    cut -d ";" -f "1" "$OUT" |
    fgrep -h -v "$OUT" -f - "$ID"
  } >&2

  rm "$OUT" "$ID" "$IN"
}

parse_mukodesi() {
  local IN="Mukodesi.pdftotext.layout.txt"
  local OUT="engedely-mukodes.tmp.csv"
  local ID="id.tmp.csv"

  echo "mukodesi" >&2
  pdftotext -layout "Működési Engedéllyel Rendelkező Kereskedők 2018-12-20.pdf" "$IN"

  cat "$IN" |
  sed "
    s~õ~ő~g
    s~û~ű~g
    s~\"~'~g
    " |
  sed -nr "
    s~^\f? {16,}[0-9]+$~&~
    t sk
    s~^\f? {16,}(Hétfő|Kedd|Szerda|Csütörtök|Péntek|Szombat|Vasárnap)~&~
    t sk
    s~Üzlet elnevezése: *~&~
    t p
    s~neve: *~&~
    t p
    s~^\f?címe: {12,}~&~
    t addr
    s~^ {13,30}[^ ]~&~
    T sk
    :addr
    s~ *Kedd *([0-9]{2}:[0-9]{2})? - tól +([0-9]{2}:[0-9]{2})? - ig$~~
    :p
    p
    :sk
  " |
  grep -vE "^ *(NYILVÁNTARTÁS|\.+|a működési engedéllyel rendelkező üzletekről)$" |
  sed -nr "
    :restart
    s~;~,~g
    t comma
    :comma
    s~^\f?neve: *([^ ].*[^ ]) +([0-9]+/20[0-2][0-9])$~id;\2\noperator;\1~
    t p
    s~Üzlet elnevezése: *([^ ](.*[^ ])?) *Nyitvatartás ideje$~name;\1~
    t p
    s~^\f?címe: *([^ ](.*[^ ])?)~addr;\1~
    t p

    s~^ +([^ ])~\1~
    T e
    N
    s~\ncíme:$~~
    t addr

    s~\nÜzlet elnevezése: *Nyitvatartás ideje$~~
    t name

    s~^(.*)\nneve: *([0-9]+/20[0-2][0-9])$~id;\2;operator;\1~
    t operator

    s~.*\n~~
    b restart

    :operator
    N
    s~\n *~ ~
    s~;(operator)~\n\1~
    b p

    :name
    N
    s~\n *~ ~
    s~^~name;~
    b p

    :addr
    N
    s~\n *~ ~
    s~^~addr;~
    b p

    :p
    p
    :e
  " |
  awk -F ';' -vOFS=';' '
    {
      if ($1 == "id") {
        save()
        id = $2
        operator = ""
        name = ""
        addr = ""
      } else if ($1 == "operator") {
        operator = $2
      } else if ($1 == "name") {
        name = $2
      } else if ($1 == "addr") {
        addr = $2
      }
    }
    END {
        save()
    }
    function save() {
        if (id != "") {
          print id OFS addr OFS name OFS operator
        }
    }
  ' |
  tee "$OUT"

  sed -rn 's~.*M.*ködési engedéllyel rendelkez.* üzlet *([0-9]+/20[0-2][0-9])$~\1~; T e; p; :e' "$IN" > "$ID"

  {
    echo "extra IDs:"
    fgrep -v "$OUT" -f "$ID"

    echo "missing IDs:"
    cut -d ";" -f "1" "$OUT" |
    fgrep -h -v "$OUT" -f - "$ID"
  } >&2

  rm "$OUT" "$ID" "$IN"
}

main "$@"
