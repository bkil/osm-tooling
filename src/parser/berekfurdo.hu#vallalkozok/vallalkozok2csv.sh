#!/bin/sh
main() {
  local IN="Berekfürdő.html"
  wget \
    -nc \
    -O "$IN" \
    "http://www.berekfurdo.hu/?module=news&fname=vallalkozok"
  cat "$IN" |
  charset |
  crop_table |
  fold_lines |
  table2kv |
  kv2csv |
  fill_operator_addr |
  remove_town
}

charset() {
  iconv -f iso-8859-2 -t utf-8 |
  sed "s~\r~~g"
}

crop_table() {
  sed -n "1,/<tbody>/ ! p" |
  sed -n "/<\/tbody>/,$ ! p"
}

fold_lines() {
  sed "s~<br */>~ ~g" |
  sed "
    :l
    s~>$~&~
    t e
    N
    s~\s*\n\s*~ ~
    t l
    :e
  "
}

table2kv() {
  sed -n -r '
    s~.*<td class="xl65" height="17" style="height: 12\.75pt; border-top: medium none"><font size="2">(.*)</font></td>$~name \1~
    t p
    s~.*<td class="xl65" style="border-top: medium none; border-left: medium none"><font size="2">(.*)</font></td>$~addr \1~
    t p
    s~.*<td colspan="3" align="center">.*(<font size="2">.*<em>|<em>.*<font size="2">)(.*)(</em></font>|</font></em>) *</td>$~business \2~
    t p
    s~.*<td colspan="2"><font size="2">(.*)</font></td>$~business \1~
    t p
    b e
    :p
    s~</?span>~~g
    s~[  ]+~ ~g
    s~ *$~~
    s~&#39;~'\''~
    s~;~,~g
    s~^([^ ]*) +~\1;~
    t nonempty
    :nonempty
    s~^business$~&~
    t e
    p
    :e
  '
}

kv2csv() {
  awk -F ';' -vOFS=';' '
    {
      if ($1 == "business") {
        business = $2
      } else if ($1 == "addr") {
        addr = (addr ";" $2)
      } else if ($1 == "name") {
        if (name != "") {
          print name addr OFS business
        }
        business = ""
        addr = ""
        name = $2
      }
    }
    END {
        if (name != "") {
          print name addr OFS business
        }
    }
  '
  : sed -r '
    N
    N
    N
    s~;~,~g
    s~\n~;~g
    s~(^|;)[^ ]* ~\1~g
  '
}

fill_operator_addr() {
  awk -F ';' -vOFS=';' '
    {
      if ($2 == "") {
        $2 = $3
      }
      print $1 OFS $2 OFS $3 OFS $4
    }
  '
}

remove_town() {
  sed -r "s~5309 (Berekfürdő|Bf\.),? +~~g"
}

main "$@"
