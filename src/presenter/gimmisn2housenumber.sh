#!/bin/sh

main() {
  local OSMIN="$1"
  local OUT="${2-misi-num.csv}"

  cat "$OSMIN" |
  sed "s~</tr>~\n~g" |
  sed -nr 's~^<tr><td><a href="https://www.openstreetmap.org/[^/"]*/[0-9]*" target="_blank">[0-9]*</a></td><td>([^<>]*)</td><td>([^<>]*)</td><td>([^<>]*)</td>.*~\3;\1;\2~ ; T e; p; :e' |
  sort -u |
  cat > "$OUT"
}

main "$@"
